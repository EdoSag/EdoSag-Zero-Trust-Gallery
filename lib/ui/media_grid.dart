import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../l10n/l10n.dart';

/// One day of photos, newest first.
class DayGroup<T> {
  const DayGroup(this.day, this.items);

  /// Midnight, local time.
  final DateTime day;
  final List<T> items;
}

/// Splits [items] (any order) into days, newest day first and newest first
/// inside a day.
List<DayGroup<T>> groupByDay<T>(
  Iterable<T> items,
  DateTime Function(T) dateOf,
) {
  final sorted = items.toList()..sort((a, b) => dateOf(b).compareTo(dateOf(a)));
  final groups = <DayGroup<T>>[];
  for (final item in sorted) {
    final t = dateOf(item).toLocal();
    final day = DateTime(t.year, t.month, t.day);
    if (groups.isEmpty || groups.last.day != day) {
      groups.add(DayGroup(day, [item]));
    } else {
      groups.last.items.add(item);
    }
  }
  return groups;
}

/// "Today", "Yesterday", "Sat, Nov 21" or, in another year,
/// "Sat, Nov 21, 2025".
String dayTitle(BuildContext context, DateTime day, {DateTime? now}) {
  final l = context.l10n;
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return l.today;
  if (diff == 1) return l.yesterday;
  final locale = Localizations.localeOf(context).toLanguageTag();
  return day.year == today.year
      ? DateFormat.MMMEd(locale).format(day)
      : DateFormat.yMMMEd(locale).format(day);
}

/// How many photos fit across the grid; pinch to change (2 to 6).
final gridColumnsProvider = NotifierProvider<GridColumns, int>(GridColumns.new);

class GridColumns extends Notifier<int> {
  static const _key = 'gallery_grid_columns';
  static const min = 2, max = 6, initial = 4;

  @override
  int build() {
    _load();
    return initial;
  }

  Future<void> _load() async {
    try {
      final v = int.tryParse(
        await ref.read(ztPreferencesStoreProvider).read(_key) ?? '',
      );
      if (v != null && v >= min && v <= max) state = v;
    } on Object {
      // No stored choice: the default stays.
    }
  }

  void set(int columns) {
    final v = columns.clamp(min, max);
    if (v == state) return;
    state = v;
    ref.read(ztPreferencesStoreProvider).write(_key, '$v').ignore();
  }
}

/// A grid of photos by day, like every gallery: a heading per day, then the
/// day's photos. Pinch with two fingers to show more or fewer across.
/// Long-press starts selecting; [selected] holds the selected keys.
class MediaGrid<T> extends ConsumerStatefulWidget {
  const MediaGrid({
    super.key,
    required this.items,
    required this.keyOf,
    required this.dateOf,
    required this.thumbnail,
    required this.onOpen,
    this.isVideo,
    this.durationOf,
    this.selected = const {},
    this.onSelect,
    this.header,
    this.controller,
  });

  final List<T> items;
  final String Function(T) keyOf;
  final DateTime Function(T) dateOf;
  final ImageProvider Function(T) thumbnail;

  /// Opens the viewer on the item (index into the day-sorted order).
  final void Function(List<T> sorted, int index) onOpen;
  final bool Function(T)? isVideo;
  final Duration Function(T)? durationOf;
  final Set<String> selected;

  /// Turns an item's selection on or off; null: no selecting here.
  final void Function(T item)? onSelect;

  /// Shown above the first day (a notice, the "pick more" bar).
  final Widget? header;
  final ScrollController? controller;

  @override
  ConsumerState<MediaGrid<T>> createState() => _MediaGridState<T>();
}

class _MediaGridState<T> extends ConsumerState<MediaGrid<T>> {
  final _pointers = <int, Offset>{};
  double? _startSpan;
  int? _startColumns;

  double? _span() {
    if (_pointers.length < 2) return null;
    final p = _pointers.values.take(2).toList();
    return (p[0] - p[1]).distance;
  }

  void _down(PointerDownEvent e) {
    _pointers[e.pointer] = e.position;
    if (_pointers.length == 2) {
      _startSpan = _span();
      _startColumns = ref.read(gridColumnsProvider);
    }
  }

  void _move(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.position;
    final start = _startSpan, columns = _startColumns, span = _span();
    if (start == null || columns == null || span == null || start < 1) return;
    final scale = span / start;
    // Spreading the fingers zooms in: fewer, bigger photos.
    final steps = scale >= 1
        ? -((scale - 1) / 0.35).floor()
        : ((1 / scale - 1) / 0.35).floor();
    ref.read(gridColumnsProvider.notifier).set(columns + steps);
  }

  void _up(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length < 2) {
      _startSpan = null;
      _startColumns = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final columns = ref.watch(gridColumnsProvider);
    final groups = groupByDay(widget.items, widget.dateOf);
    final sorted = [for (final g in groups) ...g.items];
    final theme = Theme.of(context);
    final selecting = widget.selected.isNotEmpty;
    var offset = 0;
    final slivers = <Widget>[
      if (widget.header != null) SliverToBoxAdapter(child: widget.header),
    ];
    for (final g in groups) {
      final start = offset;
      offset += g.items.length;
      slivers
        ..add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
              child: Text(
                dayTitle(context, g.day),
                style: theme.textTheme.titleSmall,
              ),
            ),
          ),
        )
        ..add(
          SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            delegate: SliverChildBuilderDelegate(childCount: g.items.length, (
              context,
              i,
            ) {
              final item = g.items[i];
              final key = widget.keyOf(item);
              final isSelected = widget.selected.contains(key);
              return _Tile(
                key: ValueKey('tile_$key'),
                image: widget.thumbnail(item),
                video: widget.isVideo?.call(item) ?? false,
                duration: widget.durationOf?.call(item),
                selecting: selecting,
                selected: isSelected,
                onTap: selecting && widget.onSelect != null
                    ? () => widget.onSelect!(item)
                    : () => widget.onOpen(sorted, start + i),
                onLongPress: widget.onSelect == null
                    ? null
                    : () => widget.onSelect!(item),
              );
            }),
          ),
        );
    }
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 96)));
    return Listener(
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: CustomScrollView(
        controller: widget.controller,
        // Two fingers on the grid zoom; one scrolls.
        dragStartBehavior: DragStartBehavior.down,
        slivers: slivers,
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.image,
    required this.video,
    required this.selecting,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.duration,
  });

  final ImageProvider image;
  final bool video;
  final Duration? duration;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: video ? context.l10n.video : context.l10n.photo,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedPadding(
              duration: const Duration(milliseconds: 120),
              padding: EdgeInsets.all(selected ? 10 : 0),
              child: Image(
                image: image,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                frameBuilder: (context, child, frame, sync) =>
                    frame == null && !sync
                    ? ColoredBox(color: scheme.surfaceContainerHighest)
                    : child,
              ),
            ),
            if (video)
              PositionedDirectional(
                top: 4,
                end: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (duration != null && duration! > Duration.zero)
                      Text(
                        formatDuration(duration!),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          shadows: [Shadow(blurRadius: 4)],
                        ),
                      ),
                    const Icon(
                      Icons.play_circle_outline,
                      color: Colors.white,
                      size: 18,
                      shadows: [Shadow(blurRadius: 4)],
                    ),
                  ],
                ),
              ),
            if (selecting)
              PositionedDirectional(
                top: 4,
                start: 4,
                child: Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected ? scheme.primary : Colors.white,
                  shadows: const [Shadow(blurRadius: 4)],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 0:07, 1:23, 1:02:03.
String formatDuration(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}
