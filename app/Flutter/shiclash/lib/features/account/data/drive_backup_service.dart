import 'dart:convert';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;

class DriveBackupInfo {
  const DriveBackupInfo({required this.fileId, this.modifiedAt});

  final String fileId;
  final DateTime? modifiedAt;
}

class DriveBackupService {
  static const String fileName = 'shiclash-backup-v1.json';
  static const List<String> scopes = <String>[drive.DriveApi.driveAppdataScope];

  Future<DriveBackupInfo> upload(
    GoogleSignInAccount account,
    String content,
  ) async {
    final client = await _client(account, interactive: true);
    try {
      final api = drive.DriveApi(client);
      final existing = await _find(api);
      final bytes = utf8.encode(content);
      final media = drive.Media(
        Stream<List<int>>.value(bytes),
        bytes.length,
        contentType: 'application/json',
      );
      final metadata = drive.File()..name = fileName;
      final file = existing == null
          ? await api.files.create(
              metadata..parents = <String>['appDataFolder'],
              uploadMedia: media,
            )
          : await api.files.update(
              metadata,
              existing.fileId,
              uploadMedia: media,
            );
      return DriveBackupInfo(
        fileId: file.id ?? existing?.fileId ?? '',
        modifiedAt: file.modifiedTime,
      );
    } finally {
      client.close();
    }
  }

  Future<String?> download(GoogleSignInAccount account) async {
    final client = await _client(account, interactive: true);
    try {
      final api = drive.DriveApi(client);
      final existing = await _find(api);
      if (existing == null) return null;
      final response = await api.files.get(
        existing.fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );
      if (response is! drive.Media) {
        throw const FormatException('Isi backup Google Drive tidak valid');
      }
      return await response.stream.transform(utf8.decoder).join();
    } finally {
      client.close();
    }
  }

  Future<DriveBackupInfo?> latest(GoogleSignInAccount account) async {
    final client = await _client(account, interactive: false);
    try {
      return await _find(drive.DriveApi(client));
    } finally {
      client.close();
    }
  }

  Future<auth.AuthClient> _client(
    GoogleSignInAccount account, {
    required bool interactive,
  }) async {
    var authorization = await account.authorizationClient
        .authorizationForScopes(scopes);
    if (authorization == null && interactive) {
      authorization = await account.authorizationClient.authorizeScopes(scopes);
    }
    if (authorization == null) {
      throw StateError('Izin backup Google Drive belum diberikan.');
    }
    return authorization.authClient(scopes: scopes);
  }

  Future<DriveBackupInfo?> _find(drive.DriveApi api) async {
    final files = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$fileName' and trashed = false",
      orderBy: 'modifiedTime desc',
      pageSize: 1,
    );
    final matches = files.files;
    final file = matches == null || matches.isEmpty ? null : matches.first;
    final id = file?.id;
    if (id == null) return null;
    return DriveBackupInfo(fileId: id, modifiedAt: file?.modifiedTime);
  }
}
