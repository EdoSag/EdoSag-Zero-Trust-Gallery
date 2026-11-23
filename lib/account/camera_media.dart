import 'package:zero_trust_core/zero_trust_core.dart';

/// A vault photo or video kept in the Zero Trust account. The file itself is
/// an encrypted attachment whose key lives only here, inside the item (which
/// is encrypted too): the server sees sizes and times, nothing else.
///
/// Written by ZT Camera's vault backup (and, later, Gallery's own backup);
/// Gallery opens the same items with Camera's keys (`dataAppId: 'camera'`).
/// Keep this in step with Zero-Trust-Camera
/// `lib/private_vault/vault_backup.dart`: only add optional fields, never
/// rename or drop one.
class CameraMedia {
  const CameraMedia({
    required this.id,
    required this.type,
    required this.mime,
    required this.takenAt,
    required this.size,
    required this.file,
    this.parts = const [],
    this.favourite = false,
    this.albums = const [],
    this.lat,
    this.lon,
    this.saver = false,
    this.thumb,
  });

  final String id;

  /// "photo" or "video".
  final String type;
  final String mime;
  final DateTime takenAt;
  final int size;
  final ZtAttachmentRef file;

  /// A video over the attachment size limit is kept as several files, in
  /// order; [file] is then the first of them. Empty for everything else.
  final List<ZtAttachmentRef> parts;
  final bool favourite;

  /// Ids of [CameraAlbum]s this item is in.
  final List<String> albums;

  /// Where it was taken, if the owner chose to keep places in the vault.
  /// Inside the encrypted item, like everything else here.
  final double? lat;
  final double? lon;

  /// The backed-up file is a smaller copy (space saver), not the original.
  final bool saver;

  /// A small preview, encrypted like the file, so another phone can show
  /// what is in the account without downloading everything. Null for items
  /// backed up before previews existed.
  final ZtAttachmentRef? thumb;

  bool get isVideo => type == 'video';

  /// Every file this item is kept in.
  List<ZtAttachmentRef> get files => parts.isEmpty ? [file] : parts;

  CameraMedia copyWith({bool? favourite, List<String>? albums}) => CameraMedia(
    id: id,
    type: type,
    mime: mime,
    takenAt: takenAt,
    size: size,
    file: file,
    parts: parts,
    favourite: favourite ?? this.favourite,
    albums: albums ?? this.albums,
    lat: lat,
    lon: lon,
    saver: saver,
    thumb: thumb,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'mime': mime,
    'takenAt': takenAt.millisecondsSinceEpoch,
    'size': size,
    'file': file.toJson(),
    if (parts.isNotEmpty) 'parts': [for (final p in parts) p.toJson()],
    'favourite': favourite,
    'albums': albums,
    if (lat != null && lon != null) ...{'lat': lat, 'lon': lon},
    if (saver) 'saver': true,
    if (thumb != null) 'thumb': thumb!.toJson(),
  };

  static CameraMedia fromJson(
    String _,
    Map<String, Object?> j,
    DateTime _,
  ) => CameraMedia(
    id: j['id']! as String,
    type: j['type'] as String? ?? 'photo',
    mime: j['mime'] as String? ?? 'image/jpeg',
    takenAt: DateTime.fromMillisecondsSinceEpoch(
      (j['takenAt'] as num?)?.toInt() ?? 0,
    ),
    size: (j['size'] as num?)?.toInt() ?? 0,
    file: ZtAttachmentRef.fromJson((j['file']! as Map).cast<String, Object?>()),
    parts: [
      for (final p in (j['parts'] as List<Object?>? ?? const []))
        if (p is Map) ZtAttachmentRef.fromJson(p.cast<String, Object?>()),
    ],
    favourite: j['favourite'] == true,
    albums: [
      for (final a in (j['albums'] as List<Object?>? ?? const []))
        if (a is String) a,
    ],
    lat: (j['lat'] as num?)?.toDouble(),
    lon: (j['lon'] as num?)?.toDouble(),
    saver: j['saver'] == true,
    thumb: j['thumb'] is Map
        ? ZtAttachmentRef.fromJson((j['thumb']! as Map).cast<String, Object?>())
        : null,
  );
}

/// A vault album, kept in the account so a restore can put items back in it.
class CameraAlbum {
  const CameraAlbum({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, Object?> toJson() => {'id': id, 'name': name};

  static CameraAlbum fromJson(String _, Map<String, Object?> j, DateTime _) =>
      CameraAlbum(id: j['id']! as String, name: j['name'] as String? ?? '');
}

final cameraMediaCollection = ZtCollection<CameraMedia>(
  kind: 'camera_media',
  fromJson: CameraMedia.fromJson,
  toJson: (m) => m.toJson(),
  idOf: (m) => m.id,
);

final cameraAlbumCollection = ZtCollection<CameraAlbum>(
  kind: 'camera_album',
  fromJson: CameraAlbum.fromJson,
  toJson: (a) => a.toJson(),
  idOf: (a) => a.id,
);
