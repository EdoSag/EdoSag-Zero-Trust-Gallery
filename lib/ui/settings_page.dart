import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../app/account.dart';
import '../l10n/l10n.dart';
import '../phone/phone_library.dart';

/// The suite's settings screen. Gallery works without an account, so with
/// nobody signed in it shows what needs none (language, theme, photo
/// access, About) and "Sign in or create account" for the account's
/// photos and shared albums.
class GallerySettingsPage extends ConsumerWidget {
  const GallerySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final access = ref.watch(phoneAccessProvider).value ?? PhoneAccess.none;
    return ZtSettingsPage(
      accountOptional: true,
      showSyncStatus: true,
      showStorageUsage: true,
      onSignIn: () => Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const GallerySignInPage()),
      ),
      onSignedOut: () => Navigator.of(context).popUntil((r) => r.isFirst),
      onOpenUrl: (url) => launchUrl(url, mode: LaunchMode.externalApplication),
      privacyPolicyUrl: Uri.parse('https://zerotrust.bz/privacy'),
      termsUrl: Uri.parse('https://zerotrust.bz/terms'),
      supportUrl: Uri.parse('https://zerotrust.bz/support'),
      appSection: [
        ListTile(
          key: const ValueKey('photoAccess'),
          leading: const Icon(Icons.photo_library_outlined),
          title: Text(l.photoAccess),
          subtitle: Text(switch (access) {
            PhoneAccess.all => l.photoAccessAll,
            PhoneAccess.some => l.photoAccessSome,
            PhoneAccess.none => l.photoAccessNone,
          }),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => ref.read(phoneLibraryProvider).openSettings(),
        ),
        ListTile(
          leading: const Icon(Icons.share_outlined),
          title: Text(l.cleanShareTitle),
          subtitle: Text(l.cleanShareBody),
        ),
      ],
    );
  }
}
