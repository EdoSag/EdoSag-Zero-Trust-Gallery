import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Hidden details in a JPEG: where (GPS), when, which phone, and anything
/// else in EXIF, XMP, IPTC or comments. [stripJpeg] removes them without
/// touching the picture itself (no re-compression, no quality lost).
///
/// Kept: JFIF (APP0), the colour profile (APP2 ICC, so colours stay right),
/// Adobe's colour marker (APP14), and of course the image data. Metadata
/// between the scans of a progressive JPEG goes too, and so does anything
/// after the end of the picture.
abstract final class CleanPhoto {
  static bool isJpeg(Uint8List b) =>
      b.length > 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF;

  /// The JPEG without its hidden details, or null when [jpeg] isn't a JPEG
  /// this can read, or when its EXIF turns the picture (orientation other
  /// than 1): removing that would show it sideways, so the caller makes a
  /// new JPEG instead.
  static Uint8List? stripJpeg(Uint8List jpeg) {
    if (!isJpeg(jpeg)) return null;
    final out = BytesBuilder(copy: false)..add(const [0xFF, 0xD8]);
    var i = 2;
    while (i + 2 <= jpeg.length) {
      if (jpeg[i] != 0xFF) return null;
      final marker = jpeg[i + 1];
      // Fill bytes before a marker.
      if (marker == 0xFF) {
        i++;
        continue;
      }
      // End of the picture: anything after it is dropped.
      if (marker == 0xD9) {
        out.add(const [0xFF, 0xD9]);
        return out.takeBytes();
      }
      // Markers without a length.
      if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
        out.add(Uint8List.sublistView(jpeg, i, i + 2));
        i += 2;
        continue;
      }
      if (i + 4 > jpeg.length) return null;
      final len = (jpeg[i + 2] << 8) | jpeg[i + 3];
      if (len < 2 || i + 2 + len > jpeg.length) return null;
      final segment = Uint8List.sublistView(jpeg, i, i + 2 + len);
      if (marker == 0xE1 && _turns(segment)) return null;
      if (_keep(marker)) out.add(segment);
      i += 2 + len;
      // Start of scan: its picture data runs up to the next real marker
      // (0xFF 0x00 is a stuffed byte, 0xFF 0xD0-D7 a restart marker, both
      // part of the data). Markers after it are read like the ones before.
      if (marker == 0xDA) {
        final start = i;
        while (i + 1 < jpeg.length) {
          if (jpeg[i] == 0xFF) {
            final next = jpeg[i + 1];
            if (next != 0x00 && !(next >= 0xD0 && next <= 0xD7)) break;
            i += 2;
          } else {
            i++;
          }
        }
        if (i + 1 >= jpeg.length) return null; // cut off: no end marker
        out.add(Uint8List.sublistView(jpeg, start, i));
      }
    }
    return null;
  }

  /// A new JPEG of [bytes], turned the right way up, with nothing hidden
  /// in it. Null when it can't be read as a picture. Slow on big photos:
  /// run it with `compute`.
  static Uint8List? remake(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    return img.encodeJpg(img.bakeOrientation(decoded), quality: 92);
  }

  /// APP0 (JFIF), APP2 (ICC profile), APP14 (Adobe) and every non-APP
  /// marker (tables, frame header). Dropped: APP1 (EXIF, XMP), APP3 to
  /// APP13 and APP15 (maker data, IPTC), COM (comments).
  static bool _keep(int marker) {
    if (marker == 0xFE) return false;
    if (marker >= 0xE0 && marker <= 0xEF) {
      return marker == 0xE0 || marker == 0xE2 || marker == 0xEE;
    }
    return true;
  }

  /// Whether an APP1 EXIF segment says the picture is stored turned
  /// (orientation tag 0x0112 other than 1).
  static bool _turns(Uint8List seg) => exifOrientation(seg) > 1;

  /// The EXIF orientation in an APP1 segment (marker included), 1 when
  /// there is none.
  static int exifOrientation(Uint8List seg) {
    // FF E1 len(2) "Exif\0\0" then TIFF.
    const header = [0x45, 0x78, 0x69, 0x66, 0x00, 0x00];
    if (seg.length < 4 + 6 + 8) return 1;
    for (var k = 0; k < 6; k++) {
      if (seg[4 + k] != header[k]) return 1;
    }
    final t = 10; // TIFF start
    final little = seg[t] == 0x49 && seg[t + 1] == 0x49;
    final big = seg[t] == 0x4D && seg[t + 1] == 0x4D;
    if (!little && !big) return 1;
    int u16(int at) {
      if (at + 2 > seg.length) throw RangeError.index(at, seg);
      return little
          ? seg[at] | (seg[at + 1] << 8)
          : (seg[at] << 8) | seg[at + 1];
    }

    int u32(int at) {
      if (at + 4 > seg.length) throw RangeError.index(at, seg);
      return little
          ? seg[at] |
                (seg[at + 1] << 8) |
                (seg[at + 2] << 16) |
                (seg[at + 3] << 24)
          : (seg[at] << 24) |
                (seg[at + 1] << 16) |
                (seg[at + 2] << 8) |
                seg[at + 3];
    }

    try {
      final ifd = t + u32(t + 4);
      final count = u16(ifd);
      for (var n = 0; n < count; n++) {
        final e = ifd + 2 + n * 12;
        if (u16(e) == 0x0112) return u16(e + 8);
      }
    } on RangeError {
      return 1;
    }
    return 1;
  }
}
