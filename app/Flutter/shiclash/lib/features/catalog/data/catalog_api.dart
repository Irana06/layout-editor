import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:shiclash/core/config/app_config.dart';
import 'package:shiclash/features/catalog/data/catalog_models.dart';
import 'package:shiclash/features/catalog/data/offline_store.dart';

class CatalogApi {
  CatalogApi({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

  Future<Map<String, dynamic>> getBootstrap() async {
    final request = await _client
        .getUrl(AppConfig.apiUri('bootstrap'))
        .timeout(const Duration(seconds: 12));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 20));
    final body = await response.transform(utf8.decoder).join();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CatalogApiException(
        'Laravel API merespons ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const CatalogApiException('Format respons API tidak dikenali.');
    }

    return decoded;
  }
}

class CatalogRepository extends ChangeNotifier {
  CatalogRepository(this._api, {this.offline});

  final CatalogApi _api;

  /// Optional: when present the catalogue is kept on the device, so losing
  /// signal costs the latest data rather than the whole app.
  final OfflineStore? offline;

  bool _refreshing = false;

  void invalidate() => notifyListeners();

  /// A stored catalogue is served immediately and refreshed behind the screen.
  ///
  /// Asking the network first meant every screen waited for the request to fail
  /// before reading a copy that was already on the device — several seconds of
  /// nothing, on exactly the connection where the cache was supposed to help.
  Future<CatalogBootstrap> load() async {
    final cached = await offline?.cachedCatalog();
    if (cached != null) {
      unawaited(_refreshInBackground(cached));

      return CatalogBootstrap.fromJson(cached, fromCache: true);
    }

    final payload = await _api.getBootstrap();
    await offline?.rememberCatalog(payload);

    return CatalogBootstrap.fromJson(payload);
  }

  /// Fetch a newer catalogue without making anyone wait for it. Listeners are
  /// only told when the version actually moved: notifying on every refresh
  /// would reload the screen, which would call load() again, forever.
  Future<void> _refreshInBackground(Map<String, dynamic> cached) async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final payload = await _api.getBootstrap();
      final before = _versionOf(cached);
      final after = _versionOf(payload);
      await offline?.rememberCatalog(payload);
      if (after.isNotEmpty && after != before) notifyListeners();
    } catch (_) {
      // Offline is the expected case here, and the screen already has data.
    } finally {
      _refreshing = false;
    }
  }

  String _versionOf(Map<String, dynamic> payload) {
    final meta = payload['meta'];

    return meta is Map ? meta['catalog_version'] as String? ?? '' : '';
  }
}

class CatalogApiException implements Exception {
  const CatalogApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
