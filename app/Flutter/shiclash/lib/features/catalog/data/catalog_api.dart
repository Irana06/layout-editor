import 'dart:convert';
import 'dart:io';

import 'package:shiclash/core/config/app_config.dart';
import 'package:shiclash/features/catalog/data/catalog_models.dart';

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

class CatalogRepository {
  const CatalogRepository(this._api);

  final CatalogApi _api;

  Future<CatalogBootstrap> load() async {
    return CatalogBootstrap.fromJson(await _api.getBootstrap());
  }
}

class CatalogApiException implements Exception {
  const CatalogApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
