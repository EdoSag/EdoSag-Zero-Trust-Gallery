import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_gallery/shared/join_links.dart';
import 'package:zerotrust_gallery/shared/shared_album.dart';
import 'package:zerotrust_gallery/shared/shared_albums.dart';
import 'package:zerotrust_gallery/shared/shared_files.dart';
import 'package:zerotrust_gallery/ui/gallery_home.dart';

import 'support/fakes.dart';

LocalItem item(String id, Map<String, Object?>? json, {bool deleted = false}) =>
    LocalItem(
      itemId: id,
      json: json,
      updatedAt: DateTime.utc(2026, 11, 22),
      deleted: deleted,
    );

void main() {
  final t = DateTime(2026, 11, 22, 9);

  test('a photo item reads back as it was written', () {
    final p = sharedPhoto('p1', me, t, video: true);
    final back = SharedPhoto.fromItem(p.itemId, p.toJson())!;
    expect(back.id, 'p1');
    expect(back.owner, me);
    expect(back.isVideo, isTrue);
    expect(back.takenAt, t);
    expect(back.files.single.id, 'fp1');
    expect(back.thumb!.id, 'tp1');
    expect(back.duration, const Duration(seconds: 12));
    expect(back.allFiles.map((f) => f.id), ['fp1', 'tp1']);
    expect(p.itemId, 'photo/$me/p1');
  });

  test('a photo kept under someone else\'s id is not shown', () {
    final p = sharedPhoto('p1', me, t);
    expect(SharedPhoto.fromItem('photo/$friend/p1', p.toJson()), isNull);
    expect(SharedPhoto.fromItem(p.itemId, {'kind': 'other'}), isNull);
    expect(
      SharedPhoto.fromItem(p.itemId, {...p.toJson(), 'files': []}),
      isNull,
    );
  });

  test('the policy: only owners rename, each photo is its adder\'s', () {
    expect(gallerySpacePolicy.ownerOf('photo/$me/p1'), me);
    expect(gallerySpacePolicy.ownerOf(albumItemId), isNull);
    expect(
      gallerySpacePolicy.isAdminOnly(
        albumItemId,
        const SharedAlbumMeta(name: 'x').toJson(),
      ),
      isTrue,
    );
  });

  test('an album: its name, photos of current members only, newest first', () {
    final older = sharedPhoto('old', me, t);
    final newer = sharedPhoto('new', friend, t.add(const Duration(hours: 1)));
    final gone = sharedPhoto('gone', '00000000-0000-4000-8000-0000000000ff', t);
    final album = readAlbum(
      spaceId: 's',
      isAdmin: true,
      members: [member(me, 'Me', admin: true), member(friend, 'Dana')],
      items: [
        item(albumItemId, const SharedAlbumMeta(name: 'Trip').toJson()),
        item(older.itemId, older.toJson()),
        item(newer.itemId, newer.toJson()),
        item(gone.itemId, gone.toJson()),
        item('photo/$me/deleted', null, deleted: true),
      ],
    );
    expect(album.name, 'Trip');
    expect(album.waiting, isFalse);
    expect(album.photos.map((p) => p.id), ['new', 'old']);
    expect(album.nameOf(friend), 'Dana');
  });

  test('without its name item an album is still waiting', () {
    final album = readAlbum(
      spaceId: 's',
      isAdmin: false,
      members: const [],
      items: const [],
    );
    expect(album.waiting, isTrue);
  });

  test('files are split into pieces under the attachment limit', () async {
    final pieces = await splitInto(
      Stream.fromIterable([
        [1, 2, 3],
        [4, 5, 6, 7, 8],
        [9],
      ]),
      4,
    ).toList();
    expect(pieces, [
      [1, 2, 3, 4],
      [5, 6, 7, 8],
      [9],
    ]);
    expect(sharedPartBytes, lessThan(ZtAttachments.defaultMaxBytes));
  });

  test('a long file is read back whole from its pieces', () async {
    final files = FakeSharedFiles();
    final whole = await readWhole(files, 's', me, [fileRef('a'), fileRef('b')]);
    expect(whole, Uint8List.fromList([...testPng, ...testPng]));
    expect(
      spaceFolder('3f2b1c4d-0000-4000-8000-00000000000a'),
      'space_3f2b1c4d000040008000'
      '00000000000a',
    );
  });

  test('invite links: only Gallery ones are taken', () {
    expect(
      JoinLinks.isInvite(
        Uri.parse('https://zerotrust.bz/join/gallery#zt1.gallery.x'),
      ),
      isTrue,
    );
    expect(
      JoinLinks.isInvite(Uri.parse('https://zerotrust.bz/join/notes#zt1.x')),
      isFalse,
    );
    expect(
      JoinLinks.isInvite(Uri.parse('https://zerotrust.bz/join/gallery')),
      isFalse,
    );
    expect(
      JoinLinks.isInvite(Uri.parse('https://evil.example/join/gallery#zt1')),
      isFalse,
    );
  });

  testWidgets('an invite opened from a link opens the Sharing tab and the '
      'join page with the link filled in', (tester) async {
    const link = 'https://zerotrust.bz/join/gallery#zt1.gallery.abc';
    JoinLinks.offer(Uri.parse(link));
    await tester.pumpWidget(
      testApp(
        home: const GalleryHome(),
        signedIn: true,
        albums: FakeSharedAlbums(albumsState(const [])),
      ),
    );
    await tester.pumpAndSettle();
    expect(JoinLinks.pending.value, isNull);
    expect(find.text(link), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('No shared albums yet'), findsOneWidget);
  });

  testWidgets('signed out, an invite waits on the Sharing tab', (tester) async {
    const link = 'https://zerotrust.bz/join/gallery#zt1.gallery.def';
    JoinLinks.offer(Uri.parse(link));
    addTearDown(() => JoinLinks.pending.value = null);
    await tester.pumpWidget(testApp(home: const GalleryHome()));
    await tester.pumpAndSettle();
    expect(JoinLinks.pending.value, link);
    expect(find.byKey(const Key('sharingSignIn')), findsOneWidget);
  });
}
