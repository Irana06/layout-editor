import 'dart:convert';
import 'dart:io';

import 'package:shiclash/core/config/app_config.dart';

/// A layout snapshot living on the server under a short code.
class SharedLayout {
  const SharedLayout({
    required this.code,
    required this.title,
    required this.thLevel,
    required this.sceneryId,
    required this.data,
  });

  factory SharedLayout.fromJson(Map<String, dynamic> json) => SharedLayout(
    code: json['code'] as String,
    title: json['title'] as String? ?? 'Layout dibagikan',
    thLevel: (json['th_level'] as num).toInt(),
    sceneryId: (json['scenery_id'] as num).toInt(),
    data: (json['data'] as List? ?? const [])
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false),
  );

  final String code;
  final String title;
  final int thLevel;
  final int sceneryId;
  final List<Map<String, dynamic>> data;

  /// The payload shape the editor and the local store already speak.
  Map<String, dynamic> toLayout() => {
    'scenery_id': sceneryId,
    'th_level': thLevel,
    'data': data,
  };
}

/// Sharing copies a layout to the server; it never syncs afterwards. The device
/// keeps the original, and the link keeps whatever was sent at the time.
class ShareApi {
  ShareApi({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

  Future<({String code, String url})> share({
    required String title,
    required Map<String, dynamic> layout,
  }) async {
    final decoded = await _send(
      'POST',
      AppConfig.apiUri('layouts/share'),
      body: {
        'title': title,
        'th_level': layout['th_level'],
        'scenery_id': layout['scenery_id'],
        'data': layout['data'],
      },
    );
    final data = Map<String, dynamic>.from(decoded['data'] as Map);

    return (code: data['code'] as String, url: data['url'] as String);
  }

  Future<SharedLayout> fetch(String code) async {
    final decoded = await _send(
      'GET',
      AppConfig.apiUri('layouts/shared/$code'),
    );

    return SharedLayout.fromJson(
      Map<String, dynamic>.from(decoded['data'] as Map),
    );
  }

  Future<Map<String, dynamic>> _send(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
  }) async {
    final request = await _client
        .openUrl(method, uri)
        .timeout(const Duration(seconds: 12));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close().timeout(const Duration(seconds: 20));
    final text = await response.transform(utf8.decoder).join();

    if (response.statusCode == 404) {
      throw const ShareException(
        'Layout ini tidak ditemukan atau sudah ditarik.',
      );
    }
    if (response.statusCode == 422) {
      throw const ShareException(
        'Layout ini ditolak server karena tidak sesuai aturan Town Hall.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ShareException('Server merespons ${response.statusCode}.');
    }

    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw const ShareException('Format respons server tidak dikenali.');
    }

    return decoded;
  }

  void close() => _client.close(force: true);
}

class ShareException implements Exception {
  const ShareException(this.message);

  final String message;

  @override
  String toString() => message;
}
