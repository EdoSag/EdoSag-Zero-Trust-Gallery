import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import 'account/account_photos.dart';
import 'app/email_links.dart';
import 'app/gallery_config.dart';
import 'app/gallery_gate.dart';
import 'l10n/l10n.dart';
import 'shared/shared_album.dart';
import 'viewer/share_out.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The Zero-Trust account is optional here: the phone's photos show
  // without it. Signing in adds the account's photos and shared albums.
  // A failure here must not keep the photos away.
  try {
    await dotenv.load(fileName: '.env');
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
    unawaited(EmailLinks.listen());
  } on Object catch (e) {
    debugPrint('Account setup failed: $e');
  }
  // English or Hebrew, as picked in Settings, from the first frame.
  await ZtLanguageController.preload();
  runApp(
    ProviderScope(
      overrides: [
        ztAppConfigProvider.overrideWithValue(galleryAppConfig),
        // Only owners rename an album; each photo is its adder's alone.
        ztSpacePolicyProvider.overrideWithValue(gallerySpacePolicy),
      ],
      child: const ZeroTrustGalleryApp(),
    ),
  );
}

class ZeroTrustGalleryApp extends ConsumerStatefulWidget {
  const ZeroTrustGalleryApp({super.key, this.home = const GalleryGate()});

  final Widget home;

  @override
  ConsumerState<ZeroTrustGalleryApp> createState() =>
      _ZeroTrustGalleryAppState();
}

class _ZeroTrustGalleryAppState extends ConsumerState<ZeroTrustGalleryApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tidy();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back in the app: copies made for sharing, and videos put together to
  /// play, are no longer needed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _tidy();
  }

  void _tidy() {
    () async {
      try {
        await ShareOut.clear(await ref.read(outgoingDirProvider)());
        await ShareOut.clear(await ref.read(playDirProvider)());
      } on Object {
        // No temporary folder (tests): nothing to tidy.
      }
    }();
  }

  @override
  Widget build(BuildContext context) => ZtThemeBuilder(
    builder: (context, theme, darkTheme, mode) => MaterialApp(
      // On-device task switcher label; the store name is Zero-Trust Gallery.
      title: 'ZT Gallery',
      theme: theme,
      darkTheme: darkTheme,
      themeMode: mode,
      // English (default) or Hebrew, from Settings → Appearance → Language.
      locale: ref.watch(ztLanguageProvider),
      supportedLocales: ZtLanguages.supported,
      localizationsDelegates: const [
        AppL10n.delegate,
        ...ZtLanguages.delegates,
      ],
      home: widget.home,
      // Any touch on any screen counts as activity for auto-lock.
      builder: (context, child) => Listener(
        onPointerDown: (_) =>
            ref.read(vaultControllerProvider.notifier).touch(),
        child: child,
      ),
    ),
  );
}
