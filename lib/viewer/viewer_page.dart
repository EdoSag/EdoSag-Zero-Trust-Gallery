import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../l10n/l10n.dart';

/// One photo or video as the viewer shows it, wherever it comes from (the
/// phone, the account, a shared album).
class ViewerEntry {
  const ViewerEntry({
    required this.key,
    required this.isVideo,
    required this.takenAt,
    required this.image,
    this.videoFile,
    this.details = const [],
  });

  final String key;
  final bool isVideo;
  final DateTime takenAt;

  /// The picture (for a video, a still shown until it plays).
  final ImageProvider image;

  /// A video's file, for playing. Null: no playing here.
  final Future<File?> Function()? videoFile;

  /// Shown under Details, as (label, value).
  final List<(String, String)> details;
}

/// A button in the viewer's bottom bar. [run] returns true when the entry
/// is gone afterwards (deleted), so the viewer moves on.
class ViewerAction {
  const ViewerAction({
    required this.icon,
    required this.label,
    required this.run,
    this.key,
  });

  final IconData icon;
  final String label;
  final Future<bool> Function(BuildContext context, ViewerEntry entry) run;
  final Key? key;
}

/// Full-screen photos and videos: swipe between them, pinch or double-tap
/// to zoom, tap to hide the bars. The bottom bar holds [actions] and
/// Details.
class ViewerPage extends StatefulWidget {
  const ViewerPage({
    super.key,
    required this.entries,
    required this.initialIndex,
    this.actions = const [],
  });

  final List<ViewerEntry> entries;
  final int initialIndex;
  final List<ViewerAction> actions;

  static Route<void> route({
    required List<ViewerEntry> entries,
    required int initialIndex,
    List<ViewerAction> actions = const [],
  }) => MaterialPageRoute<void>(
    builder: (_) => ViewerPage(
      entries: entries,
      initialIndex: initialIndex,
      actions: actions,
    ),
  );

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> {
  late final List<ViewerEntry> _entries = [...widget.entries];
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  bool _chrome = true;
  bool _zoomed = false;

  @override
  void dispose() {
    _pages.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleChrome() {
    setState(() => _chrome = !_chrome);
    SystemChrome.setEnabledSystemUIMode(
      _chrome ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
  }

  Future<void> _run(ViewerAction a) async {
    final entry = _entries[_index];
    final gone = await a.run(context, entry);
    if (!gone || !mounted) return;
    setState(() {
      _entries.removeAt(_index);
      if (_index >= _entries.length) _index = _entries.length - 1;
    });
    if (_entries.isEmpty) Navigator.of(context).pop();
  }

  void _details(ViewerEntry e) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
              child: Text(
                l.details,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: Text(DateFormat.yMMMMEEEEd(locale).format(e.takenAt)),
              subtitle: Text(DateFormat.jm(locale).format(e.takenAt)),
            ),
            for (final (label, value) in e.details)
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(value),
                subtitle: Text(label),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (_entries.isEmpty) return const Scaffold(backgroundColor: Colors.black);
    final entry = _entries[_index];
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _chrome
          ? AppBar(
              backgroundColor: Colors.black54,
              foregroundColor: Colors.white,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat.yMMMd(locale).format(entry.takenAt),
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    DateFormat.jm(locale).format(entry.takenAt),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            )
          : null,
      body: PageView.builder(
        controller: _pages,
        // While zoomed in, a swipe pans the photo instead.
        physics: _zoomed
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics(),
        itemCount: _entries.length,
        onPageChanged: (i) => setState(() {
          _index = i;
          _zoomed = false;
        }),
        itemBuilder: (context, i) {
          final e = _entries[i];
          return e.isVideo && e.videoFile != null
              ? _VideoPage(
                  key: ValueKey('video_${e.key}'),
                  entry: e,
                  active: i == _index,
                  onTap: _toggleChrome,
                )
              : _PhotoPage(
                  key: ValueKey('photo_${e.key}'),
                  entry: e,
                  onTap: _toggleChrome,
                  onZoom: (z) {
                    if (z != _zoomed) setState(() => _zoomed = z);
                  },
                );
        },
      ),
      bottomNavigationBar: _chrome
          ? ColoredBox(
              color: Colors.black54,
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final a in widget.actions)
                      IconButton(
                        key: a.key,
                        tooltip: a.label,
                        color: Colors.white,
                        icon: Icon(a.icon),
                        onPressed: () => _run(a),
                      ),
                    IconButton(
                      key: const Key('viewerDetails'),
                      tooltip: l.details,
                      color: Colors.white,
                      icon: const Icon(Icons.info_outline),
                      onPressed: () => _details(entry),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _PhotoPage extends StatefulWidget {
  const _PhotoPage({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onZoom,
  });

  final ViewerEntry entry;
  final VoidCallback onTap;
  final ValueChanged<bool> onZoom;

  @override
  State<_PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends State<_PhotoPage> {
  final _zoom = TransformationController();
  TapDownDetails? _doubleTap;

  @override
  void initState() {
    super.initState();
    _zoom.addListener(() {
      widget.onZoom(_zoom.value.getMaxScaleOnAxis() > 1.01);
    });
  }

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    if (_zoom.value.getMaxScaleOnAxis() > 1.01) {
      _zoom.value = Matrix4.identity();
      return;
    }
    final at = _doubleTap?.localPosition ?? Offset.zero;
    const scale = 2.5;
    _zoom.value = Matrix4.identity()
      ..translateByDouble(-at.dx * (scale - 1), -at.dy * (scale - 1), 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: widget.onTap,
    onDoubleTapDown: (d) => _doubleTap = d,
    onDoubleTap: _toggleZoom,
    child: InteractiveViewer(
      transformationController: _zoom,
      maxScale: 8,
      child: SizedBox.expand(
        child: Image(
          image: widget.entry.image,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 48,
            ),
          ),
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const Center(child: CircularProgressIndicator()),
        ),
      ),
    ),
  );
}

class _VideoPage extends StatefulWidget {
  const _VideoPage({
    super.key,
    required this.entry,
    required this.active,
    required this.onTap,
  });

  final ViewerEntry entry;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  VideoPlayerController? _player;
  bool _loading = false;
  bool _failed = false;

  @override
  void didUpdateWidget(_VideoPage old) {
    super.didUpdateWidget(old);
    if (!widget.active) _player?.pause();
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    final p = _player;
    if (p != null) {
      p.value.isPlaying ? await p.pause() : await p.play();
      setState(() {});
      return;
    }
    setState(() => _loading = true);
    try {
      final file = await widget.entry.videoFile!();
      if (file == null) throw StateError('no file');
      final player = VideoPlayerController.file(file);
      await player.initialize();
      player.addListener(() {
        if (mounted) setState(() {});
      });
      if (!mounted) {
        await player.dispose();
        return;
      }
      setState(() {
        _player = player;
        _loading = false;
      });
      await player.play();
    } on Object {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _player;
    final playing = p?.value.isPlaying ?? false;
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (p != null && p.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: p.value.aspectRatio,
                child: VideoPlayer(p),
              ),
            )
          else
            SizedBox.expand(
              child: Image(
                image: widget.entry.image,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          if (_loading)
            const CircularProgressIndicator()
          else if (_failed)
            Text(
              context.l10n.videoCantPlay,
              style: const TextStyle(color: Colors.white),
            )
          else
            IconButton.filledTonal(
              key: const Key('videoPlay'),
              iconSize: 48,
              tooltip: playing ? context.l10n.pause : context.l10n.play,
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              onPressed: _play,
            ),
          if (p != null && p.value.isInitialized)
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 96,
              child: VideoProgressIndicator(p, allowScrubbing: true),
            ),
        ],
      ),
    );
  }
}
