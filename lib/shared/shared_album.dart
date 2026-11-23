import 'package:zero_trust_core/zero_trust_core.dart';

/// Shared albums, on core Z24 shared spaces: one space per album. Inside a
/// space, the item [albumItemId] names the album and every photo or video
/// is an item `photo/<owner's user id>/<id>`. Everything is end-to-end
/// encrypted with the space's key, which only members hold; the files are
/// encrypted attachments whose keys live only inside those items. The
/// server sees member ids, sizes and times, never names or pictures.
///
/// Only owners (space admins) rename the album; every member adds photos;
/// each photo can be removed only by whoever added it.
const gallerySpacePolicy = SpacePolicy(
  adminOnlyKinds: {SharedAlbumMeta.kind},
  ownedPrefixes: {SharedPhoto.prefix},
);

/// The item that names a shared album inside its space.
const albumItemId = 'album';

/// The album's name, kept in the space.
class SharedAlbumMeta {
  const SharedAlbumMeta({required this.name});

  static const kind = 'gallery_album';

  final String name;

  Map<String, Object?> toJson() => {'kind': kind, 'name': name};

  static SharedAlbumMeta? fromJson(Map<String, Object?>? j) =>
      j == null || j['kind'] != kind
      ? null
      : SharedAlbumMeta(name: j['name'] as String? ?? '');
}

/// One photo or video in a shared album.
class SharedPhoto {
  const SharedPhoto({
    required this.id,
    required this.owner,
    required this.isVideo,
    required this.mime,
    required this.takenAt,
    required this.addedAt,
    required this.size,
    required this.files,
    this.thumb,
    this.width = 0,
    this.height = 0,
    this.duration = Duration.zero,
  });

  static const kind = 'gallery_photo';
  static const prefix = 'photo/';

  /// Random, 32 hex characters.
  final String id;

  /// The member who added it; only they may remove it.
  final String owner;
  final bool isVideo;
  final String mime;
  final DateTime takenAt;
  final DateTime addedAt;

  /// Bytes of the whole file.
  final int size;

  /// The file, in order: big files are kept as several attachments (each
  /// is at most the attachment limit), joined back when read.
  final List<ZtAttachmentRef> files;

  /// A small preview, so the grid never downloads whole files.
  final ZtAttachmentRef? thumb;
  final int width;
  final int height;
  final Duration duration;

  String get itemId => itemIdFor(owner, id);

  static String itemIdFor(String owner, String id) => '$prefix$owner/$id';

  Map<String, Object?> toJson() => {
    'kind': kind,
    'id': id,
    'owner': owner,
    'type': isVideo ? 'video' : 'photo',
    'mime': mime,
    'takenAt': takenAt.millisecondsSinceEpoch,
    'addedAt': addedAt.millisecondsSinceEpoch,
    'size': size,
    'files': [for (final f in files) f.toJson()],
    if (thumb != null) 'thumb': thumb!.toJson(),
    if (width > 0) 'width': width,
    if (height > 0) 'height': height,
    if (duration > Duration.zero) 'durationMs': duration.inMilliseconds,
  };

  /// Null for anything that isn't a well-formed photo item, or one whose
  /// id doesn't match its owner (written by someone else in their name).
  static SharedPhoto? fromItem(String itemId, Map<String, Object?>? j) {
    if (j == null || j['kind'] != kind) return null;
    try {
      final owner = j['owner']! as String;
      final id = j['id']! as String;
      if (itemId != itemIdFor(owner, id)) return null;
      final files = [
        for (final f in j['files']! as List<Object?>)
          ZtAttachmentRef.fromJson((f! as Map).cast<String, Object?>()),
      ];
      if (files.isEmpty) return null;
      DateTime time(Object? v) =>
          DateTime.fromMillisecondsSinceEpoch((v as num?)?.toInt() ?? 0);
      return SharedPhoto(
        id: id,
        owner: owner,
        isVideo: j['type'] == 'video',
        mime: j['mime'] as String? ?? 'image/jpeg',
        takenAt: time(j['takenAt']),
        addedAt: time(j['addedAt']),
        size: (j['size'] as num?)?.toInt() ?? 0,
        files: files,
        thumb: j['thumb'] is Map
            ? ZtAttachmentRef.fromJson(
                (j['thumb']! as Map).cast<String, Object?>(),
              )
            : null,
        width: (j['width'] as num?)?.toInt() ?? 0,
        height: (j['height'] as num?)?.toInt() ?? 0,
        duration: Duration(
          milliseconds: (j['durationMs'] as num?)?.toInt() ?? 0,
        ),
      );
    } on Object {
      return null;
    }
  }

  /// Every file this photo keeps, preview included.
  List<ZtAttachmentRef> get allFiles => [...files, ?thumb];
}

/// One shared album as the app shows it.
class SharedAlbum {
  const SharedAlbum({
    required this.spaceId,
    required this.name,
    required this.isAdmin,
    required this.members,
    required this.photos,
    this.waiting = false,
    this.joinCode,
  });

  final String spaceId;
  final String name;

  /// This account owns the album: it can rename it, let people in and
  /// delete it.
  final bool isAdmin;
  final List<SpaceMember> members;

  /// Newest first. Only photos of people still in the album: when someone
  /// leaves or is removed, what they added goes with them.
  final List<SharedPhoto> photos;

  /// Joined, but the owner hasn't let this account in yet (or the album's
  /// name hasn't arrived).
  final bool waiting;

  /// While [waiting]: the code to compare with the owner.
  final String? joinCode;

  String? nameOf(String userId) {
    for (final m in members) {
      if (m.userId == userId) return m.name;
    }
    return null;
  }

  SharedPhoto? photo(String id) {
    for (final p in photos) {
      if (p.id == id) return p;
    }
    return null;
  }
}

/// The album read from its space's items. [members] are the current ones.
SharedAlbum readAlbum({
  required String spaceId,
  required bool isAdmin,
  required List<SpaceMember> members,
  required Iterable<LocalItem> items,
  String? joinCode,
}) {
  SharedAlbumMeta? meta;
  final present = {for (final m in members) m.userId};
  final photos = <SharedPhoto>[];
  for (final item in items) {
    if (item.deleted) continue;
    if (item.itemId == albumItemId) {
      meta = SharedAlbumMeta.fromJson(item.json) ?? meta;
      continue;
    }
    if (!item.itemId.startsWith(SharedPhoto.prefix)) continue;
    final p = SharedPhoto.fromItem(item.itemId, item.json);
    if (p != null && present.contains(p.owner)) photos.add(p);
  }
  photos.sort((a, b) => b.takenAt.compareTo(a.takenAt));
  return SharedAlbum(
    spaceId: spaceId,
    name: meta?.name ?? '',
    isAdmin: isAdmin,
    members: members,
    photos: photos,
    waiting: meta == null,
    joinCode: joinCode,
  );
}
