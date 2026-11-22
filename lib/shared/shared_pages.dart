import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:zt_sharing_ui/zt_sharing_ui.dart';

import '../account/account_pages.dart';
import '../account/account_photos.dart';
import '../account/camera_media.dart';
import '../app/account.dart';
import '../l10n/l10n.dart';
import '../phone/phone_library.dart';
import '../phone/phone_pages.dart';
import '../ui/gallery_message.dart';
import '../ui/media_grid.dart';
import '../ui/settings_button.dart';
import '../viewer/share_out.dart';
import '../viewer/viewer_page.dart';
import 'album_sources.dart';
import 'shared_album.dart';
import 'shared_albums.dart';
import 'shared_files.dart';

void _snack(BuildContext context, String text) =>
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 4)),
      );

String albumTitle(BuildContext context, SharedAlbum? album) {
  final name = album?.name.trim() ?? '';
  return name.isEmpty ? context.l10n.untitledAlbum : name;
}

/// No preview: decoding it fails, and the grid shows an icon instead.
final _noPreview = MemoryImage(Uint8List(0));

/// A shared photo's whole picture, decrypted in memory.
ImageProvider sharedImage(SharedFiles files, String spaceId, SharedPhoto p) =>
    AttachmentImage(
      p.files.first,
      (_) => readWhole(files, spaceId, p.owner, p.files),
    );

/// A shared photo's preview for grids.
ImageProvider sharedThumbnail(
  SharedFiles files,
  String spaceId,
  SharedPhoto p,
) {
  final thumb = p.thumb;
  if (thumb != null) {
    return AttachmentImage(thumb, (r) => files.read(spaceId, p.owner, r));
  }
  return p.isVideo ? _noPreview : sharedImage(files, spaceId, p);
}

/// Writes a shared video (all its parts, in order) to a file for the
/// player, in the app's own cache folder.
Future<File> sharedVideoFile(
  SharedFiles files,
  Directory dir,
  String spaceId,
  SharedPhoto p,
) async {
  if (await dir.exists()) await dir.delete(recursive: true);
  await dir.create(recursive: true);
  final f = File('${dir.path}/${p.id}.mp4');
  final sink = f.openWrite();
  try {
    for (final part in p.files) {
      sink.add(await files.read(spaceId, p.owner, part));
    }
  } finally {
    await sink.close();
  }
  return f;
}

/// Asks for an album name. Null when cancelled.
Future<String?> askAlbumName(
  BuildContext context, {
  String initial = '',
  required String action,
}) => showDialog<String>(
  context: context,
  builder: (_) => _AlbumNameDialog(initial: initial, action: action),
);

class _AlbumNameDialog extends StatefulWidget {
  const _AlbumNameDialog({required this.initial, required this.action});

  final String initial;
  final String action;

  @override
  State<_AlbumNameDialog> createState() => _AlbumNameDialogState();
}

class _AlbumNameDialogState extends State<_AlbumNameDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _done() {
    final name = _name.text.trim();
    if (name.isNotEmpty) Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.albumNameTitle),
      content: TextField(
        key: const Key('albumName'),
        controller: _name,
        autofocus: true,
        maxLength: 80,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: l.albumNameHint),
        onSubmitted: (_) => _done(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        TextButton(
          key: const Key('albumNameDone'),
          onPressed: _done,
          child: Text(widget.action),
        ),
      ],
    );
  }
}

/// Makes a new shared album (name, then how others will see this account).
/// Returns its space id, or null when cancelled or it failed.
Future<String?> createSharedAlbum(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final name = await askAlbumName(context, action: l.create);
  if (name == null || !context.mounted) return null;
  final myName = await ztAskSharingName(context, ref, title: name);
  if (myName == null || !context.mounted) return null;
  try {
    return await ref
        .read(sharedAlbumsProvider.notifier)
        .create(name: name, myName: myName);
  } on Object {
    if (context.mounted) _snack(context, l.sharedUnavailable);
    return null;
  }
}

/// Joins an album from an invite link (pasted, scanned or opened).
Future<void> joinSharedAlbum(
  BuildContext context,
  WidgetRef ref, {
  String? link,
}) async {
  final started = await ZtJoinSpacePage.open(context, initialLink: link);
  if (started != null) await ref.read(sharedAlbumsProvider.notifier).reload();
}

Future<bool> _videoWarning(BuildContext context) async {
  final l = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.addVideoTitle),
      content: Text(l.addVideoBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l.cancel),
        ),
        TextButton(
          key: const Key('addVideoAnyway'),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l.addAnyway),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Adds [items] to the album [spaceId]: asks first when there are videos
/// (they keep their details), then uploads in the background and says how
/// it went.
Future<void> addToAlbum(
  BuildContext context,
  WidgetRef ref,
  String spaceId,
  List<NewSharedPhoto> items,
) async {
  if (items.isEmpty) return;
  if (items.any((i) => i.isVideo) && !await _videoWarning(context)) return;
  if (!context.mounted) return;
  final l = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final failed = await ref
      .read(sharedAlbumsProvider.notifier)
      .addPhotos(spaceId, items);
  final added = items.length - failed;
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          failed == 0 ? l.photosAdded(added) : l.someNotAdded(failed),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
}

/// "Add to shared album" from a selection or the viewer: pick an album (or
/// make one), then add.
Future<void> addToSharedAlbumFlow(
  BuildContext context,
  WidgetRef ref,
  List<NewSharedPhoto> items,
) async {
  final l = context.l10n;
  final state = ref.read(sharedAlbumsProvider);
  if (!ref.read(signedInProvider) || !state.available) {
    _snack(context, l.signInToShare);
    return;
  }
  final albums = [
    for (final a in state.albums)
      if (!a.waiting) a,
  ];
  final picked = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 8),
            child: Text(
              l.chooseSharedAlbum,
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
          ),
          ListTile(
            key: const Key('chooseNewAlbum'),
            leading: const Icon(Icons.add),
            title: Text(l.newSharedAlbum),
            onTap: () => Navigator.pop(ctx, ''),
          ),
          for (final a in albums)
            ListTile(
              key: ValueKey('choose_${a.spaceId}'),
              leading: const Icon(Icons.photo_album_outlined),
              title: Text(albumTitle(ctx, a)),
              subtitle: Text(l.itemCount(a.photos.length)),
              onTap: () => Navigator.pop(ctx, a.spaceId),
            ),
        ],
      ),
    ),
  );
  if (picked == null || !context.mounted) return;
  final spaceId = picked.isEmpty
      ? await createSharedAlbum(context, ref)
      : picked;
  if (spaceId == null || !context.mounted) return;
  await addToAlbum(context, ref, spaceId, items);
}

/// The Sharing tab: shared albums, people waiting to join them, and
/// making or joining one.
class SharingPage extends ConsumerWidget {
  const SharingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final signedIn = ref.watch(signedInProvider);
    final state = ref.watch(sharedAlbumsProvider);
    final available = signedIn && state.available;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.sharingTab),
        actions: [
          if (available)
            IconButton(
              key: const Key('joinSharedAlbum'),
              tooltip: l.joinSharedAlbum,
              icon: const Icon(Icons.link),
              onPressed: () => joinSharedAlbum(context, ref),
            ),
          const SettingsButton(),
        ],
      ),
      floatingActionButton: available
          ? FloatingActionButton.extended(
              key: const Key('newSharedAlbum'),
              icon: const Icon(Icons.add),
              label: Text(l.newSharedAlbum),
              onPressed: () async {
                final id = await createSharedAlbum(context, ref);
                if (id != null && context.mounted) {
                  await SharedAlbumPage.open(context, id);
                }
              },
            )
          : null,
      body: !signedIn
          ? GalleryMessage(
              icon: Icons.group_outlined,
              title: l.sharedSignedOutTitle,
              body: l.sharedSignedOutBody,
              action: FilledButton(
                key: const Key('sharingSignIn'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const GallerySignInPage(),
                  ),
                ),
                child: Text(l.signIn),
              ),
            )
          : !state.available && state.ready
          ? GalleryMessage(
              icon: Icons.cloud_off_outlined,
              title: l.sharedSignedOutTitle,
              body: l.sharedUnavailable,
            )
          : !state.ready
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 96),
              children: [
                ZtJoinRequestCards(
                  titleOf: (id) => albumTitle(context, state[id]),
                ),
                if (state.albums.isEmpty)
                  SizedBox(
                    height: 420,
                    child: GalleryMessage(
                      icon: Icons.photo_album_outlined,
                      title: l.sharedEmptyTitle,
                      body: l.sharedEmptyBody,
                    ),
                  ),
                for (final a in state.albums)
                  _AlbumTile(album: a, upload: state.uploads[a.spaceId]),
              ],
            ),
    );
  }
}

class _AlbumTile extends ConsumerWidget {
  const _AlbumTile({required this.album, this.upload});

  final SharedAlbum album;
  final UploadProgress? upload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final cover = album.photos.firstOrNull;
    final progress = upload;
    return ListTile(
      key: ValueKey('sharedAlbum_${album.spaceId}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.square(
          dimension: 56,
          child: cover == null
              ? ColoredBox(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    album.waiting
                        ? Icons.hourglass_top
                        : Icons.photo_album_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : Image(
                  image: sharedThumbnail(
                    ref.watch(sharedFilesProvider),
                    album.spaceId,
                    cover,
                  ),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
        ),
      ),
      title: Text(
        album.waiting && album.name.isEmpty
            ? l.waitingTitle
            : albumTitle(context, album),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        progress != null
            ? l.addingPhotos(progress.done + 1, progress.total)
            : album.waiting
            ? (album.name.isEmpty ? '' : l.waitingTitle)
            : '${l.itemCount(album.photos.length)} · '
                  '${l.memberCount(album.members.length)}',
      ),
      trailing: progress != null
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: () => SharedAlbumPage.open(context, album.spaceId),
    );
  }
}

/// One shared album: its photos by day, adding, people, renaming.
class SharedAlbumPage extends ConsumerStatefulWidget {
  const SharedAlbumPage({super.key, required this.spaceId});

  final String spaceId;

  static Future<void> open(BuildContext context, String spaceId) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SharedAlbumPage(spaceId: spaceId),
        ),
      );

  @override
  ConsumerState<SharedAlbumPage> createState() => _SharedAlbumPageState();
}

class _SharedAlbumPageState extends ConsumerState<SharedAlbumPage> {
  Future<void> _people(SharedAlbum album, {bool inviteNow = false}) =>
      ZtSpacePage.open(
        context,
        spaceId: album.spaceId,
        title: albumTitle(context, album),
        description: context.l10n.sharedAlbumDescription,
        inviteNow: inviteNow,
      );

  Future<void> _rename(SharedAlbum album) async {
    final l = context.l10n;
    final name = await askAlbumName(
      context,
      initial: album.name,
      action: l.save,
    );
    if (name == null || name == album.name) return;
    try {
      await ref.read(sharedAlbumsProvider.notifier).rename(album.spaceId, name);
    } on Object {
      if (mounted) _snack(context, l.sharedUnavailable);
    }
  }

  Future<void> _add() async {
    final l = context.l10n;
    final hasAccount = ref.read(accountOpenProvider);
    final from = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('addFromPhone'),
              leading: const Icon(Icons.smartphone),
              title: Text(l.fromThisPhone),
              onTap: () => Navigator.pop(ctx, 'phone'),
            ),
            if (hasAccount)
              ListTile(
                key: const Key('addFromAccount'),
                leading: const Icon(Icons.cloud_outlined),
                title: Text(l.fromYourAccount),
                onTap: () => Navigator.pop(ctx, 'account'),
              ),
          ],
        ),
      ),
    );
    if (from == null || !mounted) return;
    final List<NewSharedPhoto>? items;
    if (from == 'phone') {
      final picked = await Navigator.of(context).push<List<PhoneMedia>>(
        MaterialPageRoute(builder: (_) => const PickPhonePage()),
      );
      final library = ref.read(phoneLibraryProvider);
      items = picked?.map((m) => phoneToShared(library, m)).toList();
    } else {
      final picked = await Navigator.of(context).push<List<CameraMedia>>(
        MaterialPageRoute(builder: (_) => const PickAccountPage()),
      );
      final store = ref.read(accountPhotoStoreProvider);
      items = picked?.map((m) => accountToShared(store, m)).toList();
    }
    if (items == null || !mounted) return;
    await addToAlbum(context, ref, widget.spaceId, items);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(sharedAlbumsProvider);
    final album = state[widget.spaceId];
    // Left, removed or deleted: nothing left to show here.
    ref.listen(sharedAlbumsProvider.select((s) => s[widget.spaceId]), (
      was,
      now,
    ) {
      if (was != null && now == null && state.ready) {
        Navigator.of(context).maybePop();
      }
    });
    if (album == null) {
      return Scaffold(
        appBar: AppBar(),
        body: state.ready
            ? const SizedBox.shrink()
            : const Center(child: CircularProgressIndicator()),
      );
    }
    if (album.waiting) return _WaitingPage(album: album);
    final upload = state.uploads[album.spaceId];
    final files = ref.watch(sharedFilesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(albumTitle(context, album)),
        actions: [
          IconButton(
            key: const Key('albumAdd'),
            tooltip: l.addPhotos,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            onPressed: _add,
          ),
          IconButton(
            key: const Key('albumPeople'),
            tooltip: l.people,
            icon: const Icon(Icons.group_outlined),
            onPressed: () => _people(album),
          ),
          if (album.isAdmin)
            PopupMenuButton<String>(
              key: const Key('albumMenu'),
              onSelected: (_) => _rename(album),
              itemBuilder: (_) => [
                PopupMenuItem(
                  key: const Key('albumRename'),
                  value: 'rename',
                  child: Text(l.rename),
                ),
              ],
            ),
        ],
        bottom: upload == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Column(
                  children: [
                    Text(
                      l.addingPhotos(upload.done + 1, upload.total),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: upload.total == 0
                          ? null
                          : upload.done / upload.total,
                    ),
                  ],
                ),
              ),
      ),
      body: album.photos.isEmpty
          ? GalleryMessage(
              icon: Icons.photo_album_outlined,
              title: l.albumEmptyTitle,
              body: l.albumEmptyBody,
              action: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    key: const Key('emptyAdd'),
                    onPressed: _add,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(l.addPhotos),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('emptyInvite'),
                    onPressed: () => _people(album, inviteNow: true),
                    icon: const Icon(Icons.person_add_alt),
                    label: Text(l.invitePeople),
                  ),
                ],
              ),
            )
          : MediaGrid<SharedPhoto>(
              items: album.photos,
              keyOf: (p) => p.id,
              dateOf: (p) => p.takenAt,
              thumbnail: (p) => sharedThumbnail(files, album.spaceId, p),
              isVideo: (p) => p.isVideo,
              durationOf: (p) => p.duration,
              onOpen: (sorted, i) =>
                  openSharedViewer(context, ref, album, sorted, i),
            ),
    );
  }
}

/// Joined, waiting for the owner: the code to compare, and giving up.
class _WaitingPage extends ConsumerWidget {
  const _WaitingPage({required this.album});

  final SharedAlbum album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final code = album.joinCode;
    return Scaffold(
      appBar: AppBar(title: Text(l.waitingTitle)),
      body: GalleryMessage(
        icon: Icons.hourglass_top,
        title: l.waitingTitle,
        body: code == null ? '' : l.waitingBody,
        action: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (code != null)
              SelectableText(
                code,
                key: const Key('waitingCode'),
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 24),
            OutlinedButton(
              key: const Key('stopWaiting'),
              onPressed: () async {
                await ref
                    .read(sharedAlbumsProvider.notifier)
                    .stopWaiting(album.spaceId);
                if (context.mounted) Navigator.of(context).maybePop();
              },
              child: Text(l.stopWaiting),
            ),
          ],
        ),
      ),
    );
  }
}

String _megabytes(int bytes) => (bytes / 1000000).toStringAsFixed(1);

/// Opens the viewer on an album's photos: Share and Save to phone for
/// everything, Remove for what this account added.
void openSharedViewer(
  BuildContext context,
  WidgetRef ref,
  SharedAlbum album,
  List<SharedPhoto> items,
  int index,
) {
  final l = context.l10n;
  final files = ref.read(sharedFilesProvider);
  final me = ref.read(sharedAlbumsProvider).myUserId;
  final byId = {for (final p in items) p.id: p};
  final locale = Localizations.localeOf(context).toLanguageTag();
  Future<File> video(SharedPhoto p) async => sharedVideoFile(
    files,
    await ref.read(playDirProvider)(),
    album.spaceId,
    p,
  );
  Navigator.of(context).push(
    ViewerPage.route(
      entries: [
        for (final p in items)
          ViewerEntry(
            key: p.id,
            isVideo: p.isVideo,
            takenAt: p.takenAt,
            image: p.isVideo
                ? sharedThumbnail(files, album.spaceId, p)
                : sharedImage(files, album.spaceId, p),
            videoFile: p.isVideo ? () => video(p) : null,
            details: [
              (l.detailAddedBy, album.nameOf(p.owner) ?? l.someone),
              (l.detailAdded, DateFormat.yMMMd(locale).format(p.addedAt)),
              if (p.width > 0 && p.height > 0)
                (l.detailSize, '${p.width} × ${p.height}'),
              if (p.isVideo && p.duration > Duration.zero)
                (l.detailLength, formatDuration(p.duration)),
              (l.detailFileSize, l.megabytes(_megabytes(p.size))),
              (l.detailWhere, l.inSharedAlbumEncrypted),
            ],
          ),
      ],
      initialIndex: index,
      actions: [
        ViewerAction(
          key: const Key('viewerShare'),
          icon: Icons.share_outlined,
          label: l.share,
          run: (context, e) async {
            final p = byId[e.key]!;
            final share = ShareOut(ref);
            if (p.isVideo) {
              final f = await video(p);
              if (context.mounted) await share.videoFile(context, f);
            } else {
              final bytes = await readWhole(
                files,
                album.spaceId,
                p.owner,
                p.files,
              );
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
            final p = byId[e.key]!;
            final library = ref.read(phoneLibraryProvider);
            final messenger = ScaffoldMessenger.maybeOf(context);
            final done = l.savedToPhone, failed = l.saveFailed;
            try {
              if (p.isVideo) {
                await library.saveVideo(await video(p), takenAt: p.takenAt);
              } else {
                await library.savePhoto(
                  await readWhole(files, album.spaceId, p.owner, p.files),
                  takenAt: p.takenAt,
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
        ViewerAction(
          key: const Key('viewerRemove'),
          icon: Icons.delete_outline,
          label: l.removeFromAlbum,
          visibleFor: (e) => byId[e.key]?.owner == me,
          run: (context, e) async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(l.removePhotoTitle),
                content: Text(l.removePhotoBody),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(l.cancel),
                  ),
                  TextButton(
                    key: const Key('removeConfirm'),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(l.remove),
                  ),
                ],
              ),
            );
            if (ok != true) return false;
            try {
              await ref
                  .read(sharedAlbumsProvider.notifier)
                  .deletePhoto(album.spaceId, byId[e.key]!);
              return true;
            } on Object {
              if (context.mounted) _snack(context, l.sharedUnavailable);
              return false;
            }
          },
        ),
      ],
    ),
  );
}

/// Picking photos to add: tap to pick, then Add.
mixin _Picking<T, W extends ConsumerStatefulWidget> on ConsumerState<W> {
  final Map<String, T> picked = {};

  String keyOf(T item);

  void toggle(T item) => setState(() {
    final k = keyOf(item);
    if (picked.remove(k) == null) picked[k] = item;
  });

  PreferredSizeWidget pickBar(String title) {
    final l = context.l10n;
    return AppBar(
      title: Text(picked.isEmpty ? title : l.selectedCount(picked.length)),
      actions: [
        TextButton(
          key: const Key('pickAdd'),
          onPressed: picked.isEmpty
              ? null
              : () => Navigator.pop(context, picked.values.toList()),
          child: Text(l.addSelected(picked.length)),
        ),
      ],
    );
  }
}

/// The phone's photos, to pick from.
class PickPhonePage extends ConsumerStatefulWidget {
  const PickPhonePage({super.key});

  @override
  ConsumerState<PickPhonePage> createState() => _PickPhonePageState();
}

class _PickPhonePageState extends ConsumerState<PickPhonePage>
    with _Picking<PhoneMedia, PickPhonePage> {
  @override
  String keyOf(PhoneMedia item) => item.id;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final access = ref.watch(phoneAccessProvider);
    final media = ref.watch(phoneMediaProvider);
    final library = ref.watch(phoneLibraryProvider);
    return Scaffold(
      appBar: pickBar(l.fromThisPhone),
      body: switch ((access, media)) {
        (AsyncData(value: PhoneAccess.none), _) => const PhoneAccessNotice(),
        (_, AsyncData(:final value)) when value.isEmpty => Center(
          child: Text(l.nothingToPick),
        ),
        (_, AsyncData(:final value)) => MediaGrid<PhoneMedia>(
          items: value,
          keyOf: (m) => m.id,
          dateOf: (m) => m.takenAt,
          thumbnail: (m) => library.thumbnail(m),
          isVideo: (m) => m.isVideo,
          durationOf: (m) => m.duration,
          selected: picked.keys.toSet(),
          onSelect: toggle,
          onOpen: (sorted, i) => toggle(sorted[i]),
        ),
        (_, AsyncError()) => Center(child: Text(l.photosCantLoad)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// The account's photos, to pick from.
class PickAccountPage extends ConsumerStatefulWidget {
  const PickAccountPage({super.key});

  @override
  ConsumerState<PickAccountPage> createState() => _PickAccountPageState();
}

class _PickAccountPageState extends ConsumerState<PickAccountPage>
    with _Picking<CameraMedia, PickAccountPage> {
  @override
  String keyOf(CameraMedia item) => item.id;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final media = ref.watch(accountMediaProvider);
    final store = ref.watch(accountPhotoStoreProvider);
    return Scaffold(
      appBar: pickBar(l.fromYourAccount),
      body: switch (media) {
        AsyncData(:final value) when value.isEmpty => Center(
          child: Text(l.nothingToPick),
        ),
        AsyncData(:final value) => MediaGrid<CameraMedia>(
          items: value,
          keyOf: (m) => m.id,
          dateOf: (m) => m.takenAt,
          thumbnail: (m) => accountThumbnail(store, m),
          isVideo: (m) => m.isVideo,
          selected: picked.keys.toSet(),
          onSelect: toggle,
          onOpen: (sorted, i) => toggle(sorted[i]),
        ),
        AsyncError() => Center(child: Text(l.accountCantLoadTitle)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
