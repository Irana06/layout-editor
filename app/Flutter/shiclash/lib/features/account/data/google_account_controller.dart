import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shiclash/core/config/app_config.dart';

class AccountProfile {
  const AccountProfile({
    required this.name,
    required this.email,
    this.photoUrl,
    this.isAdmin = false,
  });

  final String name;
  final String email;
  final String? photoUrl;
  final bool isAdmin;

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'photo_url': photoUrl,
    'is_admin': isAdmin,
  };

  factory AccountProfile.fromJson(Map<String, dynamic> json) => AccountProfile(
    name: json['name']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    photoUrl: json['photo_url']?.toString(),
    isAdmin: json['is_admin'] == true || json['is_admin'] == 1,
  );
}

class GoogleAccountController extends ChangeNotifier {
  GoogleAccountController({
    this.enabled = true,
    FlutterSecureStorage? storage,
    HttpClient? client,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _client = client ?? HttpClient();

  static const _sessionKey = 'shiclash.mobile_session.v1';

  final bool enabled;
  final FlutterSecureStorage _storage;
  final HttpClient _client;
  final GoogleSignIn _google = GoogleSignIn.instance;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _events;
  GoogleSignInAccount? _googleAccount;
  AccountProfile? _profile;
  String? _sessionToken;
  bool _googleInitialized = false;
  bool _ready = false;
  bool _busy = false;
  bool _disposed = false;
  String? _error;

  GoogleSignInAccount? get account => _googleAccount;
  AccountProfile? get profile => _profile;
  bool get ready => _ready;
  bool get busy => _busy;
  bool get signedIn => _sessionToken != null;
  bool get isAdmin => _profile?.isAdmin ?? false;
  bool get configured => AppConfig.googleWebClientId.isNotEmpty;
  String? get error => _error;

  Future<String?> apiToken() async => _sessionToken;

  Future<void> initialize() async {
    if (!enabled || !configured) {
      _ready = true;
      _notify();
      return;
    }

    try {
      final saved = await _storage.read(key: _sessionKey);
      if (saved != null) {
        final decoded = jsonDecode(saved);
        if (decoded is Map<String, dynamic>) {
          final expiresAt = DateTime.tryParse(
            decoded['expires_at']?.toString() ?? '',
          );
          final token = decoded['token']?.toString();
          final profile = decoded['profile'];
          if (expiresAt != null &&
              expiresAt.isAfter(
                DateTime.now().add(const Duration(minutes: 1)),
              ) &&
              token != null &&
              token.startsWith('shiclash_') &&
              profile is Map<String, dynamic>) {
            _sessionToken = token;
            _profile = AccountProfile.fromJson(profile);
          } else {
            await _storage.delete(key: _sessionKey);
          }
        }
      }
    } catch (_) {
      await _storage.delete(key: _sessionKey);
    } finally {
      _ready = true;
      _notify();
    }
  }

  Future<void> _initializeGoogle() async {
    if (_googleInitialized) return;
    await _google.initialize(
      clientId: Platform.isIOS && AppConfig.googleIosClientId.isNotEmpty
          ? AppConfig.googleIosClientId
          : null,
      serverClientId: AppConfig.googleWebClientId,
    );
    _events = _google.authenticationEvents.listen(
      _onAuthentication,
      onError: (Object error) {
        _error = _friendlyError(error);
        _notify();
      },
    );
    _googleInitialized = true;
  }

  Future<void> signIn() async {
    if (!configured) {
      _error = 'Google OAuth belum dikonfigurasi untuk build ini.';
      _notify();
      return;
    }
    _busy = true;
    _error = null;
    _notify();
    try {
      await _initializeGoogle();
      final googleAccount = await _google.authenticate();
      final idToken = googleAccount.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const FormatException('Google tidak mengirim token identitas.');
      }
      final session = await _exchange(idToken);
      _googleAccount = googleAccount;
      _sessionToken = session.token;
      _profile = session.profile;
      await _storage.write(
        key: _sessionKey,
        value: jsonEncode({
          'token': session.token,
          'expires_at': session.expiresAt.toIso8601String(),
          'profile': session.profile.toJson(),
        }),
      );
    } catch (error) {
      _error = _friendlyError(error);
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<GoogleSignInAccount?> googleAccountForDrive() async {
    if (_googleAccount != null) return _googleAccount;
    _busy = true;
    _error = null;
    _notify();
    try {
      await _initializeGoogle();
      final lightweight = _google.attemptLightweightAuthentication();
      if (lightweight != null) _googleAccount = await lightweight;
      _googleAccount ??= await _google.authenticate();
      return _googleAccount;
    } catch (error) {
      _error = _friendlyError(error);
      return null;
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<_MobileSession> _exchange(String idToken) async {
    final request = await _client
        .postUrl(AppConfig.apiUri('auth/google'))
        .timeout(const Duration(seconds: 15));
    request.headers
      ..set(HttpHeaders.acceptHeader, 'application/json')
      ..set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
    final response = await request.close().timeout(const Duration(seconds: 20));
    final body = await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 20));
    final decoded = jsonDecode(body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map<String, dynamic>) {
      throw HttpException(
        decoded is Map
            ? decoded['message']?.toString() ?? 'Server menolak login.'
            : 'Server menolak login.',
      );
    }
    final token = decoded['token']?.toString();
    final expiresIn = (decoded['expires_in'] as num?)?.toInt();
    final data = decoded['data'];
    if (token == null || expiresIn == null || data is! Map<String, dynamic>) {
      throw const FormatException('Respons sesi Shiclash tidak lengkap.');
    }
    return _MobileSession(
      token: token,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      profile: AccountProfile.fromJson(data),
    );
  }

  Future<void> signOut() async {
    _busy = true;
    _error = null;
    _notify();
    try {
      if (_googleInitialized) await _google.signOut();
      await _storage.delete(key: _sessionKey);
      _googleAccount = null;
      _sessionToken = null;
      _profile = null;
    } catch (error) {
      _error = _friendlyError(error);
    } finally {
      _busy = false;
      _notify();
    }
  }

  void clearError() {
    _error = null;
    _notify();
  }

  void _onAuthentication(GoogleSignInAuthenticationEvent event) {
    if (event is GoogleSignInAuthenticationEventSignIn) {
      _googleAccount = event.user;
    } else if (event is GoogleSignInAuthenticationEventSignOut) {
      _googleAccount = null;
    }
    _notify();
  }

  String _friendlyError(Object error) {
    if (error is GoogleSignInException &&
        error.code == GoogleSignInExceptionCode.canceled) {
      return 'Login Google dibatalkan.';
    }
    if (error is TimeoutException || error is SocketException) {
      return 'Login gagal karena koneksi timeout. Coba lagi.';
    }
    if (error is HttpException) return error.message;
    return 'Login Google gagal. Periksa internet dan konfigurasi akun.';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _events?.cancel();
    _client.close();
    super.dispose();
  }
}

class _MobileSession {
  const _MobileSession({
    required this.token,
    required this.expiresAt,
    required this.profile,
  });

  final String token;
  final DateTime expiresAt;
  final AccountProfile profile;
}
