import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_gallery/app/gallery_config.dart';
import 'package:zerotrust_gallery/shared/shared_album.dart';
import 'package:zerotrust_gallery/shared/shared_albums.dart';
import 'package:zerotrust_gallery/shared/shared_files.dart';

import 'support/fake_sync_backend.dart';
import 'support/fakes.dart';

const alice = '00000000-0000-4000-8000-00000000000a';
const bob = '00000000-0000-4000-8000-00000000000b';

class _Account extends AccountService {
  _Account(this.id) : super(SignedOutBackend());
  final String id;
  @override
  String? get currentUserId => id;
}

class _MemoryOpener implements SpaceStoreOpener {
  final Map<String, InMemoryItemStore> stores = {};
  @override
  Future<LocalItemStore> open(String spaceId) async =>
      stores.putIfAbsent(spaceId, InMemoryItemStore.new);
  @override
  Future<void> delete(String spaceId) async => stores.remove(spaceId);
  @override
  Future<void> closeAll() async {}
}

NewSharedPhoto photo(Uint8List bytes, DateTime takenAt) => NewSharedPhoto(
  isVideo: false,
  mime: 'image/jpeg',
  takenAt: takenAt,
  width: 8,
  height: 8,
  content: () => Stream.value(bytes),
  thumbnail: () async => testJpeg,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemorySpaceServer server;
  late InMemoryAttachmentBackend storage;

  ProviderContainer phone(String userId) {
    final opener = _MemoryOpener();
    final c = ProviderContainer(
      overrides: [
        ztAppConfigProvider.overrideWithValue(galleryAppConfig),
        ztSpacePolicyProvider.overrideWithValue(gallerySpacePolicy),
        ztPreferencesStoreProvider.overrideWithValue(
          InMemoryPreferencesStore(),
        ),
        accountServiceProvider.overrideWithValue(_Account(userId)),
        ztSyncBackendProvider.overrideWithValue(
          FakeSyncBackend()..serverNow = () => DateTime.now().toUtc(),
        ),
        ztDeviceIdStoreProvider.overrideWithValue(InMemoryDeviceIdStore()),
        ztLocalStoreProvider.overrideWith((ref) async {
          final appKey = ref.watch(
            vaultControllerProvider.select(
              (v) => v is VaultUnlocked ? v.appKey : null,
            ),
          );
          if (appKey == null) throw const VaultIsLocked();
          final store = await ZtLocalStore.open(appKey: appKey);
          ref.onDispose(store.close);
          return store;
        }),
        ztSpaceBackendProvider.overrideWithValue(server.backendFor(userId)),
        ztSpaceStoreOpenerProvider.overrideWithValue(opener),
        sharedFilesProvider.overrideWithValue(
          CoreSharedFiles(
            userId: userId,
            backend: storage,
            openCache: (_, _) async => InMemoryAttachmentCache(),
            deleteCache: (_, _) async {},
            list: (folder) async => [
              for (final path in storage.files.keys)
                if (path.startsWith('$folder/'))
                  path.substring(folder.length + 1),
            ],
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    c.listen(ztSyncControllerProvider, (_, _) {});
    c.listen(sharedAlbumsProvider, (_, _) {});
    return c;
  }

  Future<SharedAlbumsState> settled(
    ProviderContainer c,
    bool Function(SharedAlbumsState) test,
  ) async {
    for (var i = 0; i < 1000; i++) {
      final s = c.read(sharedAlbumsProvider);
      if (test(s)) return s;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('albums never settled: ${c.read(sharedAlbumsProvider).albums}');
  }

  Future<void> until(bool Function() test, String what) async {
    for (var i = 0; i < 1000; i++) {
      if (test()) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail(what);
  }

  setUp(() {
    server = InMemorySpaceServer();
    storage = InMemoryAttachmentBackend();
  });

  test('two phones share an album: create, add, invite, join, see, '
      'remove only your own, leave takes your photos along', () async {
    final a = phone(alice);
    final b = phone(bob);
    await a
        .read(vaultControllerProvider.notifier)
        .unlock(Uint8List.fromList(List.filled(32, 1)));
    await b
        .read(vaultControllerProvider.notifier)
        .unlock(Uint8List.fromList(List.filled(32, 2)));
    await settled(a, (s) => s.available && s.ready);
    await settled(b, (s) => s.available && s.ready);

    // Alice makes an album and adds a photo.
    final albums = a.read(sharedAlbumsProvider.notifier);
    final id = await albums.create(name: 'Trip', myName: 'Alice');
    expect(a.read(sharedAlbumsProvider)[id]!.name, 'Trip');
    expect(a.read(sharedAlbumsProvider)[id]!.isAdmin, isTrue);
    final original = Uint8List.fromList(List.generate(5000, (i) => i % 251));
    final taken = DateTime(2026, 11, 20, 9);
    expect(await albums.addPhotos(id, [photo(original, taken)]), 0);
    final mine = a.read(sharedAlbumsProvider)[id]!.photos.single;
    expect(mine.owner, alice);
    expect(mine.takenAt, taken);
    expect(mine.size, original.length);
    expect(mine.thumb, isNotNull);
    await a.read(sharedFilesProvider).flush(id);
    // Encrypted on the phone, under Alice's own id and the album's folder.
    final folder = '$alice/${spaceFolder(id)}/';
    expect(storage.files.keys, hasLength(2));
    expect(storage.files.keys, everyElement(startsWith(folder)));
    expect(storage.files.values, everyElement(isNot(original)));

    // Alice invites Bob; he waits with a code until she lets him in.
    final spaces = a.read(ztSpacesProvider.notifier);
    await spaces.syncNow(id);
    final link = await spaces.invite(id);
    final joined = await b
        .read(ztSpacesProvider.notifier)
        .answer(SpaceInviteLink.parse('$link'), myName: 'Bob');
    final waiting = await settled(b, (s) => s[id]?.waiting == true);
    expect(waiting[id]!.joinCode, joined.verificationCode);
    final pending = await spaces.pendingJoins(id);
    expect(pending.single.verificationCode, joined.verificationCode);
    await spaces.confirm(pending.single);

    // Bob sees the album, its photo, and can open the file.
    final seen = await settled(
      b,
      (s) => s[id]?.name == 'Trip' && s[id]!.photos.length == 1,
    );
    final theirs = seen[id]!.photos.single;
    expect(theirs.owner, alice);
    expect(seen[id]!.isAdmin, isFalse);
    expect(seen[id]!.nameOf(alice), 'Alice');
    expect(
      await readWhole(b.read(sharedFilesProvider), id, alice, theirs.files),
      original,
    );

    // Only whoever added a photo removes it.
    final bobs = b.read(sharedAlbumsProvider.notifier);
    await expectLater(bobs.deletePhoto(id, theirs), throwsStateError);
    // Nor may Bob rename Alice's album.
    await expectLater(bobs.rename(id, 'Mine'), throwsStateError);

    // Bob adds his own; Alice sees both.
    expect(await bobs.addPhotos(id, [photo(testJpeg, taken)]), 0);
    await b.read(sharedFilesProvider).flush(id);
    await b.read(ztSpacesProvider.notifier).syncNow(id);
    await settled(a, (s) => s[id]?.photos.length == 2);
    expect(storage.files.keys.where((k) => k.startsWith('$bob/')), isNotEmpty);

    // Alice removes hers: gone for both, and its files too.
    await albums.deletePhoto(id, mine);
    await a.read(sharedFilesProvider).flush(id);
    await spaces.syncNow(id);
    await settled(
      b,
      (s) => s[id]?.photos.every((p) => p.owner == bob) ?? false,
    );
    expect(storage.files.keys.where((k) => k.startsWith(folder)), isEmpty);

    // Bob leaves: what he added leaves with him, files included.
    await b.read(ztSpacesProvider.notifier).leave(id);
    await settled(b, (s) => s[id] == null);
    await until(
      () => storage.files.keys.every((k) => !k.startsWith('$bob/')),
      "Bob's files were never deleted",
    );
    await a.read(ztSpacesProvider.notifier).refresh();
    await spaces.syncNow(id);
    await settled(a, (s) => s[id]?.photos.isEmpty ?? false);
  });
}
