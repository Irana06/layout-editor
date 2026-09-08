import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

/// Progress of a full asset download, so the UI can report it honestly rather
/// than spinning with no idea how long is left.
class OfflineProgress {
  const OfflineProgress({
    required this.done,
    required this.total,
    required this.failed,
  });

  final int done;
  final int total;
  final int failed;

  double get fraction => total == 0 ? 0 : done / total;
  bool get finished => total > 0 && done >= total;
}

/// Keeps the catalogue and its images on the device.
///
/// Two separate concerns live here on purpose. The catalogue JSON is small and
/// is saved on every successful load without being asked — losing signal should
/// never make the app unopenable. The images are large, so they are only
/// fetched when the user asks for them.
class OfflineStore extends ChangeNotifier {
  OfflineStore({
    Future<Directory> Function()? directory,
    HttpClient Function()? clientFactory,
  }) : _directory = directory ?? getApplicationSupportDirectory,
       _clientFactory = clientFactory ?? HttpClient.new;

  final Future<Directory> Function() _directory;
  final HttpClient Function() _clientFactory;

  /// Resolving an image has to be synchronous — a widget cannot wait to decide
  /// whether to read a file or the network — so the store is reachable from
  /// [OfflineImage] without threading it through every screen.
  static OfflineStore instance = OfflineStore();

  Directory? _root;
  bool _downloading = false;
  bool _cancelled = false;

  /// Names of the files on disk, so [imageProvider] can answer immediately.
  Set<String> _stored = const {};
  OfflineProgress? progress;
  String? error;

  bool get downloading => _downloading;

  /// Version of the catalogue whose images are stored, or null when nothing has
  /// been downloaded. Compared against the live catalogue to offer an update.
  String? storedVersion;

  Future<Directory> _dir() async {
    final root = _root ??= Directory('${(await _directory()).path}/offline');
    if (!await root.exists()) await root.create(recursive: true);

    return root;
  }

  File _catalogFile(Directory root) => File('${root.path}/catalog.json');

  File _stampFile(Directory root) => File('${root.path}/assets-version.txt');

  /// Local name for a remote asset. The URL path is kept so two files with the
  /// same basename in different folders cannot collide.
  String _keyFor(String url) {
    final path = Uri.parse(url).path;

    return path.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }

  Future<void> load() async {
    try {
      final root = await _dir();
      final stamp = _stampFile(root);
      storedVersion = await stamp.exists()
          ? (await stamp.readAsString()).trim()
          : null;
      await _indexStoredFiles();
    } catch (_) {
      storedVersion = null;
      _stored = const {};
    }
    notifyListeners();
  }

  Future<void> _indexStoredFiles() async {
    final root = await _dir();
    final names = <String>{};
    await for (final entity in root.list()) {
      if (entity is File) names.add(entity.uri.pathSegments.last);
    }
    _stored = names;
  }

  /// Where this image should come from. A downloaded file wins, so the editor
  /// keeps drawing with no connection; anything not stored still falls back to
  /// the network, which is what makes a partial download useful rather than
  /// all-or-nothing.
  ImageProvider imageProvider(String url) {
    final key = _keyFor(url);
    final root = _root;
    if (root != null && _stored.contains(key)) {
      return FileImage(File('${root.path}/$key'));
    }

    return NetworkImage(url);
  }

  /// Remember the last catalogue that loaded, so the next cold start works
  /// without a connection.
  Future<void> rememberCatalog(Map<String, dynamic> payload) async {
    try {
      final root = await _dir();
      final temp = File('${_catalogFile(root).path}.tmp');
      await temp.writeAsString(jsonEncode(payload), flush: true);
      await temp.rename(_catalogFile(root).path);
    } catch (_) {
      // A failed cache write must never break a load that already succeeded.
    }
  }

  Future<Map<String, dynamic>?> cachedCatalog() async {
    try {
      final file = _catalogFile(await _dir());
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());

      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Local file for [url] if it has been downloaded, otherwise null.
  Future<File?> imageFor(String url) async {
    if (url.isEmpty) return null;
    try {
      final file = File('${(await _dir()).path}/${_keyFor(url)}');

      return await file.exists() ? file : null;
    } catch (_) {
      return null;
    }
  }

  Future<int> storedBytes() async {
    try {
      final root = await _dir();
      var total = 0;
      await for (final entity in root.list()) {
        if (entity is File) total += await entity.length();
      }

      return total;
    } catch (_) {
      return 0;
    }
  }

  void cancel() {
    _cancelled = true;
    notifyListeners();
  }

  /// Fetch every image the catalogue refers to. Already-present files are
  /// skipped, so an interrupted download resumes rather than starting over.
  Future<void> downloadAll({
    required List<String> urls,
    required String version,
  }) async {
    if (_downloading) return;
    _downloading = true;
    _cancelled = false;
    error = null;
    progress = OfflineProgress(done: 0, total: urls.length, failed: 0);
    notifyListeners();

    final client = _clientFactory();
    var done = 0;
    var failed = 0;
    try {
      final root = await _dir();
      for (final url in urls) {
        if (_cancelled) break;
        final target = File('${root.path}/${_keyFor(url)}');
        if (!await target.exists()) {
          try {
            final request = await client
                .getUrl(Uri.parse(url))
                .timeout(const Duration(seconds: 20));
            final response = await request.close().timeout(
              const Duration(seconds: 60),
            );
            if (response.statusCode == 200) {
              // Written beside the target then renamed, so a dropped connection
              // cannot leave a half-image that later looks downloaded.
              final temp = File('${target.path}.part');
              await response.pipe(temp.openWrite());
              await temp.rename(target.path);
            } else {
              failed++;
            }
          } catch (_) {
            failed++;
          }
        }
        done++;
        progress = OfflineProgress(
          done: done,
          total: urls.length,
          failed: failed,
        );
        notifyListeners();
      }

      // The version is only stamped on a complete run; a partial set must not
      // claim to be up to date.
      await _indexStoredFiles();
      if (!_cancelled && failed == 0) {
        storedVersion = version;
        await _stampFile(root).writeAsString(version, flush: true);
      } else if (failed > 0) {
        error = '$failed berkas gagal diunduh. Coba lagi untuk melengkapinya.';
      }
    } catch (caught) {
      error = 'Unduhan gagal: $caught';
    } finally {
      client.close(force: true);
      _downloading = false;
      notifyListeners();
    }
  }

  Future<void> clear() async {
    try {
      final root = await _dir();
      if (await root.exists()) await root.delete(recursive: true);
      _root = null;
      storedVersion = null;
      progress = null;
      error = null;
    } catch (caught) {
      error = 'Gagal menghapus data offline: $caught';
    }
    notifyListeners();
  }
}
