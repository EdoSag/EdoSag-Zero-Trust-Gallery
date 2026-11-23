import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

/// The folder of a shared album's files in the `zt-attachments` bucket,
/// under each uploader's own id: `<uploader>/space_<32 hex>/<file>`. The
/// bucket lets every member of the space read there and only the uploader
/// write or delete (Core migration 20261122120000).
String spaceFolder(String spaceId) => 'space_${spaceId.replaceAll('-', '')}';

/// The encrypted files of shared albums. Each file has its own key, kept
/// only inside the photo's item, which is encrypted with the album's key.
abstract class SharedFiles {
  /// Encrypts [bytes] on this phone and uploads them into the album. Kept
  /// on the phone until the upload is done, so it never fails for lack of
  /// network (the upload is retried by [flush]).
  Future<ZtAttachmentRef> put(String spaceId, Uint8List bytes, {String? mime});

  /// Retries this account's waiting uploads into [spaceId].
  Future<void> flush(String spaceId);

  /// The decrypted file that [owner] added.
  Future<Uint8List> read(String spaceId, String owner, ZtAttachmentRef ref);

  /// Deletes this account's own files from the album.
  Future<void> delete(String spaceId, Iterable<ZtAttachmentRef> refs);

  /// After this account left the album, or it was deleted: removes every
  /// file this account had uploaded there, and this phone's copies.
  Future<void> sweep(String spaceId);
}

/// Opens the phone's store of sealed files for one album.
typedef SharedFileCacheOpener =
    Future<AttachmentCache> Function(String spaceId, String userId);

/// Lists the files in one storage folder (names only).
typedef StorageFolderLister = Future<List<String>> Function(String folder);

/// [SharedFiles] on the core's attachments: ZtAttachments with the album's
/// folder as its "app", so the path is `<uploader>/space_<hex>/<id>`.
class CoreSharedFiles implements SharedFiles {
  CoreSharedFiles({
    required this.userId,
    required AttachmentBackend backend,
    SharedFileCacheOpener? openCache,
    Future<void> Function(String spaceId, String userId)? deleteCache,
    StorageFolderLister? list,
  }) : _backend = backend,
       _openCache = openCache ?? _fileCache,
       _deleteCache = deleteCache ?? _deleteFileCache,
       _list = list ?? _supabaseList;

  final String userId;
  final AttachmentBackend _backend;
  final SharedFileCacheOpener _openCache;
  final Future<void> Function(String spaceId, String userId) _deleteCache;
  final StorageFolderLister _list;
  final Map<String, Future<AttachmentCache>> _caches = {};
  final Map<String, ZtAttachments> _byOwner = {};

  static String _cacheApp(String spaceId) => 'gallery_${spaceFolder(spaceId)}';

  static Future<AttachmentCache> _fileCache(String spaceId, String userId) =>
      FileAttachmentCache.forAccount(appId: _cacheApp(spaceId), userId: userId);

  static Future<void> _deleteFileCache(String spaceId, String userId) =>
      FileAttachmentCache.deleteFor(appId: _cacheApp(spaceId), userId: userId);

  static Future<List<String>> _supabaseList(String folder) async => [
    for (final f
        in await Supabase.instance.client.storage
            .from(SupabaseAttachmentBackend.bucket)
            .list(
              path: folder,
              searchOptions: const SearchOptions(limit: 1000),
            ))
      f.name,
  ];

  Future<ZtAttachments> _files(String spaceId, String owner) async {
    final cache = await (_caches[spaceId] ??= _openCache(spaceId, userId));
    return _byOwner['$spaceId/$owner'] ??= ZtAttachments(
      appId: spaceFolder(spaceId),
      userId: owner,
      backend: _backend,
      cache: cache,
    );
  }

  @override
  Future<ZtAttachmentRef> put(
    String spaceId,
    Uint8List bytes, {
    String? mime,
  }) async => (await _files(spaceId, userId)).put(bytes, mimeType: mime);

  @override
  Future<void> flush(String spaceId) async =>
      (await _files(spaceId, userId)).flush();

  @override
  Future<Uint8List> read(
    String spaceId,
    String owner,
    ZtAttachmentRef ref,
  ) async => (await _files(spaceId, owner)).read(ref);

  @override
  Future<void> delete(String spaceId, Iterable<ZtAttachmentRef> refs) async =>
      (await _files(spaceId, userId)).deleteAll(refs);

  @override
  Future<void> sweep(String spaceId) async {
    final folder = '$userId/${spaceFolder(spaceId)}';
    final names = await _list(folder);
    if (names.isNotEmpty) {
      await _backend.remove([for (final n in names) '$folder/$n']);
    }
    _caches.remove(spaceId);
    _byOwner.removeWhere((k, _) => k.startsWith('$spaceId/'));
    try {
      await _deleteCache(spaceId, userId);
    } on Object {
      // Nothing kept on this phone.
    }
  }
}

/// The shared albums' files for whoever is signed in and unlocked.
final sharedFilesProvider = Provider<SharedFiles>((ref) {
  ref.watch(vaultControllerProvider.select((s) => s is VaultUnlocked));
  final userId = ref.watch(accountServiceProvider).currentUserId;
  if (userId == null) throw StateError('Not signed in');
  return CoreSharedFiles(
    userId: userId,
    backend: ref.watch(ztAttachmentBackendProvider),
  );
});

/// A photo's whole file: its parts read and joined in order.
Future<Uint8List> readWhole(
  SharedFiles files,
  String spaceId,
  String owner,
  List<ZtAttachmentRef> parts,
) async {
  if (parts.length == 1) return files.read(spaceId, owner, parts.single);
  final out = BytesBuilder(copy: false);
  for (final p in parts) {
    out.add(await files.read(spaceId, owner, p));
  }
  return out.takeBytes();
}
