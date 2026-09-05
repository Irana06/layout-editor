import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shiclash/core/config/app_config.dart';

class GoogleAccountController extends ChangeNotifier {
  GoogleAccountController({this.enabled = true});

  final bool enabled;
  final GoogleSignIn _google = GoogleSignIn.instance;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _events;
  GoogleSignInAccount? _account;
  bool _ready = false;
  bool _busy = false;
  bool _disposed = false;
  String? _error;

  GoogleSignInAccount? get account => _account;
  bool get ready => _ready;
  bool get busy => _busy;
  bool get signedIn => _account != null;
  bool get configured => AppConfig.googleWebClientId.isNotEmpty;
  String? get error => _error;

  Future<void> initialize() async {
    if (!enabled || !configured) {
      _ready = true;
      _notify();
      return;
    }
    try {
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
          _ready = true;
          _notify();
        },
      );
      await _google.attemptLightweightAuthentication();
    } catch (error) {
      _error = _friendlyError(error);
    } finally {
      _ready = true;
      _notify();
    }
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
      _account = await _google.authenticate();
    } catch (error) {
      _error = _friendlyError(error);
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> signOut() async {
    _busy = true;
    _error = null;
    _notify();
    try {
      await _google.signOut();
      _account = null;
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
      _account = event.user;
      _error = null;
    } else if (event is GoogleSignInAuthenticationEventSignOut) {
      _account = null;
    }
    _ready = true;
    _notify();
  }

  String _friendlyError(Object error) {
    if (error is GoogleSignInException &&
        error.code == GoogleSignInExceptionCode.canceled) {
      return 'Login Google dibatalkan.';
    }
    return 'Login Google gagal. Periksa internet dan konfigurasi akun.';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _events?.cancel();
    super.dispose();
  }
}
