import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import 'shared_album.dart';
import 'shared_files.dart';

/// A photo or video about to be added to a shared album, wherever it comes
/// from (the phone, the account). [content] is the file as it will be
/// shared (photos already without their hidden details), in any chunks.
class NewSharedPhoto {
  const NewSharedPhoto({
    required this.isVideo,
    required this.mime,
    required this.takenAt,
    required this.content,
    this.thumbnail,
    this.width = 0,
    this.height = 0,
    this.duration = Duration.zero,
  });

  final bool isVideo;
  final String mime;
  final DateTime takenAt;
  final Stream<List<int>> Function() content;
  final Future<Uint8List?> Function()? thumbnail;
  final int width;
  final int height;
  final Duration duration;
}

/// How far adding photos to one album has come.
class UploadProgress {
  const UploadProgress(this.done, this.total);
  final int done;
  final int total;
}

class SharedAlbumsState {
  const SharedAlbumsState({
    this.albums = const [],
    this.available = false,
    this.ready = false,
    this.uploads = const {},
    this.myUserId,
  });

  /// By name.
  final List<SharedAlbum> albums;

  /// Signed in, unlocked, and sharing is up: albums can be made and joined.
  final bool available;

  /// Read at least once since sharing came up.
  final bool ready;

  /// Albums that photos are being added to now, by space id.
  final Map<String, UploadProgress> uploads;
  final String? myUserId;

  SharedAlbum? operator [](String spaceId) {
    for (final a in albums) {
      if (a.spaceId == spaceId) return a;
    }
    return null;
  }

  SharedAlbumsState copyWith({
    List<SharedAlbum>? albums,
    bool? ready,
    Map<String, UploadProgress>? uploads,
  }) => SharedAlbumsState(
    albums: albums ?? this.albums,
    available: available,
    ready: ready ?? this.ready,
    uploads: uploads ?? this.uploads,
    myUserId: myUserId,
  );
}

/// The largest piece a file is kept in: under the attachment limit
/// ([ZtAttachments.defaultMaxBytes]), so a long video is several files.
const sharedPartBytes = 19 * 1000 * 1000;

/// Splits [input] into pieces of exactly [size] bytes (the last one
/// shorter).
Stream<Uint8List> splitInto(Stream<List<int>> input, int size) async* {
  var buffer = BytesBuilder(copy: false);
  await for (final chunk in input) {
    var offset = 0;
    while (offset < chunk.length) {
      final take = (size - buffer.length).clamp(0, chunk.length - offset);
      buffer.add(
        chunk is Uint8List
            ? Uint8List.sublistView(chunk, offset, offset + take)
            : Uint8List.fromList(chunk.sublist(offset, offset + take)),
      );
      offset += take;
      if (buffer.length == size) {
        yield buffer.takeBytes();
        buffer = BytesBuilder(copy: false);
      }
    }
  }
  if (buffer.length > 0) yield buffer.takeBytes();
}

String _newId() =>
    Kdf.randomBytes(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Keeps the shared albums read from their spaces while the vault is open,
/// and makes, renames and fills them. The spaces themselves (sync, invites,
/// members, leaving) are the core's [SpacesController].
class SharedAlbumsController extends Notifier<SharedAlbumsState> {
  SharedSpaces? _spaces;
  final Map<String, StreamSubscription<Set<String>>> _watching = {};
  StreamSubscription<Set<String>>? _anchors;
  final Set<String> _flushed = {};
  Future<void>? _running;
  bool _again = false;
  bool _disposed = false;
  bool _sweeping = false;
  int _generation = 0;

  static const _anchorPrefix = 'zt.space-anchor/';
  static const _knownKey = 'gallery_known_shared_albums';

  @override
  SharedAlbumsState build() {
    _disposed = false;
    _generation++;
    final spacesValue = ref.watch(ztSharedSpacesProvider);
    _spaces = switch (spacesValue) {
      AsyncData(:final value) => value,
      _ => null,
    };
    ref.onDispose(() {
      _disposed = true;
      _anchors?.cancel();
      _anchors = null;
      for (final s in _watching.values) {
        s.cancel();
      }
      _watching.clear();
      _flushed.clear();
    });
    final spaces = _spaces;
    if (spaces == null) return SharedAlbumsState(ready: spacesValue.hasError);
    // Keeps every album syncing while the vault is open; read again
    // whenever a sync or a membership change lands.
    ref.listen(ztSpacesProvider, (_, _) => reload());
    ref.read(ztLocalStoreProvider.future).then((store) {
      if (_disposed || store is! ZtLocalStore) return;
      _anchors = store.changes.listen((ids) {
        if (ids.any((id) => id.startsWith(_anchorPrefix))) reload();
      });
    }).ignore();
    scheduleMicrotask(reload);
    return SharedAlbumsState(available: true, myUserId: spaces.myUserId);
  }

  /// Reads every album again from this phone's copies. Completes once a
  /// read that started after this call has finished.
  Future<void> reload() {
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    return _running = () async {
      try {
        do {
          _again = false;
          await _reload();
        } while (_again && !_disposed);
      } finally {
        _running = null;
      }
    }();
  }

  Future<void> _reload() async {
    final spaces = _spaces;
    if (spaces == null || _disposed) return;
    final generation = _generation;
    bool stale() => _disposed || generation != _generation;
    final spacesState = ref.read(ztSpacesProvider);
    final albums = <SharedAlbum>[];
    final listed = <String>{};
    for (final e in spacesState.entries) {
      final id = e.info.id;
      listed.add(id);
      final space = e.space;
      if (space == null || space.gone) {
        albums.add(_waiting(id, e.joinCode));
        continue;
      }
      _watch(space);
      final List<LocalItem> items;
      try {
        items = await space.store.all();
      } on Object {
        if (stale()) return; // closed by a lock
        continue;
      }
      if (stale()) return;
      albums.add(
        readAlbum(
          spaceId: id,
          isAdmin: space.isAdmin,
          members: space.members,
          items: items,
          joinCode: e.joinCode,
        ),
      );
      if (_flushed.add(id)) _flushUploads(id);
    }
    // Invites this account answered: the owner hasn't let it in yet.
    try {
      final store = await ref.read(ztLocalStoreProvider.future);
      for (final item in await store.all()) {
        if (item.deleted || !item.itemId.startsWith(_anchorPrefix)) continue;
        final id = item.itemId.substring(_anchorPrefix.length);
        final code = item.json?['verificationCode'];
        if (listed.contains(id) || code is! String) continue;
        albums.add(_waiting(id, code));
      }
    } on Object {
      // Closed by a lock.
    }
    if (stale()) return;
    for (final gone
        in _watching.keys.where((id) => !listed.contains(id)).toList()) {
      await _watching.remove(gone)?.cancel();
    }
    if (stale()) return;
    albums.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final settled = spacesState.ready && !spacesState.loading;
    state = state.copyWith(albums: albums, ready: settled);
    if (settled && spacesState.error == null) unawaited(_sweep(listed));
  }

  static SharedAlbum _waiting(String spaceId, String? code) => SharedAlbum(
    spaceId: spaceId,
    name: '',
    isAdmin: false,
    members: const [],
    photos: const [],
    waiting: true,
    joinCode: code,
  );

  void _watch(SharedSpace space) {
    if (_watching.containsKey(space.id)) return;
    final store = space.store;
    if (store is ZtLocalStore) {
      _watching[space.id] = store.changes.listen((_) => reload());
    }
  }

  /// Uploads that waited for the network (added offline, app closed).
  void _flushUploads(String spaceId) {
    try {
      ref.read(sharedFilesProvider).flush(spaceId).catchError((Object _) {});
    } on Object {
      // Signed out meanwhile.
    }
  }

  /// Albums this account was in and no longer is (left, removed, deleted):
  /// the files it uploaded there are deleted from the server. Albums are
  /// remembered on this phone once seen, and the server is asked once more
  /// before anything is deleted.
  Future<void> _sweep(Set<String> listed) async {
    final spaces = _spaces;
    if (_sweeping || spaces == null) return;
    _sweeping = true;
    try {
      final prefs = ref.read(ztPreferencesStoreProvider);
      final key = '${_knownKey}_${spaces.myUserId}';
      final known = {
        for (final id in ((await prefs.read(key)) ?? '').split(','))
          if (id.isNotEmpty) id,
      };
      final next = {...known, ...listed};
      final gone = known.difference(listed);
      if (gone.isNotEmpty) {
        final fresh = {for (final i in await spaces.list()) i.id};
        final files = ref.read(sharedFilesProvider);
        for (final id in gone) {
          if (fresh.contains(id)) continue;
          try {
            await files.sweep(id);
            next.remove(id);
          } on Object {
            // Offline: tried again next time.
          }
        }
      }
      if (next.length != known.length || !next.containsAll(known)) {
        await prefs.write(key, next.join(','));
      }
    } on Object {
      // Offline or locked: tried again next time.
    } finally {
      _sweeping = false;
    }
  }

  SpacesController _require() {
    if (!state.available) throw StateError("Sharing isn't available now.");
    return ref.read(ztSpacesProvider.notifier);
  }

  /// A new album named [name], with this account as its owner. Returns its
  /// space id.
  Future<String> create({required String name, required String myName}) async {
    final spaces = _require();
    final space = await spaces.create(myName: myName);
    await spaces.save(
      space.id,
      albumItemId,
      SharedAlbumMeta(name: name).toJson(),
    );
    await reload();
    return space.id;
  }

  /// Renames an album (owners only).
  Future<void> rename(String spaceId, String name) async {
    if (state[spaceId]?.isAdmin != true) {
      throw StateError("Only the album's owners can rename it.");
    }
    await _require().save(
      spaceId,
      albumItemId,
      SharedAlbumMeta(name: name).toJson(),
    );
    await reload();
  }

  /// Encrypts and uploads [photos] into the album, one by one. Returns how
  /// many could not be added.
  Future<int> addPhotos(String spaceId, List<NewSharedPhoto> photos) async {
    final spaces = _require();
    final files = ref.read(sharedFilesProvider);
    final me = state.myUserId!;
    var done = 0, failed = 0;
    void progress() {
      final uploads = {...state.uploads};
      if (done + failed >= photos.length) {
        uploads.remove(spaceId);
      } else {
        uploads[spaceId] = UploadProgress(done + failed, photos.length);
      }
      state = state.copyWith(uploads: uploads);
    }

    progress();
    for (final p in photos) {
      final parts = <ZtAttachmentRef>[];
      ZtAttachmentRef? thumb;
      try {
        var size = 0;
        await for (final piece in splitInto(p.content(), sharedPartBytes)) {
          parts.add(await files.put(spaceId, piece, mime: p.mime));
          size += piece.length;
        }
        if (parts.isEmpty) throw StateError('Nothing to add');
        final preview = await p.thumbnail?.call();
        if (preview != null && preview.isNotEmpty) {
          thumb = await files.put(spaceId, preview, mime: 'image/jpeg');
        }
        final photo = SharedPhoto(
          id: _newId(),
          owner: me,
          isVideo: p.isVideo,
          mime: p.mime,
          takenAt: p.takenAt,
          addedAt: DateTime.now(),
          size: size,
          files: parts,
          thumb: thumb,
          width: p.width,
          height: p.height,
          duration: p.duration,
        );
        await spaces.save(spaceId, photo.itemId, photo.toJson());
        done++;
      } on Object {
        failed++;
        await files.delete(spaceId, [...parts, ?thumb]).catchError((_) {});
      }
      if (_disposed) break;
      progress();
    }
    await reload();
    return failed;
  }

  /// Removes this account's own [photo] from the album, for everyone.
  Future<void> deletePhoto(String spaceId, SharedPhoto photo) async {
    if (photo.owner != state.myUserId) {
      throw StateError('Only whoever added a photo can remove it.');
    }
    await _require().delete(spaceId, photo.itemId);
    await ref.read(sharedFilesProvider).delete(spaceId, photo.allFiles);
    await reload();
  }

  /// Gives up on an invite the owner hasn't answered.
  Future<void> stopWaiting(String spaceId) async {
    await ref
        .read(ztSyncControllerProvider.notifier)
        .delete(SharedSpaces.anchorId(spaceId));
    await reload();
  }
}

final sharedAlbumsProvider =
    NotifierProvider<SharedAlbumsController, SharedAlbumsState>(
      SharedAlbumsController.new,
    );
