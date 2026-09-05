import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateInfo {
  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseUrl,
    required this.downloadUrl,
  });

  final String currentVersion;
  final String latestVersion;
  final Uri releaseUrl;
  final Uri? downloadUrl;

  bool get available => compareAppVersions(latestVersion, currentVersion) > 0;
}

class UpdateService {
  UpdateService({HttpClient? client}) : _client = client ?? HttpClient();

  static final Uri _latestRelease = Uri.parse(
    'https://api.github.com/repos/Irana06/layout-editor/releases/latest',
  );

  final HttpClient _client;

  Future<UpdateInfo> check() async {
    final package = await PackageInfo.fromPlatform();
    final request = await _client
        .getUrl(_latestRelease)
        .timeout(const Duration(seconds: 10));
    request.headers
      ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
      ..set(HttpHeaders.userAgentHeader, 'Shiclash/${package.version}');
    final response = await request.close().timeout(const Duration(seconds: 15));
    final body = await response.transform(utf8.decoder).join();

    if (response.statusCode == HttpStatus.notFound) {
      throw const UpdateException(
        'Belum ada GitHub Release yang dipublikasikan.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw UpdateException('GitHub merespons ${response.statusCode}.');
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    final tag = (json['tag_name'] as String? ?? '').replaceFirst(
      RegExp(r'^v'),
      '',
    );
    final releaseUrl = Uri.tryParse(json['html_url'] as String? ?? '');
    if (tag.isEmpty || releaseUrl == null) {
      throw const UpdateException(
        'Informasi versi GitHub Release tidak lengkap.',
      );
    }
    final apkAssets = (json['assets'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .where(
          (asset) =>
              (asset['name'] as String? ?? '').toLowerCase().endsWith('.apk'),
        )
        .toList();
    Map<String, dynamic>? selected;
    for (final asset in apkAssets) {
      if ((asset['name'] as String).toLowerCase().contains('arm64')) {
        selected = asset;
        break;
      }
    }
    if (selected == null && apkAssets.isNotEmpty) {
      selected = apkAssets.first;
    }

    return UpdateInfo(
      currentVersion: package.version,
      latestVersion: tag,
      releaseUrl: releaseUrl,
      downloadUrl: Uri.tryParse(
        selected?['browser_download_url'] as String? ?? '',
      ),
    );
  }

  Future<void> openDownload(UpdateInfo info) async {
    final target = info.downloadUrl ?? info.releaseUrl;
    if (!await launchUrl(target, mode: LaunchMode.externalApplication)) {
      throw const UpdateException('Halaman download tidak dapat dibuka.');
    }
  }
}

class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

int compareAppVersions(String left, String right) {
  List<int> parts(String value) => value
      .replaceFirst(RegExp(r'^v'), '')
      .split(RegExp(r'[-+]'))
      .first
      .split('.')
      .map((part) => int.tryParse(part) ?? 0)
      .toList();
  final a = parts(left);
  final b = parts(right);
  for (var index = 0; index < 3; index++) {
    final difference =
        (index < a.length ? a[index] : 0) - (index < b.length ? b[index] : 0);
    if (difference != 0) return difference;
  }
  return 0;
}
