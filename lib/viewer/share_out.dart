import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/l10n.dart';
import '../phone/phone_library.dart';
import 'clean_photo.dart';

/// Hands files to the phone's share sheet. Tests replace it.
final shareFilesProvider = Provider<Future<void> Function(List<String> paths)>(
  (ref) =>
      (paths) => SharePlus.instance.share(
        ShareParams(files: [for (final p in paths) XFile(p)]),
      ),
);

/// Where cleaned copies wait for the app they were shared to. Tests replace
/// it.
final outgoingDirProvider = Provider<Future<Directory> Function()>(
  (ref) =>
      () async =>
          Directory('${(await getTemporaryDirectory()).path}/outgoing_share'),
);

/// Shares photos and videos so that what leaves the phone says nothing
/// about where, when or on which phone a photo was taken.
class ShareOut {
  ShareOut(this.ref);

  final WidgetRef ref;

  /// Removes copies made for an earlier share (the receiving app has had
  /// them by now). Called before every share and when the app comes back.
  static Future<void> clear(Directory dir) async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } on FileSystemException {
      // In use or already gone: tried again next time.
    }
  }

  /// A photo's bytes without hidden details: the same JPEG with them cut
  /// out, or, for other formats and turned JPEGs, a new JPEG [reencode]
  /// makes. Null when neither works.
  static Future<Uint8List?> cleanPhoto(
    Uint8List? original,
    Future<Uint8List?> Function() reencode,
  ) async {
    if (original != null) {
      final stripped = CleanPhoto.stripJpeg(original);
      if (stripped != null) return stripped;
    }
    final fresh = await reencode();
    if (fresh == null) return null;
    // A re-made JPEG has nothing hidden, but strip anyway in case the
    // system kept something.
    return CleanPhoto.stripJpeg(fresh) ?? fresh;
  }

  /// Shares phone photos and videos. Photos go as clean copies; videos keep
  /// what the camera put in them, so the person is asked first.
  Future<void> phone(BuildContext context, List<PhoneMedia> items) async {
    final library = ref.read(phoneLibraryProvider);
    final hasVideo = items.any((m) => m.isVideo);
    if (hasVideo && !await _videoWarning(context)) return;
    final dir = await ref.read(outgoingDirProvider)();
    await clear(dir);
    await dir.create(recursive: true);
    final paths = <String>[];
    var n = 0;
    for (final m in items) {
      n++;
      if (m.isVideo) {
        final f = await library.file(m);
        if (f != null) paths.add(f.path);
        continue;
      }
      final clean = await cleanPhoto(
        await library.bytes(m),
        () => library.plainJpeg(m),
      );
      if (clean == null) continue;
      final f = File('${dir.path}/photo_$n.jpg');
      await f.writeAsBytes(clean, flush: true);
      paths.add(f.path);
    }
    if (paths.isEmpty) {
      if (context.mounted) _snack(context, context.l10n.shareFailed);
      return;
    }
    await ref.read(shareFilesProvider)(paths);
  }

  /// Shares one photo already in memory (from the account), cleaned.
  Future<void> photoBytes(BuildContext context, Uint8List bytes) async {
    final dir = await ref.read(outgoingDirProvider)();
    await clear(dir);
    await dir.create(recursive: true);
    final clean = CleanPhoto.stripJpeg(bytes) ?? bytes;
    final f = File('${dir.path}/photo.jpg');
    await f.writeAsBytes(clean, flush: true);
    await ref.read(shareFilesProvider)([f.path]);
  }

  /// Shares a video file as it is.
  Future<void> videoFile(BuildContext context, File file) async {
    if (!await _videoWarning(context)) return;
    await ref.read(shareFilesProvider)([file.path]);
  }

  static Future<bool> _videoWarning(BuildContext context) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.shareVideoTitle),
        content: Text(l.shareVideoBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            key: const Key('shareVideoAnyway'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.shareAnyway),
          ),
        ],
      ),
    );
    return ok == true;
  }

  static void _snack(BuildContext context, String text) =>
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(text), duration: const Duration(seconds: 4)),
        );
}
