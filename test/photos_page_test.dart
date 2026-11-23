import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_gallery/phone/phone_library.dart';
import 'package:zerotrust_gallery/phone/phone_pages.dart';
import 'package:zerotrust_gallery/viewer/viewer_page.dart';

import 'support/fakes.dart';

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 10);
  final yesterday = today.subtract(const Duration(days: 1));

  FakePhoneLibrary library() => FakePhoneLibrary(
    items: [
      phoneMedia('a', today.add(const Duration(hours: 2))),
      phoneMedia('b', today.add(const Duration(hours: 1))),
      phoneMedia('c', today),
      phoneMedia('d', yesterday, video: true),
      phoneMedia(
        'e',
        yesterday.subtract(const Duration(hours: 1)),
        folder: 'Screenshots',
      ),
    ],
  );

  testWidgets('photos by day: heading above its photos, newest first, '
      'four across', (tester) async {
    await tester.pumpWidget(
      testApp(home: const PhotosPage(), library: library()),
    );
    await tester.pumpAndSettle();

    final todayTitle = tester.getRect(find.text('Today'));
    final yesterdayTitle = tester.getRect(find.text('Yesterday'));
    final a = tester.getRect(find.byKey(const ValueKey('tile_a')));
    final b = tester.getRect(find.byKey(const ValueKey('tile_b')));
    final c = tester.getRect(find.byKey(const ValueKey('tile_c')));
    final d = tester.getRect(find.byKey(const ValueKey('tile_d')));

    expect(todayTitle.bottom, lessThanOrEqualTo(a.top));
    // Same row, newest at the start (left in English).
    expect(a.top, b.top);
    expect(a.left, lessThan(b.left));
    expect(b.left, lessThan(c.left));
    // Four across on an 800 px wide screen: about 200 px each.
    expect(a.width, closeTo(800 / 4, 2));
    // Yesterday's heading comes after today's photos, before its own.
    expect(yesterdayTitle.top, greaterThanOrEqualTo(a.bottom));
    expect(d.top, greaterThanOrEqualTo(yesterdayTitle.bottom));
    // The video shows its length.
    expect(find.text('0:07'), findsOneWidget);
  });

  testWidgets('tapping a photo opens the viewer on it', (tester) async {
    await tester.pumpWidget(
      testApp(home: const PhotosPage(), library: library()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tile_b')));
    await tester.pumpAndSettle();
    expect(find.byType(ViewerPage), findsOneWidget);
    final viewer = tester.widget<ViewerPage>(find.byType(ViewerPage));
    expect(viewer.entries[viewer.initialIndex].key, 'b');
    expect(find.byKey(const Key('viewerShare')), findsOneWidget);
    expect(find.byKey(const Key('viewerDelete')), findsOneWidget);
  });

  testWidgets('long-press selects; share sends clean copies', (tester) async {
    final shared = <List<String>>[];
    await tester.pumpWidget(
      testApp(home: const PhotosPage(), library: library(), shared: shared),
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey('tile_a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tile_c')));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('selectionShare')));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(shared, hasLength(1));
    expect(shared.single, hasLength(2));
    expect(shared.single.every((p) => p.endsWith('.jpg')), isTrue);
  });

  testWidgets('delete removes the selected ones from the phone', (
    tester,
  ) async {
    final lib = library();
    await tester.pumpWidget(testApp(home: const PhotosPage(), library: lib));
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey('tile_b')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('selectionDelete')));
    await tester.pumpAndSettle();
    expect(lib.deleted, ['b']);
    expect(find.byKey(const ValueKey('tile_b')), findsNothing);
    expect(find.text('Photos'), findsOneWidget);
  });

  testWidgets('without access: explains and asks', (tester) async {
    final lib = library()..granted = PhoneAccess.none;
    await tester.pumpWidget(testApp(home: const PhotosPage(), library: lib));
    await tester.pumpAndSettle();
    expect(find.text('See your photos here'), findsOneWidget);
    expect(find.byKey(const ValueKey('tile_a')), findsNothing);

    await tester.tap(find.byKey(const Key('allowAccess')));
    await tester.pumpAndSettle();
    expect(lib.asked, 1);
    expect(find.byKey(const ValueKey('tile_a')), findsOneWidget);
  });

  testWidgets('refused for good: opens the phone settings', (tester) async {
    final lib = library()
      ..granted = PhoneAccess.none
      ..afterAsking = PhoneAccess.none;
    await tester.pumpWidget(testApp(home: const PhotosPage(), library: lib));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('allowAccess')));
    await tester.pumpAndSettle();
    expect(lib.settingsOpened, 1);
  });

  testWidgets('only some photos: offers to pick more', (tester) async {
    final lib = library()..granted = PhoneAccess.some;
    await tester.pumpWidget(testApp(home: const PhotosPage(), library: lib));
    await tester.pumpAndSettle();
    expect(find.text('Only some photos'), findsOneWidget);
    expect(find.text('Pick more'), findsOneWidget);
  });

  testWidgets('folders list with counts, and open one', (tester) async {
    await tester.pumpWidget(
      testApp(home: const FoldersPage(), library: library()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('4 items'), findsOneWidget);
    expect(find.text('Screenshots'), findsOneWidget);
    expect(find.text('1 item'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('folder_Screenshots')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tile_e')), findsOneWidget);
    expect(find.byKey(const ValueKey('tile_a')), findsNothing);
  });

  testWidgets('Hebrew: right to left, newest photo on the right', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(home: const PhotosPage(), library: library(), locale: hebrew),
    );
    await tester.pumpAndSettle();
    expect(find.text('היום'), findsOneWidget);
    expect(find.text('תמונות'), findsOneWidget);
    final a = tester.getRect(find.byKey(const ValueKey('tile_a')));
    final b = tester.getRect(find.byKey(const ValueKey('tile_b')));
    expect(a.left, greaterThan(b.left));
    final title = tester.getRect(find.text('היום'));
    expect(title.right, greaterThan(400));
  });
}
