import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:image/image.dart' as img;
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_gallery/account/account_photos.dart';
import 'package:zerotrust_gallery/account/camera_media.dart';
import 'package:zerotrust_gallery/app/account.dart';
import 'package:zerotrust_gallery/app/gallery_config.dart';
import 'package:zerotrust_gallery/l10n/l10n.dart';
import 'package:zerotrust_gallery/phone/phone_library.dart';
import 'package:zerotrust_gallery/viewer/share_out.dart';

/// A small real PNG, so pictures render in tests.
final Uint8List testPng = Uint8List.fromList(
  img.encodePng(
    img.Image(width: 4, height: 4)..clear(img.ColorRgb8(120, 90, 200)),
  ),
);

/// A small real JPEG.
final Uint8List testJpeg = Uint8List.fromList(
  img.encodeJpg(
    img.Image(width: 8, height: 8)..clear(img.ColorRgb8(10, 200, 30)),
  ),
);

class FakePhoneLibrary implements PhoneLibrary {
  FakePhoneLibrary({this.items = const [], this.granted = PhoneAccess.all});

  List<PhoneMedia> items;
  PhoneAccess granted;
  PhoneAccess afterAsking = PhoneAccess.all;
  int asked = 0;
  int settingsOpened = 0;
  final deleted = <String>[];
  final saved = <String>[];
  final _changes = StreamController<void>.broadcast();

  @override
  Future<PhoneAccess> access() async => granted;

  @override
  Future<PhoneAccess> requestAccess() async {
    asked++;
    granted = afterAsking;
    return granted;
  }

  @override
  Future<List<PhoneFolder>> folders() async {
    final byFolder = <String, int>{};
    for (final m in items) {
      byFolder[m.folder ?? ''] = (byFolder[m.folder ?? ''] ?? 0) + 1;
    }
    return [
      PhoneFolder(id: 'all', name: 'All', count: items.length, isAll: true),
      for (final e in byFolder.entries)
        PhoneFolder(id: e.key, name: e.key, count: e.value),
    ];
  }

  @override
  Future<List<PhoneMedia>> media({PhoneFolder? folder}) async => [
    for (final m in items)
      if (folder == null || folder.isAll || m.folder == folder.id) m,
  ];

  @override
  ImageProvider thumbnail(PhoneMedia m, {int size = 256}) =>
      MemoryImage(testPng);

  @override
  ImageProvider image(PhoneMedia m) => MemoryImage(testPng);

  @override
  Future<File?> file(PhoneMedia m) async => null;

  @override
  Future<Uint8List?> bytes(PhoneMedia m) async => testJpeg;

  @override
  Future<Uint8List?> plainJpeg(PhoneMedia m) async => testJpeg;

  @override
  Future<Set<String>> delete(List<PhoneMedia> list) async {
    deleted.addAll(list.map((m) => m.id));
    items = [
      for (final m in items)
        if (!deleted.contains(m.id)) m,
    ];
    _changes.add(null);
    return {for (final m in list) m.id};
  }

  @override
  Future<void> savePhoto(Uint8List jpeg, {required DateTime takenAt}) async =>
      saved.add('photo');

  @override
  Future<void> saveVideo(File file, {required DateTime takenAt}) async =>
      saved.add('video');

  @override
  Future<void> pickMore() async {}

  @override
  Future<void> openSettings() async => settingsOpened++;

  @override
  Stream<void> get changes => _changes.stream;
}

class FakeAccountStore implements AccountPhotoStore {
  FakeAccountStore({this.items = const [], this.albumList = const []});

  List<CameraMedia> items;
  List<CameraAlbum> albumList;
  final reads = <String>[];

  @override
  Future<List<CameraMedia>> media() async => [...items];

  @override
  Future<List<CameraAlbum>> albums() async => [...albumList];

  @override
  Future<Uint8List> read(ZtAttachmentRef ref) async {
    reads.add(ref.id);
    return testPng;
  }

  @override
  Stream<void> get changes => const Stream.empty();
}

ZtAttachmentRef fileRef(String id) =>
    ZtAttachmentRef(id: id, key: Uint8List(32), size: testPng.length);

CameraMedia cameraMedia(
  String id,
  DateTime takenAt, {
  bool video = false,
  List<String> albums = const [],
}) => CameraMedia(
  id: id,
  type: video ? 'video' : 'photo',
  mime: video ? 'video/mp4' : 'image/jpeg',
  takenAt: takenAt,
  size: 2500000,
  file: fileRef('f$id'),
  thumb: fileRef('t$id'),
  albums: albums,
);

PhoneMedia phoneMedia(
  String id,
  DateTime takenAt, {
  bool video = false,
  String folder = 'Camera',
}) => PhoneMedia(
  id: id,
  isVideo: video,
  takenAt: takenAt,
  width: 4000,
  height: 3000,
  name: 'IMG_$id.jpg',
  folder: folder,
  duration: video ? const Duration(seconds: 7) : Duration.zero,
);

/// Nobody is signed in, which is how Gallery starts.
class SignedOutBackend implements AccountBackend {
  @override
  String? get currentUserId => null;
  @override
  String? get currentEmail => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const hebrew = Locale('he');

/// One screen inside the app's theme and languages, on fakes.
Widget testApp({
  required Widget home,
  FakePhoneLibrary? library,
  FakeAccountStore? account,
  bool signedIn = false,
  Locale? locale,
  List<Override> overrides = const [],
  List<List<String>>? shared,
}) => ProviderScope(
  overrides: [
    ...overrides,
    ztAppConfigProvider.overrideWithValue(galleryAppConfig),
    ztPreferencesStoreProvider.overrideWithValue(InMemoryPreferencesStore()),
    accountServiceProvider.overrideWithValue(
      AccountService(SignedOutBackend()),
    ),
    phoneLibraryProvider.overrideWithValue(library ?? FakePhoneLibrary()),
    accountPhotoStoreProvider.overrideWithValue(account ?? FakeAccountStore()),
    signedInProvider.overrideWithValue(signedIn),
    accountOpenProvider.overrideWithValue(signedIn),
    shareFilesProvider.overrideWithValue((paths) async => shared?.add(paths)),
    outgoingDirProvider.overrideWithValue(
      () async => Directory.systemTemp.createTempSync('zt_gallery_share'),
    ),
  ],
  child: MaterialApp(
    theme: ZtTheme.light(accent: galleryAccent),
    locale: locale,
    supportedLocales: ZtLanguages.supported,
    localizationsDelegates: const [AppL10n.delegate, ...ZtLanguages.delegates],
    home: home,
  ),
);
