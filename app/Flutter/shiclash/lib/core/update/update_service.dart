import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseUrl,
    required this.downloadUrl,
    required this.expectedSha256,
    required this.downloadSize,
  });

  final String currentVersion;
  final String latestVersion;
  final Uri releaseUrl;
  final Uri? downloadUrl;
  final String? expectedSha256;
  final int? downloadSize;

  bool get available => compareAppVersions(latestVersion, currentVersion) > 0;
}

class UpdateService {
  UpdateService({HttpClient? client, MethodChannel? installer})
    : _client = client ?? HttpClient(),
      _installer = installer ?? const MethodChannel('shiclash/app_installer');

  static final Uri _latestRelease = Uri.parse(
    'https://api.github.com/repos/Irana06/layout-editor/releases/latest',
  );

  final HttpClient _client;
  final MethodChannel _installer;

  bool get directInstallSupported => Platform.isAndroid;

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
      expectedSha256: parseReleaseSha256(selected?['digest'] as String?),
      downloadSize: selected?['size'] as int?,
    );
  }

  Future<void> downloadAndInstall(
    UpdateInfo info, {
    void Function(UpdateProgress progress)? onProgress,
  }) async {
    if (!directInstallSupported) {
      throw const UpdateException(
        'Pemasangan langsung saat ini hanya tersedia di Android.',
      );
    }
    final downloadUrl = info.downloadUrl;
    final expectedSha256 = info.expectedSha256;
    if (downloadUrl == null ||
        downloadUrl.scheme != 'https' ||
        downloadUrl.host != 'github.com') {
      throw const UpdateException('File APK resmi tidak ditemukan di release.');
    }
    if (expectedSha256 == null) {
      throw const UpdateException(
        'Checksum APK belum tersedia. Coba periksa update beberapa saat lagi.',
      );
    }
    if ((info.downloadSize ?? 0) > _maximumApkBytes) {
      throw const UpdateException(
        'Ukuran APK melewati batas keamanan aplikasi.',
      );
    }

    final directory = await getTemporaryDirectory();
    final safeVersion = info.latestVersion.replaceAll(
      RegExp(r'[^0-9A-Za-z._-]'),
      '_',
    );
    final apk = File('${directory.path}/shiclash-update-$safeVersion.apk');
    final partial = File('${apk.path}.part');

    if (await apk.exists()) {
      onProgress?.call(
        UpdateProgress.verifying(await apk.length(), info.downloadSize),
      );
      if (await _matchesSha256(apk, expectedSha256)) {
        await _openInstaller(apk.path);
        return;
      }
      await apk.delete();
    }

    try {
      if (await partial.exists()) await partial.delete();
      final request = await _client
          .getUrl(downloadUrl)
          .timeout(const Duration(seconds: 15));
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/octet-stream')
        ..set(HttpHeaders.userAgentHeader, 'Shiclash/${info.currentVersion}');
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw UpdateException(
          'Download APK gagal (HTTP ${response.statusCode}).',
        );
      }
      final total = response.contentLength > 0
          ? response.contentLength
          : info.downloadSize;
      if ((total ?? 0) > _maximumApkBytes) {
        throw const UpdateException(
          'Ukuran APK melewati batas keamanan aplikasi.',
        );
      }

      var received = 0;
      final output = partial.openWrite();
      try {
        await for (final chunk in response) {
          received += chunk.length;
          if (received > _maximumApkBytes) {
            throw const UpdateException(
              'Ukuran APK melewati batas keamanan aplikasi.',
            );
          }
          output.add(chunk);
          onProgress?.call(UpdateProgress.downloading(received, total));
        }
      } finally {
        await output.close();
      }
      if (info.downloadSize != null && received != info.downloadSize) {
        throw const UpdateException('Download APK tidak lengkap. Coba lagi.');
      }

      onProgress?.call(UpdateProgress.verifying(received, total));
      if (!await _matchesSha256(partial, expectedSha256)) {
        throw const UpdateException(
          'Verifikasi APK gagal. File tidak akan dipasang.',
        );
      }
      await partial.rename(apk.path);
      onProgress?.call(UpdateProgress.installing(received, total));
      await _openInstaller(apk.path);
    } finally {
      if (await partial.exists()) await partial.delete();
    }
  }

  Future<bool> _matchesSha256(File file, String expected) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString().toLowerCase() == expected.toLowerCase();
  }

  Future<void> _openInstaller(String path) async {
    final result = await _installer.invokeMapMethod<String, dynamic>(
      'installApk',
      <String, dynamic>{'path': path},
    );
    switch (result?['status']) {
      case 'opened':
        return;
      case 'permission_required':
        throw const UpdatePermissionException();
      default:
        throw UpdateException(
          result?['message'] as String? ??
              'Installer Android tidak dapat dibuka.',
        );
    }
  }
}

const int _maximumApkBytes = 250 * 1024 * 1024;

String? parseReleaseSha256(String? value) {
  if (value == null) return null;
  final match = RegExp(r'^sha256:([0-9a-fA-F]{64})$').firstMatch(value.trim());
  return match?.group(1)?.toLowerCase();
}

enum UpdatePhase { downloading, verifying, installing }

class UpdateProgress {
  const UpdateProgress(this.phase, this.receivedBytes, this.totalBytes);

  factory UpdateProgress.downloading(int received, int? total) =>
      UpdateProgress(UpdatePhase.downloading, received, total);
  factory UpdateProgress.verifying(int received, int? total) =>
      UpdateProgress(UpdatePhase.verifying, received, total);
  factory UpdateProgress.installing(int received, int? total) =>
      UpdateProgress(UpdatePhase.installing, received, total);

  final UpdatePhase phase;
  final int receivedBytes;
  final int? totalBytes;

  double? get fraction => totalBytes == null || totalBytes! <= 0
      ? null
      : (receivedBytes / totalBytes!).clamp(0, 1);
}

class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UpdatePermissionException extends UpdateException {
  const UpdatePermissionException()
    : super(
        'Aktifkan “Izinkan dari sumber ini”, lalu kembali ke Shiclash. Instalasi akan dilanjutkan otomatis.',
      );
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
