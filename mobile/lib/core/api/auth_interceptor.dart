import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthInterceptor extends Interceptor {
  final Dio _dio;
  final _storage = const FlutterSecureStorage();

  static const _tokenKey = 'auth_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _usernameKey = 'saved_username';
  static const _passwordKey = 'saved_password';

  AuthInterceptor(this._dio);

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    options.headers['X-Timezone'] = _formatUtcOffset();
    try {
      // 刷新接口不带 Authorization，避免过期的 access token 让刷新请求也 401。
      if (!_isRefreshRequest(options)) {
        final token = await _storage.read(key: _tokenKey);
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {}
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final refreshToken = await _storage.read(key: _refreshTokenKey);
      if (refreshToken != null) {
        // 刷新请求本身 401（refresh token 已失效/被重置）时直接清 token 结束，
        // 不再触发新的刷新，避免无限递归刷新死循环。
        if (_isRefreshRequest(err.requestOptions)) {
          await _storage.delete(key: _tokenKey);
          await _storage.delete(key: _refreshTokenKey);
          handler.next(err);
          return;
        }
        try {
          final resp = await _dio.post('/auth/refresh', data: {
            'refresh_token': refreshToken,
          });
          final newToken = resp.data['access_token'] as String;
          await _storage.write(key: _tokenKey, value: newToken);
          final retryOpts = err.requestOptions;
          retryOpts.headers['Authorization'] = 'Bearer $newToken';
          final retryResp = await _dio.fetch(retryOpts);
          handler.resolve(retryResp);
          return;
        } catch (_) {
          await _storage.delete(key: _tokenKey);
          await _storage.delete(key: _refreshTokenKey);
        }
      }
    }
    handler.next(err);
  }

  /// 是否为 token 刷新请求（/auth/refresh 或带 baseUrl 前缀的完整路径）。
  bool _isRefreshRequest(RequestOptions options) {
    final path = options.path;
    return path == '/auth/refresh' || path.endsWith('/auth/refresh');
  }

  /// Formats timezone offset as ASCII-safe UTC+HH:mm (e.g. UTC+08:00, UTC-05:00).
  String _formatUtcOffset() {
    final offset = DateTime.now().timeZoneOffset;
    final totalMinutes = offset.inMinutes;
    final sign = totalMinutes.isNegative ? '-' : '+';
    final absMinutes = totalMinutes.abs();
    final hours = absMinutes ~/ 60;
    final minutes = absMinutes % 60;
    final hh = hours.toString().padLeft(2, '0');
    final mm = minutes.toString().padLeft(2, '0');
    return 'UTC$sign$hh:$mm';
  }

  static Future<void> saveTokens(
      String accessToken, String refreshToken) async {
    const storage = FlutterSecureStorage();
    await storage.write(key: _tokenKey, value: accessToken);
    await storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  static Future<void> clearTokens() async {
    const storage = FlutterSecureStorage();
    await storage.delete(key: _tokenKey);
    await storage.delete(key: _refreshTokenKey);
  }

  static Future<String?> get accessToken =>
      const FlutterSecureStorage().read(key: _tokenKey);
  static Future<void> saveCredentials(String username, String password) async {
    const storage = FlutterSecureStorage();
    await storage.write(key: _usernameKey, value: username);
    await storage.write(key: _passwordKey, value: password);
  }

  /// Persisted last successful login so the next launch can sign in
  /// automatically without re-typing server/account/password.
  static Future<MapEntry<String, String>?> get savedCredentials async {
    const storage = FlutterSecureStorage();
    final username = await storage.read(key: _usernameKey);
    final password = await storage.read(key: _passwordKey);
    if (username == null || password == null) return null;
    return MapEntry(username, password);
  }

  static Future<void> clearCredentials() async {
    const storage = FlutterSecureStorage();
    await storage.delete(key: _usernameKey);
    await storage.delete(key: _passwordKey);
  }
}
