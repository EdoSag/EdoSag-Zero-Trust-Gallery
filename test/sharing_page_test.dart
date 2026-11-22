import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_gallery/phone/phone_pages.dart';
import 'package:zerotrust_gallery/shared/shared_pages.dart';
import 'package:zerotrust_gallery/ui/gallery_home.dart';

import 'support/fakes.dart';

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 10);

  FakeSharedAlbums trip({bool admin = true}) => FakeSharedAlbums(
    albumsState([
      sharedAlbum(
        'trip',
        'Trip',
        admin: admin,
        photos: [
          sharedPhoto('mine', me, today.add(const Duration(hours: 1))),
          sharedPhoto('theirs', friend, today),
        ],
      ),
    ]),
  );

  testWidgets('signed out, the Sharing tab asks to sign in and offers no '
      'new album', (tester) async {
    await tester.pumpWidget(testApp(home: const SharingPage()));
    await tester.pumpAndSettle();

    expect(find.text('Shared albums'), findsWidgets);
    expect(find.byKey(const Key('sharingSignIn')), findsOneWidget);
    expect(find.byKey(const Key('newSharedAlbum')), findsNothing);
    expect(find.byKey(const Key('joinSharedAlbum')), findsNothing);
  });

  testWidgets('no albums yet: the empty message, New shared album at the '
      'bottom and Join on top', (tester) async {
    await tester.pumpWidget(
      testApp(
        home: const SharingPage(),
        signedIn: true,
        albums: FakeSharedAlbums(albumsState(const [])),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No shared albums yet'), findsOneWidget);
    final fab = tester.getRect(find.byKey(const Key('newSharedAlbum')));
    final join = tester.getRect(find.byKey(const Key('joinSharedAlbum')));
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    // The new-album button sits at the bottom end, the join button in the
    // bar on top.
    expect(fab.bottom, greaterThan(size.height - 100));
    expect(fab.right, greaterThan(size.width - 40));
    expect(join.top, lessThan(80));
  });

  testWidgets('albums list: name, count and people; waiting ones say so', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        home: const SharingPage(),
        signedIn: true,
        albums: FakeSharedAlbums(
          albumsState([
            sharedAlbum('trip', 'Trip', photos: [sharedPhoto('p', me, today)]),
            sharedAlbum('w', '', waiting: true, joinCode: '12 34 56'),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tripTile = find.byKey(const ValueKey('sharedAlbum_trip'));
    expect(
      find.descendant(of: tripTile, matching: find.text('Trip')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tripTile, matching: find.text('1 item · 2 people')),
      findsOneWidget,
    );
    final waitingTile = find.byKey(const ValueKey('sharedAlbum_w'));
    expect(
      find.descendant(
        of: waitingTile,
        matching: find.text('Waiting to be let in'),
      ),
      findsOneWidget,
    );
    // Listed one under the other.
    expect(
      tester.getRect(tripTile).bottom,
      lessThanOrEqualTo(tester.getRect(waitingTile).top),
    );

    // A waiting album shows the code to compare, and can be given up.
    await tester.tap(waitingTile);
    await tester.pumpAndSettle();
    expect(find.text('12 34 56'), findsOneWidget);
  });

  testWidgets('waiting: Stop waiting gives up on the invite', (tester) async {
    final albums = FakeSharedAlbums(
      albumsState([sharedAlbum('w', '', waiting: true, joinCode: '111 222')]),
    );
    await tester.pumpWidget(
      testApp(
        home: const SharedAlbumPage(spaceId: 'w'),
        signedIn: true,
        albums: albums,
      ),
    );
    await tester.pumpAndSettle();
    final code = tester.getRect(find.byKey(const Key('waitingCode')));
    final stop = tester.getRect(find.byKey(const Key('stopWaiting')));
    expect(code.bottom, lessThanOrEqualTo(stop.top));
    await tester.tap(find.byKey(const Key('stopWaiting')));
    await tester.pumpAndSettle();
    expect(albums.stopped, ['w']);
  });

  testWidgets('an album: its photos in the grid, actions in the bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        home: const SharedAlbumPage(spaceId: 'trip'),
        signedIn: true,
        albums: trip(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trip'), findsOneWidget);
    final mine = tester.getRect(find.byKey(const ValueKey('tile_mine')));
    final theirs = tester.getRect(find.byKey(const ValueKey('tile_theirs')));
    // Same day, same row, newest first.
    expect(mine.top, theirs.top);
    expect(mine.left, lessThan(theirs.left));
    for (final k in ['albumAdd', 'albumPeople', 'albumMenu']) {
      expect(tester.getRect(find.byKey(Key(k))).top, lessThan(80), reason: k);
    }
  });

  testWidgets('only owners can rename', (tester) async {
    final albums = trip(admin: false);
    await tester.pumpWidget(
      testApp(
        home: const SharedAlbumPage(spaceId: 'trip'),
        signedIn: true,
        albums: albums,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('albumMenu')), findsNothing);
  });

  testWidgets('owners rename from the menu', (tester) async {
    final albums = trip();
    await tester.pumpWidget(
      testApp(
        home: const SharedAlbumPage(spaceId: 'trip'),
        signedIn: true,
        albums: albums,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('albumMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('albumRename')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('albumName')), 'Paris');
    await tester.tap(find.byKey(const Key('albumNameDone')));
    await tester.pumpAndSettle();
    expect(albums.renamed, ['Paris']);
  });

  testWidgets('the viewer offers Remove only for what you added', (
    tester,
  ) async {
    final albums = trip();
    await tester.pumpWidget(
      testApp(
        home: const SharedAlbumPage(spaceId: 'trip'),
        signedIn: true,
        albums: albums,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tile_theirs')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('viewerSave')), findsOneWidget);
    expect(find.byKey(const Key('viewerRemove')), findsNothing);
    await tester.tap(find.byKey(const Key('viewerDetails')));
    await tester.pumpAndSettle();
    expect(find.text('Dana'), findsOneWidget);
    expect(
      find.text('In a shared album, end-to-end encrypted'),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tile_mine')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('viewerRemove')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('removeConfirm')));
    await tester.pumpAndSettle();
    expect(albums.deleted, ['mine']);
  });

  testWidgets('add photos from the phone: pick two, Add 2', (tester) async {
    final albums = trip();
    await tester.pumpWidget(
      testApp(
        home: const SharedAlbumPage(spaceId: 'trip'),
        signedIn: true,
        albums: albums,
        library: FakePhoneLibrary(
          items: [phoneMedia('a', today), phoneMedia('b', today)],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('albumAdd')));
    await tester.pumpAndSettle();
    // Signed in with the account open: both sources.
    expect(find.byKey(const Key('addFromAccount')), findsOneWidget);
    await tester.tap(find.byKey(const Key('addFromPhone')));
    await tester.pumpAndSettle();

    final add = find.byKey(const Key('pickAdd'));
    expect(tester.widget<TextButton>(add).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('tile_a')));
    await tester.tap(find.byKey(const ValueKey('tile_b')));
    await tester.pump();
    expect(find.text('Add 2'), findsOneWidget);
    expect(find.text('2 selected'), findsOneWidget);
    // The Add button is in the bar, on screen.
    expect(tester.getRect(add).top, lessThan(80));
    expect(tester.getRect(add).width, greaterThan(20));
    await tester.tap(add);
    await tester.pumpAndSettle();

    expect(albums.added, [('trip', 2, 0)]);
    expect(find.text('2 added to the album'), findsOneWidget);
  });

  testWidgets('a video is added only after saying it keeps its details', (
    tester,
  ) async {
    final albums = trip();
    await tester.pumpWidget(
      testApp(
        home: const SharedAlbumPage(spaceId: 'trip'),
        signedIn: true,
        albums: albums,
        library: FakePhoneLibrary(items: [phoneMedia('v', today, video: true)]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('albumAdd')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addFromPhone')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tile_v')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('pickAdd')));
    await tester.pumpAndSettle();

    expect(find.text('Add the video as it is?'), findsOneWidget);
    expect(albums.added, isEmpty);
    await tester.tap(find.byKey(const Key('addVideoAnyway')));
    await tester.pumpAndSettle();
    expect(albums.added, [('trip', 1, 1)]);
  });

  testWidgets('an empty album offers Add photos and Invite people, one '
      'under the other', (tester) async {
    await tester.pumpWidget(
      testApp(
        home: const SharedAlbumPage(spaceId: 'e'),
        signedIn: true,
        albums: FakeSharedAlbums(albumsState([sharedAlbum('e', 'Empty')])),
      ),
    );
    await tester.pumpAndSettle();
    final add = tester.getRect(find.byKey(const Key('emptyAdd')));
    final invite = tester.getRect(find.byKey(const Key('emptyInvite')));
    expect(add.height, greaterThan(20));
    expect(invite.height, greaterThan(20));
    expect(add.bottom, lessThanOrEqualTo(invite.top));
  });

  testWidgets('new shared album: name it, then your name, then it opens', (
    tester,
  ) async {
    final albums = FakeSharedAlbums(albumsState(const []));
    await tester.pumpWidget(
      testApp(home: const SharingPage(), signedIn: true, albums: albums),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('newSharedAlbum')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('albumName')), 'Beach');
    await tester.tap(find.byKey(const Key('albumNameDone')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('zt-sharing-name')), 'Edo');
    await tester.tap(find.byKey(const Key('zt-sharing-name-ok')));
    await tester.pumpAndSettle();

    expect(albums.createdNames, [('Beach', 'Edo')]);
    // The new album is open, empty, ready for photos and people.
    expect(find.byKey(const Key('emptyInvite')), findsOneWidget);
    expect(find.text('Beach'), findsOneWidget);
  });

  testWidgets('selected phone photos go into a shared album', (tester) async {
    final albums = trip();
    await tester.pumpWidget(
      testApp(
        home: const PhotosPage(),
        signedIn: true,
        albums: albums,
        library: FakePhoneLibrary(
          items: [phoneMedia('a', today), phoneMedia('b', today)],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey('tile_a')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('selectionAddToAlbum')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chooseNewAlbum')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('choose_trip')));
    await tester.pumpAndSettle();
    expect(albums.added, [('trip', 1, 0)]);
  });

  testWidgets('signed out, Add to shared album asks to sign in', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        home: const PhotosPage(),
        library: FakePhoneLibrary(items: [phoneMedia('a', today)]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey('tile_a')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('selectionAddToAlbum')));
    await tester.pumpAndSettle();
    expect(
      find.text('Sign in with your Zero-Trust account to share albums.'),
      findsOneWidget,
    );
  });

  testWidgets('Hebrew: the Sharing tab and its texts, right to left', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        home: const GalleryHome(),
        signedIn: true,
        locale: hebrew,
        albums: FakeSharedAlbums(albumsState(const [])),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('שיתוף'));
    await tester.pumpAndSettle();
    expect(find.text('עדיין אין אלבומים משותפים'), findsOneWidget);
    final fab = tester.getRect(find.byKey(const Key('newSharedAlbum')));
    // Right to left: the button sits at the bottom left.
    expect(fab.left, lessThan(40));
  });
}
