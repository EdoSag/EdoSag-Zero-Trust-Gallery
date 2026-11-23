import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import 'camera_media.dart';

/// The account's photos and albums: the items ZT Camera (and later Gallery)
/// backs up. The files are encrypted attachments; their keys are inside the
/// items, which are encrypted too. Tests use a fake.
abstract class AccountPhotoStore {
  Future<List<CameraMedia>> media();
  Future<List<CameraAlbum>> albums();

  /// The decrypted file (one part of a long video: see [CameraMedia.parts]).
  Future<Uint8List> read(ZtAttachmentRef ref);

  /// Fires when items change (a sync brought new ones, another phone
  /// deleted some).
  Stream<void> get changes;
}

/// [AccountPhotoStore] on the core: the synced store and attachments of
/// the data Gallery opens (Camera's). Needs the vault unlocked.
class CoreAccountPhotoStore implements AccountPhotoStore {
  CoreAccountPhotoStore(this._ref);

  final Ref _ref;

  Future<LocalItemStore> get _store => _ref.read(ztLocalStoreProvider.future);

  @override
  Future<List<CameraMedia>> media() async =>
      cameraMediaCollection.list(await _store);

  @override
  Future<List<CameraAlbum>> albums() async =>
      cameraAlbumCollection.list(await _store);

  @override
  Future<Uint8List> read(ZtAttachmentRef ref) async =>
      (await _ref.read(ztAttachmentsProvider.future)).read(ref);

  @override
  Stream<void> get changes async* {
    final store = await _store;
    if (store is ZtLocalStore) yield* store.changes;
  }
}

final accountPhotoStoreProvider = Provider<AccountPhotoStore>(
  CoreAccountPhotoStore.new,
);

/// Whether the account's photos can be read now: signed in and unlocked.
final accountOpenProvider = Provider<bool>(
  (ref) => ref.watch(vaultControllerProvider) is VaultUnlocked,
);

/// The account's photos and videos, newest first, while it is open.
final accountMediaProvider = StreamProvider<List<CameraMedia>>((ref) async* {
  if (!ref.watch(accountOpenProvider)) {
    yield const [];
    return;
  }
  // A finished sync may have brought items in.
  ref.watch(ztSyncControllerProvider.select((s) => s.lastSyncedAt));
  final store = ref.watch(accountPhotoStoreProvider);
  List<CameraMedia> sorted(List<CameraMedia> all) =>
      all..sort((a, b) => b.takenAt.compareTo(a.takenAt));
  yield sorted(await store.media());
  await for (final _ in store.changes) {
    yield sorted(await store.media());
  }
});

/// The account's albums (made in ZT Camera's vault), by name.
final accountAlbumsProvider = FutureProvider<List<CameraAlbum>>((ref) async {
  if (!ref.watch(accountOpenProvider)) return const [];
  ref.watch(accountMediaProvider);
  final all = await ref.watch(accountPhotoStoreProvider).albums();
  return all
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
});

/// An encrypted attachment shown as a picture: downloaded (or read from
/// this phone's encrypted copy) and decrypted in memory, never written out
/// in the clear. Two with the same file are the same image, so the image
/// cache keeps one.
@immutable
class AttachmentImage extends ImageProvider<AttachmentImage> {
  const AttachmentImage(this.file, this.load);

  final ZtAttachmentRef file;
  final Future<Uint8List> Function(ZtAttachmentRef ref) load;

  @override
  Future<AttachmentImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    AttachmentImage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: () async {
      final bytes = await load(key.file);
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      return decode(buffer);
    }(),
    scale: 1,
    debugLabel: 'AttachmentImage(${file.id})',
  );

  @override
  bool operator ==(Object other) =>
      other is AttachmentImage && other.file.id == file.id;

  @override
  int get hashCode => file.id.hashCode;
}

/// Where a video from the account is put together to play: the app's own
/// cache folder (no other app can read it), emptied before the next one
/// and when the app starts. Tests replace it.
final playDirProvider = Provider<Future<Directory> Function()>(
  (ref) =>
      () async =>
          Directory('${(await getTemporaryDirectory()).path}/account_play'),
);

/// Writes [m]'s video (all its parts, in order) to a file for the player.
Future<File> accountVideoFile(
  AccountPhotoStore store,
  Directory dir,
  CameraMedia m,
) async {
  if (await dir.exists()) await dir.delete(recursive: true);
  await dir.create(recursive: true);
  final f = File('${dir.path}/${m.id}.mp4');
  final sink = f.openWrite();
  try {
    for (final part in m.files) {
      sink.add(await store.read(part));
    }
  } finally {
    await sink.close();
  }
  return f;
}
