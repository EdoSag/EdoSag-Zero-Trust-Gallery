package dev.sagron.zerotrustgallery

import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * FlutterFragmentActivity, not FlutterActivity: the biometric unlock prompt
 * (local_auth, in the shared core) needs a FragmentActivity.
 */
class MainActivity : FlutterFragmentActivity()
