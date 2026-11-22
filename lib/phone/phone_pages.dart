import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../shared/album_sources.dart';
import '../shared/shared_pages.dart';
import '../ui/media_grid.dart';
import '../ui/settings_button.dart';
import '../viewer/share_out.dart';
import '../viewer/viewer_page.dart';
import 'phone_library.dart';

/// The viewer's entry for a phone photo or video.
ViewerEntry phoneEntry(
  BuildContext context,
  PhoneLibrary library,
  PhoneMedia m,
) {
  final l = context.l10n;
  return ViewerEntry(
    key: m.id,
    isVideo: m.isVideo,
    takenAt: m.takenAt,
    image: library.image(m),
    videoFile: m.isVideo ? () => library.file(m) : null,
    details: [
      if (m.name != null) (l.detailName, m.name!),
      if (m.width > 0 && m.height > 0)
        (l.detailSize, '${m.width} × ${m.height}'),
      if (m.isVideo && m.duration > Duration.zero)
        (l.detailLength, formatDuration(m.duration)),
      if (m.folder != null) (l.detailFolder, m.folder!),
      (l.detailWhere, l.onThisPhone),
    ],
  );
}

/// Opens the viewer on [items] at [index], with Share and Delete.
void openPhoneViewer(
  BuildContext context,
  WidgetRef ref,
  List<PhoneMedia> items,
  int index,
) {
  final library = ref.read(phoneLibraryProvider);
  final byId = {for (final m in items) m.id: m};
  final l = context.l10n;
  Navigator.of(context).push(
    ViewerPage.route(
      entries: [for (final m in items) phoneEntry(context, library, m)],
      initialIndex: index,
      actions: [
        ViewerAction(
          key: const Key('viewerShare'),
          icon: Icons.share_outlined,
          label: l.share,
          run: (context, e) async {
            await ShareOut(ref).phone(context, [byId[e.key]!]);
            return false;
          },
        ),
        ViewerAction(
          key: const Key('viewerDelete'),
          icon: Icons.delete_outline,
          label: l.delete,
          run: (context, e) async {
            final gone = await library.delete([byId[e.key]!]);
            return gone.contains(e.key);
          },
        ),
      ],
    ),
  );
}

/// What to show instead of photos until the app may see them.
class PhoneAccessNotice extends ConsumerWidget {
  const PhoneAccessNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              l.accessTitle,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(l.accessBody, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('allowAccess'),
              onPressed: () async {
                final a = await ref.read(phoneAccessProvider.notifier).ask();
                // Refused for good: only the phone's settings can allow it.
                if (a == PhoneAccess.none) {
                  await ref.read(phoneLibraryProvider).openSettings();
                }
              },
              child: Text(l.allowAccess),
            ),
          ],
        ),
      ),
    );
  }
}

/// Android 14 and later, when only some photos were picked.
class _SomePhotosBar extends ConsumerWidget {
  const _SomePhotosBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: ListTile(
        leading: const Icon(Icons.photo_library_outlined),
        title: Text(l.somePhotosTitle),
        subtitle: Text(l.somePhotosBody),
        trailing: TextButton(
          onPressed: () => ref.read(phoneLibraryProvider).pickMore(),
          child: Text(l.pickMore),
        ),
      ),
    );
  }
}

/// Picking several photos: the bar on top of a grid while some are
/// selected.
mixin PhoneSelection<W extends ConsumerStatefulWidget> on ConsumerState<W> {
  final Set<String> selected = {};
  final Map<String, PhoneMedia> _picked = {};

  void toggle(PhoneMedia m) => setState(() {
    if (!selected.remove(m.id)) {
      selected.add(m.id);
      _picked[m.id] = m;
    } else {
      _picked.remove(m.id);
    }
  });

  void clearSelection() => setState(() {
    selected.clear();
    _picked.clear();
  });

  List<PhoneMedia> get picked => _picked.values.toList();

  /// The app bar while selecting: count, Share, Add to shared album,
  /// Delete.
  PreferredSizeWidget selectionBar(BuildContext context) {
    final l = context.l10n;
    return AppBar(
      leading: IconButton(
        tooltip: l.cancel,
        icon: const Icon(Icons.close),
        onPressed: clearSelection,
      ),
      title: Text(l.selectedCount(selected.length)),
      actions: [
        IconButton(
          key: const Key('selectionShare'),
          tooltip: l.share,
          icon: const Icon(Icons.share_outlined),
          onPressed: () async {
            await ShareOut(ref).phone(context, picked);
          },
        ),
        IconButton(
          key: const Key('selectionAddToAlbum'),
          tooltip: l.addToSharedAlbum,
          icon: const Icon(Icons.add_to_photos_outlined),
          onPressed: () async {
            final library = ref.read(phoneLibraryProvider);
            final items = [for (final m in picked) phoneToShared(library, m)];
            await addToSharedAlbumFlow(context, ref, items);
          },
        ),
        IconButton(
          key: const Key('selectionDelete'),
          tooltip: l.delete,
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            await ref.read(phoneLibraryProvider).delete(picked);
            clearSelection();
          },
        ),
      ],
    );
  }
}

/// The Photos tab: every photo and video on the phone, by day.
class PhotosPage extends ConsumerStatefulWidget {
  const PhotosPage({super.key});

  @override
  ConsumerState<PhotosPage> createState() => _PhotosPageState();
}

class _PhotosPageState extends ConsumerState<PhotosPage>
    with PhoneSelection<PhotosPage>, WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from the phone's settings: access may have changed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(phoneAccessProvider.notifier).recheck());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final access = ref.watch(phoneAccessProvider);
    final media = ref.watch(phoneMediaProvider);
    final library = ref.watch(phoneLibraryProvider);
    return PopScope(
      canPop: selected.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) clearSelection();
      },
      child: Scaffold(
        appBar: selected.isNotEmpty
            ? selectionBar(context)
            : AppBar(
                title: Text(l.photosTab),
                actions: const [SettingsButton()],
              ),
        body: switch ((access, media)) {
          (AsyncData(value: PhoneAccess.none), _) => const PhoneAccessNotice(),
          (_, AsyncData(:final value)) when value.isEmpty => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(l.noPhotos, textAlign: TextAlign.center),
            ),
          ),
          (_, AsyncData(:final value)) => MediaGrid<PhoneMedia>(
            items: value,
            keyOf: (m) => m.id,
            dateOf: (m) => m.takenAt,
            thumbnail: (m) => library.thumbnail(m),
            isVideo: (m) => m.isVideo,
            durationOf: (m) => m.duration,
            selected: selected,
            onSelect: toggle,
            header: access.value == PhoneAccess.some
                ? const _SomePhotosBar()
                : null,
            onOpen: (sorted, i) => openPhoneViewer(context, ref, sorted, i),
          ),
          (_, AsyncError()) => Center(child: Text(l.photosCantLoad)),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

/// The Albums tab: the phone's folders (Camera, Screenshots, WhatsApp...).
class FoldersPage extends ConsumerWidget {
  const FoldersPage({super.key, this.extra = const []});

  /// Shown above the phone's folders (shared albums, account albums).
  final List<Widget> extra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final access = ref.watch(phoneAccessProvider);
    final folders = ref.watch(phoneFoldersProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.albumsTab),
        actions: const [SettingsButton()],
      ),
      body: CustomScrollView(
        slivers: [
          ...[for (final w in extra) SliverToBoxAdapter(child: w)],
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
              child: Text(
                l.onThisPhone,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ),
          switch ((access, folders)) {
            (AsyncData(value: PhoneAccess.none), _) => const SliverToBoxAdapter(
              child: SizedBox(height: 360, child: PhoneAccessNotice()),
            ),
            (_, AsyncData(:final value)) => SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.82,
                ),
                delegate: SliverChildBuilderDelegate(
                  childCount: value.length,
                  (context, i) => _FolderTile(folder: value[i]),
                ),
              ),
            ),
            _ => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          },
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }
}

class _FolderTile extends ConsumerWidget {
  const _FolderTile({required this.folder});

  final PhoneFolder folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = ref.watch(folderMediaProvider(folder));
    final library = ref.watch(phoneLibraryProvider);
    final cover = media.value?.firstOrNull;
    final theme = Theme.of(context);
    return InkWell(
      key: ValueKey('folder_${folder.id}'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => FolderPage(folder: folder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox.expand(
                child: cover == null
                    ? ColoredBox(
                        color: theme.colorScheme.surfaceContainerHighest,
                      )
                    : Image(
                        image: library.thumbnail(cover, size: 384),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => ColoredBox(
                          color: theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            folder.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
          Text(
            context.l10n.itemCount(folder.count),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// One phone folder's photos, by day.
class FolderPage extends ConsumerStatefulWidget {
  const FolderPage({super.key, required this.folder});

  final PhoneFolder folder;

  @override
  ConsumerState<FolderPage> createState() => _FolderPageState();
}

class _FolderPageState extends ConsumerState<FolderPage>
    with PhoneSelection<FolderPage> {
  @override
  Widget build(BuildContext context) {
    final media = ref.watch(folderMediaProvider(widget.folder));
    final library = ref.watch(phoneLibraryProvider);
    return PopScope(
      canPop: selected.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) clearSelection();
      },
      child: Scaffold(
        appBar: selected.isNotEmpty
            ? selectionBar(context)
            : AppBar(title: Text(widget.folder.name)),
        body: switch (media) {
          AsyncData(:final value) => MediaGrid<PhoneMedia>(
            items: value,
            keyOf: (m) => m.id,
            dateOf: (m) => m.takenAt,
            thumbnail: (m) => library.thumbnail(m),
            isVideo: (m) => m.isVideo,
            durationOf: (m) => m.duration,
            selected: selected,
            onSelect: toggle,
            onOpen: (sorted, i) => openPhoneViewer(context, ref, sorted, i),
          ),
          AsyncError() => Center(child: Text(context.l10n.photosCantLoad)),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}
