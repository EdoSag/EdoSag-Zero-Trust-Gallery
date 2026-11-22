import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../account/account_pages.dart';
import '../l10n/l10n.dart';
import '../phone/phone_pages.dart';

/// Which tab is open.
final homeTabProvider = NotifierProvider<HomeTab, int>(HomeTab.new);

class HomeTab extends Notifier<int> {
  @override
  int build() => 0;

  void set(int tab) => state = tab;
}

/// The app's tabs: Photos (the phone's), Albums (the phone's folders and
/// the account's albums) and Account (the photos in the Zero-Trust
/// account).
class GalleryHome extends ConsumerWidget {
  const GalleryHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final tab = ref.watch(homeTabProvider);
    return Scaffold(
      body: IndexedStack(
        index: tab,
        children: const [
          PhotosPage(),
          FoldersPage(extra: [AccountAlbumsSection()]),
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
            icon: const Icon(Icons.cloud_outlined),
            selectedIcon: const Icon(Icons.cloud),
            label: l.accountTab,
          ),
        ],
      ),
    );
  }
}
