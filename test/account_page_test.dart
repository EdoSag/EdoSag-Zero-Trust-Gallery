import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_gallery/account/account_pages.dart';
import 'package:zerotrust_gallery/account/camera_media.dart';
import 'package:zerotrust_gallery/app/account.dart';
import 'package:zerotrust_gallery/phone/phone_pages.dart';
import 'package:zerotrust_gallery/ui/gallery_home.dart';
import 'package:zerotrust_gallery/viewer/viewer_page.dart';

import 'support/fakes.dart';

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 12);

  FakeAccountStore store() => FakeAccountStore(
    items: [
      cameraMedia('p1', today, albums: ['trip']),
      cameraMedia('v1', today.subtract(const Duration(hours: 1)), video: true),
      cameraMedia(
        'p0',
        today.subtract(const Duration(days: 3)),
        albums: ['trip'],
      ),
    ],
    albumList: [const CameraAlbum(id: 'trip', name: 'Eilat trip')],
  );

  testWidgets('signed out: explains and offers sign-in', (tester) async {
    await tester.pumpWidget(testApp(home: const AccountPhotosPage()));
    await tester.pumpAndSettle();
    expect(find.text('Your encrypted photos'), findsOneWidget);
    await tester.tap(find.byKey(const Key('accountSignIn')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(GallerySignInPage), findsOneWidget);
  });

  testWidgets('signed in: the account photos by day, previews decrypted', (
    tester,
  ) async {
    final account = store();
    await tester.pumpWidget(
      testApp(
        home: const AccountPhotosPage(),
        account: account,
        signedIn: true,
      ),
    );
    await tester.pumpAndSettle();
    final p1 = tester.getRect(find.byKey(const ValueKey('tile_p1')));
    final v1 = tester.getRect(find.byKey(const ValueKey('tile_v1')));
    expect(
      tester.getRect(find.text('Today')).bottom,
      lessThanOrEqualTo(p1.top),
    );
    expect(p1.top, v1.top);
    expect(p1.left, lessThan(v1.left));
    expect(find.byKey(const ValueKey('tile_p0')), findsOneWidget);
    // Previews come from the small encrypted copies, not the full files.
    expect(account.reads, containsAll(['tp1', 'tv1', 'tp0']));
    expect(account.reads, isNot(contains('fp1')));
  });

  testWidgets('opening one shows the full photo with Share and Save', (
    tester,
  ) async {
    final account = store();
    await tester.pumpWidget(
      testApp(
        home: const AccountPhotosPage(),
        account: account,
        signedIn: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tile_p1')));
    await tester.pumpAndSettle();
    expect(find.byType(ViewerPage), findsOneWidget);
    expect(account.reads, contains('fp1'));
    expect(find.byKey(const Key('viewerShare')), findsOneWidget);
    expect(find.byKey(const Key('viewerSave')), findsOneWidget);
    await tester.tap(find.byKey(const Key('viewerDetails')));
    await tester.pumpAndSettle();
    expect(find.text('In your account, end-to-end encrypted'), findsOneWidget);
    expect(find.text('2.5 MB'), findsOneWidget);
  });

  testWidgets('save to phone keeps a copy in the phone gallery', (
    tester,
  ) async {
    final lib = FakePhoneLibrary();
    await tester.pumpWidget(
      testApp(
        home: const AccountPhotosPage(),
        account: store(),
        library: lib,
        signedIn: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tile_p1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('viewerSave')));
    await tester.pumpAndSettle();
    expect(lib.saved, ['photo']);
    expect(
      find.text('Saved to this phone (ZT Gallery folder).'),
      findsOneWidget,
    );
  });

  testWidgets('signed in, nothing backed up yet', (tester) async {
    await tester.pumpWidget(
      testApp(home: const AccountPhotosPage(), signedIn: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nothing in your account yet'), findsOneWidget);
  });

  testWidgets('account albums show above the phone folders', (tester) async {
    await tester.pumpWidget(
      testApp(
        home: const FoldersPage(extra: [AccountAlbumsSection()]),
        account: store(),
        library: FakePhoneLibrary(items: [phoneMedia('a', today)]),
        signedIn: true,
      ),
    );
    await tester.pumpAndSettle();
    final albumTitle = tester.getRect(find.text('Eilat trip'));
    final phoneHeading = tester.getRect(find.text('On this phone'));
    expect(albumTitle.bottom, lessThan(phoneHeading.top));
    expect(find.text('2 items'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('accountAlbum_trip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tile_p1')), findsOneWidget);
    expect(find.byKey(const ValueKey('tile_p0')), findsOneWidget);
    expect(find.byKey(const ValueKey('tile_v1')), findsNothing);
  });

  testWidgets('the three tabs', (tester) async {
    await tester.pumpWidget(
      testApp(
        home: const GalleryHome(),
        library: FakePhoneLibrary(items: [phoneMedia('a', today)]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tile_a')), findsOneWidget);
    await tester.tap(find.byIcon(Icons.cloud_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Your encrypted photos'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.photo_album_outlined));
    await tester.pumpAndSettle();
    expect(find.text('On this phone'), findsOneWidget);
  });
}
