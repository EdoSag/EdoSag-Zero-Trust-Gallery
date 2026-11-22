import 'dart:async';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

/// How much of the phone's photos the app may see.
enum PhoneAccess {
  /// Not asked yet, or refused: nothing shows.
  none,

  /// Android 14 and later: only the photos the person picked.
  some,
  all,
}

/// One photo or video on the phone (Android's MediaStore).
class PhoneMedia {
  const PhoneMedia({
    required this.id,
    required this.isVideo,
    required this.takenAt,
    this.width = 0,
    this.height = 0,
    this.duration = Duration.zero,
    this.name,
    this.mime,
    this.folder,
    this.entity,
  });

  final String id;
  final bool isVideo;

  /// When it was taken (or, without that, added to the phone).
  final DateTime takenAt;
  final int width;
  final int height;
  final Duration duration;

  /// The file name, as other apps see it.
  final String? name;
  final String? mime;

  /// The phone folder it is in ("Camera", "Screenshots", "WhatsApp Images").
  final String? folder;

  /// The MediaStore entry; null in tests.
  final AssetEntity? entity;

  @override
  bool operator ==(Object other) => other is PhoneMedia && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A phone folder ("album" in MediaStore terms).
class PhoneFolder {
  const PhoneFolder({
    required this.id,
    required this.name,
    required this.count,
    this.isAll = false,
    this.path,
  });

  final String id;
  final String name;
  final int count;

  /// The "every photo" folder the system lists first.
  final bool isAll;
  final AssetPathEntity? path;

  @override
  bool operator ==(Object other) => other is PhoneFolder && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The phone's photos and videos. The app reads them through this so tests
/// can use a fake; [MediaStoreLibrary] is the real one.
abstract class PhoneLibrary {
  /// What the app may see now, without asking.
  Future<PhoneAccess> access();

  /// Asks for access (the system dialog), and returns the result.
  Future<PhoneAccess> requestAccess();

  /// Every folder with photos or videos, the "all" one first.
  Future<List<PhoneFolder>> folders();

  /// Everything in [folder] (every photo when null), newest first.
  Future<List<PhoneMedia>> media({PhoneFolder? folder});

  /// A small square preview, for grids.
  ImageProvider thumbnail(PhoneMedia m, {int size = 256});

  /// The whole picture (a video's first frame), for the viewer.
  ImageProvider image(PhoneMedia m);

  /// The original file, or null when it can't be read (deleted meanwhile).
  Future<File?> file(PhoneMedia m);

  /// The original bytes.
  Future<Uint8List?> bytes(PhoneMedia m);

  /// The picture as a new JPEG with nothing hidden in it, at full size.
  Future<Uint8List?> plainJpeg(PhoneMedia m);

  /// Deletes [items] from the phone. Android asks the person to confirm;
  /// returns the ids that were deleted.
  Future<Set<String>> delete(List<PhoneMedia> items);

  /// Saves a photo to the phone (Pictures/ZT Gallery), taken at [takenAt].
  Future<void> savePhoto(Uint8List jpeg, {required DateTime takenAt});

  /// Saves a video file to the phone (Movies/ZT Gallery).
  Future<void> saveVideo(File file, {required DateTime takenAt});

  /// Lets the person pick more photos (Android 14 "some photos").
  Future<void> pickMore();

  /// The app's page in the phone's settings, to allow access.
  Future<void> openSettings();

  /// Fires when photos are added or removed on the phone.
  Stream<void> get changes;
}

/// The real [PhoneLibrary], on photo_manager (MediaStore).
class MediaStoreLibrary implements PhoneLibrary {
  MediaStoreLibrary();

  static const _option = PermissionRequestOption(
    // The place inside photos is never read, so not asked for.
    androidPermission: AndroidPermission(
      type: RequestType.common,
      mediaLocation: false,
    ),
  );

  final _changes = StreamController<void>.broadcast();
  bool _listening = false;

  static PhoneAccess _map(PermissionState s) => switch (s) {
    PermissionState.authorized => PhoneAccess.all,
    PermissionState.limited => PhoneAccess.some,
    _ => PhoneAccess.none,
  };

  @override
  Future<PhoneAccess> access() async {
    try {
      return _map(
        await PhotoManager.getPermissionState(requestOption: _option),
      );
    } on PlatformException {
      return PhoneAccess.none;
    }
  }

  @override
  Future<PhoneAccess> requestAccess() async {
    final a = _map(
      await PhotoManager.requestPermissionExtend(requestOption: _option),
    );
    if (a != PhoneAccess.none) _listen();
    return a;
  }

  void _listen() {
    if (_listening) return;
    _listening = true;
    PhotoManager.addChangeCallback((_) => _changes.add(null));
    unawaited(PhotoManager.startChangeNotify());
  }

  @override
  Stream<void> get changes {
    _listen();
    return _changes.stream;
  }

  @override
  Future<List<PhoneFolder>> folders() async {
    final paths = await PhotoManager.getAssetPathList(type: RequestType.common);
    final folders = <PhoneFolder>[];
    for (final p in paths) {
      final count = await p.assetCountAsync;
      if (count == 0) continue;
      folders.add(
        PhoneFolder(
          id: p.id,
          name: p.name,
          count: count,
          isAll: p.isAll,
          path: p,
        ),
      );
    }
    return folders;
  }

  @override
  Future<List<PhoneMedia>> media({PhoneFolder? folder}) async {
    var path = folder?.path;
    if (path == null) {
      final all = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        onlyAll: true,
      );
      if (all.isEmpty) return const [];
      path = all.first;
    }
    final out = <PhoneMedia>[];
    const size = 500;
    for (var page = 0; ; page++) {
      final batch = await path.getAssetListPaged(page: page, size: size);
      for (final e in batch) {
        if (e.type != AssetType.image && e.type != AssetType.video) continue;
        out.add(_wrap(e, folder: folder?.isAll == false ? folder!.name : null));
      }
      if (batch.length < size) break;
    }
    return out;
  }

  static PhoneMedia _wrap(AssetEntity e, {String? folder}) => PhoneMedia(
    id: e.id,
    isVideo: e.type == AssetType.video,
    // MediaStore's "date taken" (createDateTime) is 1970 for some files
    // without one; the date added is better than that.
    takenAt: e.createDateTime.year > 1971
        ? e.createDateTime
        : e.modifiedDateTime,
    width: e.orientatedWidth,
    height: e.orientatedHeight,
    duration: e.videoDuration,
    name: e.title,
    mime: e.mimeType,
    folder:
        folder ??
        e.relativePath?.split('/').where((s) => s.isNotEmpty).lastOrNull,
    entity: e,
  );

  @override
  ImageProvider thumbnail(PhoneMedia m, {int size = 256}) =>
      AssetEntityImageProvider(
        m.entity!,
        isOriginal: false,
        thumbnailSize: ThumbnailSize.square(size),
      );

  @override
  ImageProvider image(PhoneMedia m) => m.isVideo
      ? AssetEntityImageProvider(
          m.entity!,
          isOriginal: false,
          thumbnailSize: const ThumbnailSize(1440, 1440),
        )
      : AssetEntityImageProvider(m.entity!);

  @override
  Future<File?> file(PhoneMedia m) => m.entity!.originFile;

  @override
  Future<Uint8List?> bytes(PhoneMedia m) => m.entity!.originBytes;

  @override
  Future<Uint8List?> plainJpeg(PhoneMedia m) {
    final e = m.entity!;
    final w = e.orientatedWidth, h = e.orientatedHeight;
    if (w <= 0 || h <= 0) return Future.value();
    // Android draws the picture (turned the right way up) and saves it as a
    // new JPEG: nothing of the original's hidden details comes along.
    return e.thumbnailDataWithSize(ThumbnailSize(w, h), quality: 95);
  }

  @override
  Future<Set<String>> delete(List<PhoneMedia> items) async =>
      (await PhotoManager.editor.deleteWithIds([
        for (final m in items) m.id,
      ])).toSet();

  @override
  Future<void> savePhoto(Uint8List jpeg, {required DateTime takenAt}) =>
      PhotoManager.editor.saveImage(
        jpeg,
        filename: 'ZT_${takenAt.millisecondsSinceEpoch}.jpg',
        relativePath: 'Pictures/ZT Gallery',
        creationDate: takenAt,
      );

  @override
  Future<void> saveVideo(File file, {required DateTime takenAt}) =>
      PhotoManager.editor.saveVideo(
        file,
        title: 'ZT_${takenAt.millisecondsSinceEpoch}.mp4',
        relativePath: 'Movies/ZT Gallery',
        creationDate: takenAt,
      );

  @override
  Future<void> pickMore() => PhotoManager.presentLimited();

  @override
  Future<void> openSettings() => PhotoManager.openSetting();
}

final phoneLibraryProvider = Provider<PhoneLibrary>(
  (ref) => MediaStoreLibrary(),
);

/// What the app may see of the phone's photos; [PhoneAccessController.ask]
/// asks for more.
final phoneAccessProvider =
    AsyncNotifierProvider<PhoneAccessController, PhoneAccess>(
      PhoneAccessController.new,
    );

class PhoneAccessController extends AsyncNotifier<PhoneAccess> {
  @override
  Future<PhoneAccess> build() => ref.read(phoneLibraryProvider).access();

  Future<PhoneAccess> ask() async {
    final a = await ref.read(phoneLibraryProvider).requestAccess();
    state = AsyncData(a);
    return a;
  }

  /// Checks again (back from the phone's settings).
  Future<void> recheck() async {
    state = AsyncData(await ref.read(phoneLibraryProvider).access());
  }
}

/// Every photo and video on the phone, newest first; reloads when the phone
/// says something changed.
final phoneMediaProvider = FutureProvider<List<PhoneMedia>>((ref) async {
  final access = await ref.watch(phoneAccessProvider.future);
  if (access == PhoneAccess.none) return const [];
  final library = ref.watch(phoneLibraryProvider);
  final sub = library.changes.listen((_) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  return library.media();
});

/// The phone's folders, the "all" one left out (the Photos tab is that).
final phoneFoldersProvider = FutureProvider<List<PhoneFolder>>((ref) async {
  final access = await ref.watch(phoneAccessProvider.future);
  if (access == PhoneAccess.none) return const [];
  final library = ref.watch(phoneLibraryProvider);
  final sub = library.changes.listen((_) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  return [
    for (final f in await library.folders())
      if (!f.isAll) f,
  ];
});

/// What is in one folder, newest first.
final folderMediaProvider =
    FutureProvider.family<List<PhoneMedia>, PhoneFolder>((ref, folder) async {
      final library = ref.watch(phoneLibraryProvider);
      final sub = library.changes.listen((_) => ref.invalidateSelf());
      ref.onDispose(sub.cancel);
      return library.media(folder: folder);
    });
