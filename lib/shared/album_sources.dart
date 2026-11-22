import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../account/account_photos.dart';
import '../account/camera_media.dart';
import '../phone/phone_library.dart';
import '../viewer/share_out.dart';
import 'shared_albums.dart';

/// A small JPEG preview (512 pixels on the longer side) of [bytes].
Uint8List? _preview(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final upright = img.bakeOrientation(decoded);
  final small = upright.width >= upright.height
      ? img.copyResize(upright, width: 512)
      : img.copyResize(upright, height: 512);
  return img.encodeJpg(small, quality: 85);
}

/// A photo as it goes into a shared album: the same JPEG without where,
/// when and on which phone it was taken, or, when that can't be cut out
/// (other formats, a turned JPEG), a new JPEG.
Future<Uint8List> cleanForAlbum(Uint8List bytes) async {
  final clean = await ShareOut.cleanBytes(bytes);
  if (clean == null) throw const FormatException('Not a picture');
  return clean;
}

/// A phone photo or video, ready to add.
NewSharedPhoto phoneToShared(PhoneLibrary library, PhoneMedia m) =>
    NewSharedPhoto(
      isVideo: m.isVideo,
      mime: m.isVideo ? (m.mime ?? 'video/mp4') : 'image/jpeg',
      takenAt: m.takenAt,
      width: m.width,
      height: m.height,
      duration: m.duration,
      thumbnail: () => library.thumbnailBytes(m),
      content: m.isVideo
          ? () async* {
              final f = await library.file(m);
              if (f == null) throw StateError('The video is gone');
              yield* f.openRead();
            }
          : () async* {
              final clean = await ShareOut.cleanPhoto(
                await library.bytes(m),
                () => library.plainJpeg(m),
              );
              if (clean == null) throw StateError("The photo can't be read");
              yield clean;
            },
    );

/// A photo or video from the account (ZT Camera's vault), ready to add.
NewSharedPhoto accountToShared(AccountPhotoStore store, CameraMedia m) =>
    NewSharedPhoto(
      isVideo: m.isVideo,
      mime: m.isVideo ? m.mime : 'image/jpeg',
      takenAt: m.takenAt,
      thumbnail: () async {
        final thumb = m.thumb;
        if (thumb != null) return store.read(thumb);
        if (m.isVideo) return null;
        return compute(_preview, await store.read(m.file));
      },
      content: m.isVideo
          ? () async* {
              for (final part in m.files) {
                yield await store.read(part);
              }
            }
          : () async* {
              yield await cleanForAlbum(await store.read(m.file));
            },
    );
