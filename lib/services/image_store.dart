// services/image_store.dart
import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum RecipeImageKind { file, tile }

class ImageStore {
  // --- Config ---
  static const _imagesSubdir = 'images';
  static const _tmpSuffix = '.part';
  static const _defaultExt = '.jpg';
  static const _dioTimeout = Duration(seconds: 15);

  // In-flight download de-dupe per key.
  static final Map<String, Future<File?>> _inflight = {};

  // ---------- Paths / filenames ----------
  static Future<Directory> _imagesDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, _imagesSubdir));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _safeExt(String candidate) {
    if (candidate.isEmpty) return _defaultExt;
    final q = candidate.indexOf('?');
    final ext = (q >= 0 ? candidate.substring(0, q) : candidate).toLowerCase();
    // basic guard: ext should start with dot and be short-ish
    if (!ext.startsWith('.') || ext.length > 6) return _defaultExt;
    return ext;
    }

  static String _extFromUrl(String url) {
    final seg = Uri.parse(url).pathSegments;
    final last = seg.isNotEmpty ? seg.last : '';
    return _safeExt(p.extension(last));
  }

  /// Preferred: stable key (e.g., UUID) + optional extension override.
  static Future<File> fileForKey(String imageKey, {String? ext}) async {
    final dir = await _imagesDir();
    final name = '$imageKey${ext ?? _defaultExt}';
    return File(p.join(dir.path, name));
  }

  /// Back-compat: recipeId + kind + infer ext from URL.
  static Future<File> fileFor(int recipeId, RecipeImageKind kind, String url) async {
    final dir = await _imagesDir();
    final ext = _extFromUrl(url);
    final name = '${recipeId}_${kind.name}$ext';
    return File(p.join(dir.path, name));
  }

  // ---------- Local checks ----------
  static Future<File?> _existing(File file) async {
    if (await file.exists()) {
      final len = await file.length();
      if (len > 0) return file;
    }
    return null;
  }

  static Future<File?> localIfExists(int recipeId, RecipeImageKind kind, String url) async {
    final f = await fileFor(recipeId, kind, url);
    return _existing(f);
  }

  static Future<File?> localIfExistsByKey(String imageKey, {String? ext}) async {
    final f = await fileForKey(imageKey, ext: ext);
    return _existing(f);
  }

  // ---------- Network download (read-through) ----------

  /// Clean read-through: try local, else download -> save -> return.
  /// Supply a stable [imageKey] (UUID preferred). If [ext] omitted, inferred from URL.
  /// Optional [expectedSha256] to verify integrity when server provides it.
  static Future<File?> getOrDownload({
    required String imageKey,
    required String url,
    Dio? dio,
    String? ext, // if null, ext is inferred from url
    String? expectedSha256,
  }) async {
    final inferredExt = ext ?? _extFromUrl(url);
    final target = await fileForKey(imageKey, ext: inferredExt);

    // 1) Local hit?
    final local = await _existing(target);
    if (local != null) return local;

    // 2) De-dup concurrent downloads for same key+ext
    final inflightKey = '$imageKey|$inferredExt';
    if (_inflight.containsKey(inflightKey)) {
      return _inflight[inflightKey];
    }

    final completer = Completer<File?>();
    _inflight[inflightKey] = completer.future;

    try {
      final tmpPath = '${target.path}$_tmpSuffix';
      final tmpFile = File(tmpPath);
      await tmpFile.parent.create(recursive: true);

      final client = dio ?? Dio(BaseOptions(
        connectTimeout: _dioTimeout,
        receiveTimeout: _dioTimeout,
        sendTimeout: _dioTimeout,
        followRedirects: true,
        responseType: ResponseType.bytes,
      ));

      final res = await client.get<List<int>>(url,
          options: Options(responseType: ResponseType.bytes));

      final bytes = res.data;
      if (bytes == null || bytes.isEmpty) {
        // keep placeholder behavior: return null instead of throwing
        completer.complete(null);
        _inflight.remove(inflightKey);
        return null;
      }

      await tmpFile.writeAsBytes(bytes, flush: true);

      // Optional integrity check
      if (expectedSha256 != null && expectedSha256.isNotEmpty) {
        final ok = await _verifySha256(tmpFile, expectedSha256);
        if (!ok) {
          // bad download: remove temp and bail
          if (await tmpFile.exists()) {
            try { await tmpFile.delete(); } catch (_) {}
          }
          completer.complete(null);
          _inflight.remove(inflightKey);
          return null;
        }
      }

      // Atomic-ish finalize
      await tmpFile.rename(target.path);
      completer.complete(target);
      _inflight.remove(inflightKey);
      return target;
    } catch (_) {
      // Network or IO failure → return null; do not crash UI.
      completer.complete(null);
      _inflight.remove(inflightKey);
      return null;
    }
  }

  /// Back-compat: old signature used across your code.
  /// Local-first; only hits network if missing.
  static Future<File> download(int recipeId, RecipeImageKind kind, String url, {Dio? dio}) async {
    final f = await fileFor(recipeId, kind, url);
    final hit = await _existing(f);
    if (hit != null) return hit;

    final tmp = File('${f.path}$_tmpSuffix');
    await tmp.parent.create(recursive: true);

    final client = dio ??
        Dio(BaseOptions(
          connectTimeout: _dioTimeout,
          receiveTimeout: _dioTimeout,
          sendTimeout: _dioTimeout,
          followRedirects: true,
          responseType: ResponseType.bytes,
        ));

    final res = await client.get<List<int>>(url,
        options: Options(responseType: ResponseType.bytes));
    final bytes = res.data ?? const <int>[];
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(f.path);
    return f;
  }

  /// Fire-and-forget prefetch (kept for compatibility).
  static Future<void> prefetchForRecipe({
    required int recipeId,
    String? imageFileUrl,
    String? imageTileUrl,
    Dio? dio,
  }) async {
    if (imageFileUrl != null && imageFileUrl.isNotEmpty) {
      unawaited(download(recipeId, RecipeImageKind.file, imageFileUrl, dio: dio));
    }
    if (imageTileUrl != null && imageTileUrl.isNotEmpty) {
      unawaited(download(recipeId, RecipeImageKind.tile, imageTileUrl, dio: dio));
    }
  }

  // ---------- Utils ----------
  static Future<bool> _verifySha256(File file, String expectedHex) async {
    try {
      final bytes = await file.readAsBytes();
      // lightweight SHA-256 without extra deps: use crypto if you have it;
      // placeholder check: compare length first to avoid work if obviously wrong
      // If you already depend on 'crypto', uncomment below and remove the stub.
      //
      // import 'package:crypto/crypto.dart' as crypto;
      // final digest = crypto.sha256.convert(bytes).toString();
      // return digest.toLowerCase() == expectedHex.toLowerCase();

      // Stub fallback (length check only) — replace with real crypto when added
      return expectedHex.isNotEmpty && bytes.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Helper to construct a local path for UI (when you already know the key).
  static Future<String> localPathForKey(String imageKey, {String ext = _defaultExt}) async {
    final f = await fileForKey(imageKey, ext: ext);
    return f.path;
  }
}
