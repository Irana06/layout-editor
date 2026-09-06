import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shiclash/core/config/app_config.dart';
import 'package:shiclash/features/catalog/data/catalog_models.dart';

class CalibrationApi {
  CalibrationApi({required this.idToken, HttpClient? client})
    : _client = client ?? HttpClient();

  final Future<String?> Function() idToken;
  final HttpClient _client;

  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = await idToken();
    if (token == null) {
      throw const CalibrationException('Login Google diperlukan.', 401);
    }
    try {
      final uri = AppConfig.apiUri(path);
      if (uri.scheme != 'https' &&
          uri.host != 'localhost' &&
          uri.host != '10.0.2.2') {
        throw const CalibrationException(
          'Koneksi admin harus menggunakan HTTPS.',
          0,
        );
      }
      final request = await _client
          .openUrl(body == null ? 'GET' : 'PATCH', uri)
          .timeout(const Duration(seconds: 15));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final text = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 20));
      final Object? decoded;
      try {
        decoded = jsonDecode(text);
      } catch (_) {
        throw CalibrationException(
          'Server mengirim respons yang tidak dikenali (${response.statusCode}).',
          response.statusCode,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = switch (response.statusCode) {
          401 => 'Sesi Shiclash berakhir. Login kembali untuk melanjutkan; perubahanmu tetap ada.',
          403 => 'Akun ini belum memiliki akses admin.',
          404 => 'Calibrator belum tersedia di server atau data sudah dihapus. Muat ulang.',
          429 => 'Terlalu banyak permintaan. Tunggu sebentar lalu coba lagi.',
          _ =>
            decoded is Map
                ? decoded['message']?.toString() ?? 'Gagal menyimpan.'
                : 'Server belum tersedia.',
        };
        throw CalibrationException(message, response.statusCode);
      }
      if (decoded is! Map<String, dynamic>) {
        throw const CalibrationException('Format data tidak dikenali.', 0);
      }
      return decoded;
    } on TimeoutException {
      throw const CalibrationException(
        'Koneksi timeout. Perubahan belum dibuang; periksa server sebelum mencoba lagi.',
        0,
      );
    } on SocketException {
      throw const CalibrationException(
        'Tidak dapat terhubung. Periksa internet lalu coba lagi.',
        0,
      );
    }
  }

  Future<bool> isAdmin() async =>
      (await request('auth/me'))['data']['is_admin'] == true;
  Future<CatalogBootstrap> load() async =>
      CatalogBootstrap.fromJson(await request('admin/calibration'));

  Future<List<BuildingUnlockRule>> saveUnlockRules(
    int townHallLevel,
    List<Map<String, dynamic>> rules,
  ) async {
    final result = await request(
      'admin/unlock-rules',
      body: {'th_level': townHallLevel, 'rules': rules},
    );
    return (result['unlockRules'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(BuildingUnlockRule.fromJson)
        .toList(growable: false);
  }

  void close() => _client.close();
}

class CalibrationException implements Exception {
  const CalibrationException(this.message, this.status);
  final String message;
  final int status;
  @override
  String toString() => message;
}
