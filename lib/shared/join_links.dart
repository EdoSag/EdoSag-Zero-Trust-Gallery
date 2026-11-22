import 'package:flutter/foundation.dart';

/// Shared album invites opened from a message or a QR code:
/// https://zerotrust.bz/join/gallery#zt1.gallery.… Android opens them in
/// this app (App Links), [EmailLinks] hands them here, and the home screen
/// opens the join page once the account is open.
abstract final class JoinLinks {
  /// The invite waiting to be opened, if any.
  static final pending = ValueNotifier<String?>(null);

  /// Whether [uri] is a Gallery invite.
  static bool isInvite(Uri uri) =>
      uri.host == 'zerotrust.bz' &&
      (uri.path == '/join/gallery' || uri.path.startsWith('/join/gallery/')) &&
      uri.fragment.isNotEmpty;

  static void offer(Uri uri) {
    if (isInvite(uri)) pending.value = uri.toString();
  }

  /// The waiting invite, once: later calls return null.
  static String? take() {
    final link = pending.value;
    pending.value = null;
    return link;
  }
}
