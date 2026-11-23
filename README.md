# Zero-Trust Gallery

The photo app of the Zero-Trust suite: the photos on your phone, the
encrypted photos in your Zero-Trust account (the same ones ZT Camera backs
up), and end-to-end encrypted shared albums with other Zero-Trust users.

The server never sees a photo, an album name, a date or a place: everything
that leaves the phone is encrypted on it first.

On the phone it is called **ZT Gallery**; in stores and releases,
**Zero-Trust Gallery**. Licensed under the GNU AGPL v3 (see `LICENSE`).

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

Package `dev.sagron.zerotrustgallery`. Tests: `flutter test` (needs a
`.env` file, which may be empty).
