import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_gallery/phone/phone_library.dart';
import 'package:zerotrust_gallery/ui/settings_page.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('settings work signed out and show photo access', (tester) async {
    final lib = FakePhoneLibrary(granted: PhoneAccess.some);
    await tester.pumpWidget(
      testApp(home: const GallerySettingsPage(), library: lib),
    );
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('photoAccess'));
    await tester.scrollUntilVisible(row, 200);
    expect(find.text('Only the photos you picked'), findsOneWidget);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(lib.settingsOpened, 1);
  });
}
