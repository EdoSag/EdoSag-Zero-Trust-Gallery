# Zero-Trust Gallery

The photo app of the Zero-Trust suite: the photos on your phone, the
encrypted photos in your Zero-Trust account (the same ones ZT Camera backs
up), and end-to-end encrypted shared albums with other Zero-Trust users. On
the phone it is called **ZT Gallery**; in stores and on release pages,
**Zero-Trust Gallery**. Built on
[Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core). Part of the
[Zero-Trust suite](https://zerotrust.bz).

## What it does

- **Photos**: every photo and video on the phone, by day; pinch to show 2
  to 6 across; select several to share or delete.
- **Albums**: the phone's folders (Camera, Screenshots, WhatsApp...), and
  the albums in your account.
- **Account**: the photos you back up with ZT Camera's Private vault,
  decrypted on the phone. Save one back to the phone, or share it.
- **Viewer**: swipe, pinch or double-tap to zoom, play videos, details.
- **Clean sharing**: photos leave without where, when and on which phone
  they were taken (EXIF, XMP and IPTC removed without re-compressing;
  turned or non-JPEG photos are saved anew as a plain JPEG).
- **Shared albums** (Sharing tab): make an album, invite people with a
  link or QR code, let them in after comparing a code, and everyone adds
  photos and videos from the phone or the account. Only owners rename an
  album; only whoever added a photo removes it; when someone leaves, what
  they added goes with them (files included). Photos go in without their
  hidden details; videos only after a warning.

## Privacy

ZT Gallery works without an account. When you sign in, it is zero-knowledge like every Zero-Trust app: your data is encrypted on
your device, with keys made from your password, before anything is sent.
The server stores only ciphertext and your password itself is never
sent, so neither we nor anyone who breaks into the server can read your
data. The recovery key shown at sign-up is the only way back in if you
forget the password. How the keys work:
[Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core#key-hierarchy) and
[zerotrust.bz/security](https://zerotrust.bz/security/).

- The server never sees a photo, an album name, a date or a place:
  everything that leaves the phone is encrypted on it first.
- Shared photos leave without their hidden details (where, when and on
  which phone they were taken).
- The place inside photos (`ACCESS_MEDIA_LOCATION`) is never asked for.

## One account, one core

Signing in is optional. The account is the one Zero-Trust account that opens every app in the suite. Sign-in, unlock
(fingerprint or face, auto-lock), the recovery key, settings, the look,
sync and languages come from
[Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core), so they work
the same in every app. Accounts made before the core still sign in and
see their data.

## Install

Android: get the latest signed APK from this repository's
[Releases](https://github.com/EdoSag/Zero-Trust-Gallery/releases/latest),
or from [zerotrust.bz/install](https://zerotrust.bz/install/#gallery),
which also shows each file's SHA-256, the signing fingerprint and an
Obtainium link. GitHub Releases are the main way the apps are published.

Builds from GitHub check for a newer release themselves (Settings > About,
one anonymous request a day, can be turned off). Every Zero-Trust app is signed
with the same key, and Android only installs an update signed with it.

## Languages

English and Hebrew, with right-to-left layout. Choose under
Settings > Appearance > Language.

## How it is built

- Flutter on [Zero-Trust-Core](https://github.com/EdoSag/Zero-Trust-Core):
  the same account, lock, settings and look as every Zero-Trust app.
- `ZtAppConfig(appId: 'gallery', dataAppId: 'camera')`: Gallery opens the
  same synced items (`camera_media`, `camera_album`) and encrypted files as
  ZT Camera, with the same keys. Keep `lib/account/camera_media.dart` in
  step with Camera's `lib/private_vault/vault_backup.dart`.
- Shared albums are core Z24 shared spaces (`app: 'gallery'`), one per
  album: an `album` item names it and each photo is an item
  `photo/<owner>/<id>` (`gallerySpacePolicy` makes it its owner's alone).
  The files are encrypted attachments at
  `<uploader>/space_<space id>/<file>` in `zt-attachments`, readable by
  the album's members only (Core migration 20261122120000); files over
  19 MB are kept in pieces. Invites open in the app from
  `https://zerotrust.bz/join/gallery#...` (App Links).
- The phone's photos come from Android's MediaStore (photo_manager). The
  place inside photos (`ACCESS_MEDIA_LOCATION`) is never asked for.
- CI (`.github/workflows/android-apk.yml`) runs the suite's release checks
  as `camera`, analyze and tests, and builds the signed APK; a push to main
  publishes it as a GitHub release.
- Package `dev.sagron.zerotrustgallery`.

## Build from source

Flutter 3.47.9, the version CI pins (3.50 deprecates `material.dart` and
fails analyze).

First create a file named `.env` in the project folder. It is not committed
(CI writes its own) and it is bundled into the APK, so it holds public client
values only, never a service-role key:

```
SUPABASE_URL=https://<project>.supabase.co
SUPABASE_ANON_KEY=<publishable key>
```

Then:

```bash
flutter pub get
dart run zt_release_checks --app camera   # shared release checks (Gallery runs them as `camera`)
flutter analyze && flutter test
flutter run
```

Never add `cryptography_flutter`: it breaks the core's key derivation and
sign-in fails.

The tests need a `.env` file, which may be empty.

## Branches and releases

Work happens on `Dev`: pull requests target `Dev`, never `main`, and get a
test build. A release is one `Dev` → `main` pull request. Every push to
`main` runs the suite's release checks, builds a signed APK and a Google Play bundle
and publishes them as a GitHub Release named "Zero-Trust Gallery"
(`.github/workflows/android-apk.yml`). The workflow needs the repository
secrets `ANDROID_KEYSTORE_BASE64` and `ANDROID_KEYSTORE_PASSWORD`, the
keystore shared by all Zero-Trust apps.

## Support and security

- Help centre: [zerotrust.bz/help](https://zerotrust.bz/help/). Questions and
  account deletion: support@zerotrust.bz.
- Security problems: please report them privately to cyber@zerotrust.bz. What
  the encryption does and doesn't protect against is on
  [zerotrust.bz/security](https://zerotrust.bz/security/).
- [Privacy policy](https://zerotrust.bz/privacy/) and
  [terms](https://zerotrust.bz/terms/).

## License

Copyright (C) 2026 Edo Sagron (https://zerotrust.bz)

Zero-Trust is open source under the [GNU Affero General Public License v3.0](LICENSE)
(AGPL-3.0-only), the same licence Signal uses.

- You may use, study, change and share the code, including in your own projects.
- If you share a changed version, or run it for other people over a network, you must
  publish your full source code under the same licence.
- This program comes with no warranty; see the licence for details.

Third-party libraries keep their own licences; the app lists them under
Settings > Open-source licences.

### Name and logo

The AGPL covers the code, not the brand. "Zero-Trust", "ZT", the app names and icons are
reserved. If you publish a fork, give it a different name and icon so nobody mistakes it
for an official Zero-Trust app.

### Servers

The official apps use the Zero-Trust servers. A fork must use its own backend (for
example its own Supabase project) and must not connect to the official servers.

### Contributing

Pull requests are welcome. By sending one you agree that your contribution is licensed
under the AGPL-3.0 and that the copyright holder may also license it under other terms,
including commercially. This keeps the project able to offer paid plans and other licences.
