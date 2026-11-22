import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/account.dart';
import '../l10n/l10n.dart';
import '../phone/phone_library.dart';
import '../ui/media_grid.dart';
import '../ui/settings_button.dart';
import '../viewer/share_out.dart';
import '../viewer/viewer_page.dart';
import 'account_photos.dart';
import 'camera_media.dart';

/// No preview: decoding it fails, and the grid shows an icon instead.
final _noPreview = MemoryImage(Uint8List(0));

ImageProvider accountThumbnail(AccountPhotoStore store, CameraMedia m) {
  final thumb = m.thumb;
  if (thumb != null) return AttachmentImage(thumb, store.read);
  // Items backed up before previews existed: a photo shows itself.
  return m.isVideo ? _noPreview : AttachmentImage(m.file, store.read);
}

String _megabytes(int bytes) => (bytes / 1000000).toStringAsFixed(1);

ViewerEntry accountEntry(BuildContext context, WidgetRef ref, CameraMedia m) {
  final l = context.l10n;
  final store = ref.read(accountPhotoStoreProvider);
  return ViewerEntry(
    key: m.id,
    isVideo: m.isVideo,
    takenAt: m.takenAt,
    image: m.isVideo
        ? accountThumbnail(store, m)
        : AttachmentImage(m.file, store.read),
    videoFile: m.isVideo
        ? () async =>
              accountVideoFile(store, await ref.read(playDirProvider)(), m)
        : null,
    details: [
      (l.detailFileSize, l.megabytes(_megabytes(m.size))),
      if (m.saver) (l.detailCopy, l.spaceSaverCopy),
      (l.detailWhere, l.inYourAccountEncrypted),
    ],
  );
}

/// Opens the viewer on account items, with Share and Save to phone.
void openAccountViewer(
  BuildContext context,
  WidgetRef ref,
  List<CameraMedia> items,
  int index,
) {
  final l = context.l10n;
  final byId = {for (final m in items) m.id: m};
  final store = ref.read(accountPhotoStoreProvider);
  Navigator.of(context).push(
    ViewerPage.route(
      entries: [for (final m in items) accountEntry(context, ref, m)],
      initialIndex: index,
      actions: [
        ViewerAction(
          key: const Key('viewerShare'),
          icon: Icons.share_outlined,
          label: l.share,
          run: (context, e) async {
            final m = byId[e.key]!;
            final share = ShareOut(ref);
            if (m.isVideo) {
              final f = await accountVideoFile(
                store,
                await ref.read(playDirProvider)(),
                m,
              );
              if (context.mounted) await share.videoFile(context, f);
            } else {
              final bytes = await store.read(m.file);
              if (context.mounted) await share.photoBytes(context, bytes);
            }
            return false;
          },
        ),
        ViewerAction(
          key: const Key('viewerSave'),
          icon: Icons.download_outlined,
          label: l.saveToPhone,
          run: (context, e) async {
            final m = byId[e.key]!;
            final library = ref.read(phoneLibraryProvider);
            final messenger = ScaffoldMessenger.maybeOf(context);
            final done = l.savedToPhone;
            final failed = l.saveFailed;
            try {
              if (m.isVideo) {
                final f = await accountVideoFile(
                  store,
                  await ref.read(playDirProvider)(),
                  m,
                );
                await library.saveVideo(f, takenAt: m.takenAt);
              } else {
                await library.savePhoto(
                  await store.read(m.file),
                  takenAt: m.takenAt,
                );
              }
              messenger?.showSnackBar(
                SnackBar(
                  content: Text(done),
                  duration: const Duration(seconds: 4),
                ),
              );
            } on Object {
              messenger?.showSnackBar(
                SnackBar(
                  content: Text(failed),
                  duration: const Duration(seconds: 4),
                ),
              );
            }
            return false;
          },
        ),
      ],
    ),
  );
}

/// The account's photos as a grid by day.
class _AccountGrid extends ConsumerWidget {
  const _AccountGrid({required this.items});

  final List<CameraMedia> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(accountPhotoStoreProvider);
    return MediaGrid<CameraMedia>(
      items: items,
      keyOf: (m) => m.id,
      dateOf: (m) => m.takenAt,
      thumbnail: (m) => accountThumbnail(store, m),
      isVideo: (m) => m.isVideo,
      onOpen: (sorted, i) => openAccountViewer(context, ref, sorted, i),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

/// The Account tab: the photos in the Zero-Trust account (backed up from
/// ZT Camera's Private vault), end-to-end encrypted.
class AccountPhotosPage extends ConsumerWidget {
  const AccountPhotosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final signedIn = ref.watch(signedInProvider);
    final media = ref.watch(accountMediaProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.accountTab),
        actions: const [SettingsButton()],
      ),
      body: !signedIn
          ? _Message(
              icon: Icons.cloud_outlined,
              title: l.accountSignedOutTitle,
              body: l.accountSignedOutBody,
              action: FilledButton(
                key: const Key('accountSignIn'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const GallerySignInPage(),
                  ),
                ),
                child: Text(l.signIn),
              ),
            )
          : switch (media) {
              AsyncData(:final value) when value.isEmpty => _Message(
                icon: Icons.cloud_done_outlined,
                title: l.accountEmptyTitle,
                body: l.accountEmptyBody,
              ),
              AsyncData(:final value) => _AccountGrid(items: value),
              AsyncError() => _Message(
                icon: Icons.cloud_off_outlined,
                title: l.accountCantLoadTitle,
                body: l.accountCantLoadBody,
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
    );
  }
}

/// The account's albums, above the phone's folders in the Albums tab.
class AccountAlbumsSection extends ConsumerWidget {
  const AccountAlbumsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(accountAlbumsProvider).value ?? const [];
    final media = ref.watch(accountMediaProvider).value ?? const [];
    if (albums.isEmpty) return const SizedBox.shrink();
    final store = ref.watch(accountPhotoStoreProvider);
    final theme = Theme.of(context);
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
          child: Text(l.inYourAccount, style: theme.textTheme.titleSmall),
        ),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: albums.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final a = albums[i];
              final inside = [
                for (final m in media)
                  if (m.albums.contains(a.id)) m,
              ];
              final cover = inside.firstOrNull;
              return SizedBox(
                width: 128,
                child: InkWell(
                  key: ValueKey('accountAlbum_${a.id}'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AccountAlbumPage(album: a),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox.square(
                          dimension: 128,
                          child: cover == null
                              ? ColoredBox(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                )
                              : Image(
                                  image: accountThumbnail(store, cover),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => ColoredBox(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        a.name.isEmpty ? l.untitledAlbum : a.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        l.itemCount(inside.length),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// One account album's photos.
class AccountAlbumPage extends ConsumerWidget {
  const AccountAlbumPage({super.key, required this.album});

  final CameraAlbum album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = ref.watch(accountMediaProvider).value ?? const [];
    final inside = [
      for (final m in media)
        if (m.albums.contains(album.id)) m,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          album.name.isEmpty ? context.l10n.untitledAlbum : album.name,
        ),
      ),
      body: _AccountGrid(items: inside),
    );
  }
}
