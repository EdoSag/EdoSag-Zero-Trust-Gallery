import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_gallery/ui/media_grid.dart';

void main() {
  test('groups by day, newest day and newest photo first', () {
    final items = [
      DateTime(2026, 11, 20, 9),
      DateTime(2026, 11, 22, 8),
      DateTime(2026, 11, 22, 21),
      DateTime(2026, 11, 20, 23, 59),
      DateTime(2025, 1, 1),
    ];
    final groups = groupByDay(items, (d) => d);
    expect(
      [for (final g in groups) g.day],
      [DateTime(2026, 11, 22), DateTime(2026, 11, 20), DateTime(2025, 1, 1)],
    );
    expect(groups.first.items, [
      DateTime(2026, 11, 22, 21),
      DateTime(2026, 11, 22, 8),
    ]);
    expect(groups[1].items, [
      DateTime(2026, 11, 20, 23, 59),
      DateTime(2026, 11, 20, 9),
    ]);
  });

  test('durations read like a player', () {
    expect(formatDuration(const Duration(seconds: 7)), '0:07');
    expect(formatDuration(const Duration(minutes: 1, seconds: 23)), '1:23');
    expect(
      formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
  });
}
