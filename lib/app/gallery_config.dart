import 'package:flutter/material.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

/// Violet: no other suite app uses it, and it doesn't read as Google
/// Photos' four colours.
const Color galleryAccent = Color(0xFF8B5CF6);

/// Gallery in the suite. Not in the core's `ZtSuite` list yet, so the other
/// apps don't link to it before it's released.
const ZtSuiteApp gallerySuiteApp = ZtSuiteApp(
  appId: 'gallery',
  name: 'Gallery',
  tagline: 'Your photos, your encrypted backup and shared albums',
  icon: Icons.photo_library_outlined,
  accent: galleryAccent,
  androidPackage: 'dev.sagron.zerotrustgallery',
);

/// `dataAppId: 'camera'`: Gallery opens the same synced items and encrypted
/// files as ZT Camera, with the same keys, so the photos Camera backs up are
/// here and nothing ever needs moving. Shared albums are Gallery's own
/// (shared spaces of the app `gallery`). Never change either id: existing
/// data would no longer open.
const ZtAppConfig galleryAppConfig = ZtAppConfig(
  appId: 'gallery',
  dataAppId: 'camera',
  displayName: 'Zero-Trust Gallery',
  accent: galleryAccent,
);
