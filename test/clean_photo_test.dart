import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zerotrust_gallery/viewer/clean_photo.dart';
import 'package:zerotrust_gallery/viewer/share_out.dart';

import 'support/fakes.dart';

/// An APP1 EXIF segment with one IFD0 entry (orientation) and some text
/// standing in for GPS and phone details.
Uint8List exifSegment({int orientation = 1, bool little = true}) {
  final tiff = BytesBuilder();
  void u16(int v) => tiff.add(little ? [v & 0xFF, v >> 8] : [v >> 8, v & 0xFF]);
  void u32(int v) => tiff.add(
    little
        ? [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, v >> 24]
        : [v >> 24, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF],
  );
  tiff.add(little ? [0x49, 0x49] : [0x4D, 0x4D]);
  u16(42);
  u32(8);
  u16(1); // one entry
  u16(0x0112);
  u16(3); // SHORT
  u32(1);
  u16(orientation);
  u16(0);
  u32(0); // no next IFD
  tiff.add(ascii.encode('GPS 32.0853N 34.7818E Pixel 10 Pro'));
  final body = [...ascii.encode('Exif'), 0, 0, ...tiff.takeBytes()];
  final len = body.length + 2;
  return Uint8List.fromList([0xFF, 0xE1, len >> 8, len & 0xFF, ...body]);
}

Uint8List segment(int marker, List<int> body) {
  final len = body.length + 2;
  return Uint8List.fromList([0xFF, marker, len >> 8, len & 0xFF, ...body]);
}

/// [testJpeg] with [extra] segments put right after its start marker.
Uint8List withSegments(List<Uint8List> extra) => Uint8List.fromList([
  0xFF,
  0xD8,
  for (final s in extra) ...s,
  ...testJpeg.sublist(2),
]);

bool contains(Uint8List hay, List<int> needle) {
  outer:
  for (var i = 0; i + needle.length <= hay.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (hay[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}

void main() {
  test(
    'removes EXIF, XMP-style APP1, IPTC and comments, keeps the picture',
    () {
      final dirty = withSegments([
        exifSegment(),
        segment(0xED, ascii.encode('Photoshop 3.0 IPTC city=Tel Aviv')),
        segment(0xFE, ascii.encode('taken at home')),
        segment(0xE2, ascii.encode('ICC_PROFILE colour')),
      ]);
      final clean = CleanPhoto.stripJpeg(dirty)!;

      expect(contains(clean, ascii.encode('Exif')), isFalse);
      expect(contains(clean, ascii.encode('Pixel 10 Pro')), isFalse);
      expect(contains(clean, ascii.encode('Tel Aviv')), isFalse);
      expect(contains(clean, ascii.encode('taken at home')), isFalse);
      // The colour profile stays, so colours look the same.
      expect(contains(clean, ascii.encode('ICC_PROFILE')), isTrue);
      // Still a picture, the same size.
      final decoded = img.decodeJpg(clean)!;
      expect(decoded.width, 8);
      expect(decoded.height, 8);
      expect(clean.length, lessThan(dirty.length));
    },
  );

  test('a turned photo is not stripped (it would show sideways)', () {
    expect(
      CleanPhoto.stripJpeg(withSegments([exifSegment(orientation: 6)])),
      isNull,
    );
    expect(
      CleanPhoto.stripJpeg(
        withSegments([exifSegment(orientation: 8, little: false)]),
      ),
      isNull,
    );
    expect(
      CleanPhoto.stripJpeg(withSegments([exifSegment(orientation: 1)])),
      isNotNull,
    );
  });

  test('reads the orientation in both byte orders', () {
    expect(CleanPhoto.exifOrientation(exifSegment(orientation: 3)), 3);
    expect(
      CleanPhoto.exifOrientation(exifSegment(orientation: 6, little: false)),
      6,
    );
    expect(
      CleanPhoto.exifOrientation(
        segment(0xE1, ascii.encode('http://ns.adobe.com/xap/1.0/')),
      ),
      1,
    );
  });

  test('not a JPEG, or a broken one: null', () {
    expect(CleanPhoto.stripJpeg(testPng), isNull);
    expect(
      CleanPhoto.stripJpeg(
        Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE1, 0xFF, 0xFF]),
      ),
      isNull,
    );
  });

  test('metadata between scans and data after the end are removed too', () {
    // A second scan (as in progressive JPEGs) with a comment and an XMP
    // segment before it, and a hidden note after the end marker.
    final body = testJpeg.sublist(0, testJpeg.length - 2);
    var sos = 2;
    while (!(testJpeg[sos] == 0xFF && testJpeg[sos + 1] == 0xDA)) {
      sos++;
    }
    final scan = testJpeg.sublist(sos, testJpeg.length - 2);
    final dirty = Uint8List.fromList([
      ...body,
      ...segment(0xFE, ascii.encode('between scans: Tel Aviv')),
      ...segment(0xE1, ascii.encode('http://ns.adobe.com/xap/1.0/ GPS')),
      ...scan,
      0xFF,
      0xD9,
      ...ascii.encode('trailing: Pixel 10 Pro'),
    ]);
    final clean = CleanPhoto.stripJpeg(dirty)!;
    expect(contains(clean, ascii.encode('Tel Aviv')), isFalse);
    expect(contains(clean, ascii.encode('ns.adobe.com')), isFalse);
    expect(contains(clean, ascii.encode('Pixel 10 Pro')), isFalse);
    expect(clean.sublist(clean.length - 2), [0xFF, 0xD9]);
    // Everything else is kept: both scans and the end marker.
    expect(clean.length, body.length + scan.length + 2);
  });

  test('a JPEG cut off in its picture data: null', () {
    expect(
      CleanPhoto.stripJpeg(testJpeg.sublist(0, testJpeg.length - 2)),
      isNull,
    );
  });

  test(
    'a photo that can\'t be cut clean is made again, never sent as is',
    () async {
      final turned = withSegments([exifSegment(orientation: 6)]);
      final fromTurned = (await ShareOut.cleanBytes(turned))!;
      expect(contains(fromTurned, ascii.encode('Pixel 10 Pro')), isFalse);
      expect(contains(fromTurned, ascii.encode('Exif')), isFalse);
      // Turned the right way up: 8x8 stays 8x8, but it is a new JPEG.
      expect(img.decodeJpg(fromTurned), isNotNull);

      final fromPng = (await ShareOut.cleanBytes(testPng))!;
      expect(CleanPhoto.isJpeg(fromPng), isTrue);

      expect(await ShareOut.cleanBytes(Uint8List.fromList([1, 2, 3])), isNull);
    },
  );
}
