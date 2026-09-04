import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/auth_interceptor.dart';
import '../../../core/services/server_connection_checker.dart';
import '../models/login_request.dart';
import '../models/auth_config.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_zh.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading, error }

enum AuthMessageCode {
  serverUnavailable,
  loginInvalidCredentials,
  loginEndpointMissing,
  serverError,
  loginNetworkError,
  loginGenericError,
  registerFailedDetail,
  registerInvalid,
  registerEndpointMissing,
  registerServerError,
  registerNetworkError,
  registerGenericError,
}

class AuthMessage {
  final AuthMessageCode code;

  /// Server-provided text. It is displayed verbatim and never translated.
  final String? detail;

  const AuthMessage(this.code, {this.detail});

  String localized(AppLocalizations l10n) {
    switch (code) {
      case AuthMessageCode.serverUnavailable:
        return l10n.authServerUnavailable;
      case AuthMessageCode.loginInvalidCredentials:
        return l10n.authLoginInvalidCredentials;
      case AuthMessageCode.loginEndpointMissing:
        return l10n.authLoginEndpointMissing;
      case AuthMessageCode.serverError:
        return l10n.authServerError;
      case AuthMessageCode.loginNetworkError:
        return l10n.authLoginNetworkError;
      case AuthMessageCode.loginGenericError:
        return l10n.authLoginGenericError;
      case AuthMessageCode.registerFailedDetail:
        return l10n.authRegisterFailedDetail(detail ?? '');
      case AuthMessageCode.registerInvalid:
        return l10n.authRegisterInvalid;
      case AuthMessageCode.registerEndpointMissing:
        return l10n.authRegisterEndpointMissing;
      case AuthMessageCode.registerServerError:
        return l10n.authRegisterServerError;
      case AuthMessageCode.registerNetworkError:
        return l10n.authRegisterNetworkError;
      case AuthMessageCode.registerGenericError:
        return l10n.authRegisterGenericError;
    }
  }
}

class AuthState {
  final AuthStatus status;
  final User? user;
  final AuthMessage? message;
  // Set when the server could not be reached, so routing sends the user back
  // to server setup to start over (without wiping the saved address).
  final bool serverUnreachable;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.message,
    this.serverUnreachable = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    AuthMessage? message,
    bool? serverUnreachable,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      message: message ?? this.message,
      serverUnreachable: serverUnreachable ?? this.serverUnreachable,
    );
  }
}

extension AuthStateMessageText on AuthState {
  /// Compatibility accessor for callers outside the localized widgets.
  String? get errorMessage => message?.localized(AppLocalizationsZh());
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final Future<bool> Function() _checkConnection;

  AuthNotifier(
    this._repository, {
    Future<bool> Function()? checkConnection,
  })  : _checkConnection = checkConnection ?? ServerConnectionChecker.verify,
        super(const AuthState());

  /// Runs on startup. When a server is configured it first verifies the
  /// server is reachable, then restores the session via the saved token, or
  /// signs back in automatically using the remembered credentials.
  Future<void> checkAuth() async {
    // Only probe connectivity when a server is actually configured; otherwise
    // the user simply hasn't set one up yet.
    if (ApiClient.instance.baseUrl.isNotEmpty && !await _checkConnection()) {
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        serverUnreachable: true,
        message: AuthMessage(AuthMessageCode.serverUnavailable),
      );
      return;
    }

    final token = await AuthInterceptor.accessToken;
    if (token != null) {
      state = const AuthState(status: AuthStatus.loading);
      try {
        final user = await _repository.getCurrentUser();
        state = AuthState(status: AuthStatus.authenticated, user: user);
        return;
      } catch (_) {
        // Token invalid/expired: drop it and fall through to credential login.
        await AuthInterceptor.clearTokens();
      }
    }

    // No valid token: try to sign back in with the remembered credentials.
    final creds = await AuthInterceptor.savedCredentials;
    if (creds != null) {
      state = const AuthState(status: AuthStatus.loading);
      try {
        await _authenticate(creds.key, creds.value);
        return;
      } on Exception catch (_) {
        // Credentials no longer work; forget them.
        await AuthInterceptor.clearCredentials();
      }
    }

    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<bool> login(String username, String password) async {
    state = const AuthState(status: AuthStatus.loading);

    // Verify connectivity first; three strikes and we start over.
    if (!await _checkConnection()) {
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        serverUnreachable: true,
        message: AuthMessage(AuthMessageCode.serverUnavailable),
      );
      return false;
    }

    try {
      await _authenticate(username, password);
      return true;
    } on Exception catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        message: _friendlyLoginError(e),
      );
      return false;
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    String? phone,
    String? inviteCode,
  }) async {
    final passwordHash = sha256.convert(utf8.encode(password)).toString();
    state = const AuthState(status: AuthStatus.loading);
    try {
      final response = await _repository.register(
        username: username,
        email: email,
        passwordHash: passwordHash,
        phone: phone,
        inviteCode: inviteCode,
      );
      await _persistSession(username, password, response);
      return true;
    } on Exception catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        message: _friendlyRegisterError(e),
      );
      return false;
    }
  }

  Future<void> logout() async {
    await AuthInterceptor.clearTokens();
    await AuthInterceptor.clearCredentials();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Clears a previous "server unreachable" condition once the user has
  /// successfully reconnected from the server-config screen.
  void clearConnectionError() {
    if (state.serverUnreachable) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// Entering registration should not inherit an old login error.
  void clearError() {
    if (state.status == AuthStatus.error) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// 重新拉取当前用户（头像/昵称/设置变更后刷新，web fetchUser 对应物）。
  Future<void> refreshUser() async {
    try {
      final user = await _repository.getCurrentUser();
      if (state.status == AuthStatus.authenticated) {
        state = AuthState(status: AuthStatus.authenticated, user: user);
      }
    } on Exception catch (_) {
      // 刷新失败保持旧状态，不打扰当前会话
    }
  }

  /// 用 PATCH/PUT 响应直接覆盖用户状态（省一次 GET）。
  void applyUser(User user) {
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }

  /// Logs in and persists the session (tokens + credentials) so the next
  /// launch can skip the login screen entirely.
  Future<void> _authenticate(String username, String password) async {
    final passwordHash = sha256.convert(utf8.encode(password)).toString();
    final response = await _repository.login(
      LoginRequest(username: username, passwordHash: passwordHash),
    );
    await _persistSession(username, password, response);
  }

  Future<void> _persistSession(
    String username,
    String password,
    LoginResponse response,
  ) async {
    try {
      await AuthInterceptor.saveTokens(
          response.accessToken, response.refreshToken);
    } catch (_) {}
    try {
      await AuthInterceptor.saveCredentials(username, password);
    } catch (_) {}
    final user = await _repository.getCurrentUser();
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }

  /// Maps raw login exceptions to short, user-facing messages.
  AuthMessage _friendlyLoginError(Exception e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      if (code == 400 || code == 401 || code == 403) {
        return const AuthMessage(AuthMessageCode.loginInvalidCredentials);
      }
      if (code == 404) {
        return const AuthMessage(AuthMessageCode.loginEndpointMissing);
      }
      if (code != null && code >= 500) {
        return const AuthMessage(AuthMessageCode.serverError);
      }
      return const AuthMessage(AuthMessageCode.loginNetworkError);
    }
    return const AuthMessage(AuthMessageCode.loginGenericError);
  }

  AuthMessage _friendlyRegisterError(Exception e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      final detail = _serverDetail(e);
      final invalidRequest =
          code == 400 || code == 401 || code == 403 || code == 409;
      if (invalidRequest && detail != null) {
        return AuthMessage(AuthMessageCode.registerFailedDetail,
            detail: detail);
      }
      if (invalidRequest) {
        return const AuthMessage(AuthMessageCode.registerInvalid);
      }
      if (code == 404) {
        return const AuthMessage(AuthMessageCode.registerEndpointMissing);
      }
      if (code != null && code >= 500) {
        return const AuthMessage(AuthMessageCode.registerServerError);
      }
      return const AuthMessage(AuthMessageCode.registerNetworkError);
    }
    return const AuthMessage(AuthMessageCode.registerGenericError);
  }

  String? _serverDetail(DioException e) {
    final data = e.response?.data;
    final detail = data is Map ? data['detail'] : null;
    if (detail is String && detail.trim().isNotEmpty) return detail.trim();
    return null;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(AuthRepository());
});

final authConfigProvider = FutureProvider.autoDispose<AuthConfig>((ref) async {
  return AuthRepository().getConfig();
});

final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).status == AuthStatus.authenticated;
});
