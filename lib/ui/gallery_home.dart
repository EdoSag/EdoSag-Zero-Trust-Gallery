import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../account/account_pages.dart';
import '../l10n/l10n.dart';
import '../phone/phone_pages.dart';
import '../shared/join_links.dart';
import '../shared/shared_albums.dart';
import '../shared/shared_pages.dart';

/// Which tab is open.
final homeTabProvider = NotifierProvider<HomeTab, int>(HomeTab.new);

class HomeTab extends Notifier<int> {
  static const photos = 0, albums = 1, sharing = 2, account = 3;

  @override
  int build() => photos;

  void set(int tab) => state = tab;
}

/// The app's tabs: Photos (the phone's), Albums (the phone's folders and
/// the account's albums), Sharing (shared albums) and Account (the photos
/// in the Zero-Trust account).
class GalleryHome extends ConsumerStatefulWidget {
  const GalleryHome({super.key});

  @override
  ConsumerState<GalleryHome> createState() => _GalleryHomeState();
}

class _GalleryHomeState extends ConsumerState<GalleryHome> {
  @override
  void initState() {
    super.initState();
    JoinLinks.pending.addListener(_invite);
    // An invite that opened the app arrived before this screen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _invite());
  }

  @override
  void dispose() {
    JoinLinks.pending.removeListener(_invite);
    super.dispose();
  }

  /// A shared album invite was opened: the Sharing tab, then the join page
  /// once the account is open (signed out, the tab asks to sign in and
  /// the invite waits).
  void _invite() {
    if (!mounted || JoinLinks.pending.value == null) return;
    ref.read(homeTabProvider.notifier).set(HomeTab.sharing);
    if (!ref.read(sharedAlbumsProvider).available) return;
    final link = JoinLinks.take();
    if (link != null) joinSharedAlbum(context, ref, link: link);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tab = ref.watch(homeTabProvider);
    ref.listen(sharedAlbumsProvider.select((s) => s.available), (_, now) {
      if (now) _invite();
    });
    return Scaffold(
      body: IndexedStack(
        index: tab,
        children: const [
          PhotosPage(),
          FoldersPage(extra: [AccountAlbumsSection()]),
          SharingPage(),
          AccountPhotosPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: ref.read(homeTabProvider.notifier).set,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.photo_outlined),
            selectedIcon: const Icon(Icons.photo),
            label: l.photosTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.photo_album_outlined),
            selectedIcon: const Icon(Icons.photo_album),
            label: l.albumsTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.group_outlined),
            selectedIcon: const Icon(Icons.group),
            label: l.sharingTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.cloud_outlined),
            selectedIcon: const Icon(Icons.cloud),
            label: l.accountTab,
          ),
        ],
      ),
    );
  }
}
