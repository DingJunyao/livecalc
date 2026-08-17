import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:com_a4ding_livecalc/core/api/auth_interceptor.dart';

/// 可控的 HttpClientAdapter：
/// - /auth/refresh 按 [refreshStatus] 返回
/// - 其它路径第一次返回 401，之后返回 200（模拟“过期后重试成功”）
class _FlakyAdapter implements HttpClientAdapter {
  final int refreshStatus;
  int merchantsCalls = 0;
  int refreshCalls = 0;

  _FlakyAdapter({required this.refreshStatus});

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final path = options.path;
    if (path.endsWith('/auth/refresh')) {
      refreshCalls++;
      return _body(
        refreshStatus,
        refreshStatus == 200
            ? '{"access_token":"new-token"}'
            : '{"detail":"invalid refresh token"}',
      );
    }
    merchantsCalls++;
    if (merchantsCalls == 1) {
      return _body(401, '{"detail":"access token expired"}');
    }
    return _body(200, '{"ok":true}');
  }

  ResponseBody _body(int status, String json) => ResponseBody.fromString(
        json,
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

void main() {
  final Map<String, String> secureStore = {};

  Future<dynamic> secureStorageHandler(MethodCall call) async {
    final args = call.arguments is Map
        ? Map<String, dynamic>.from(call.arguments as Map)
        : <String, dynamic>{};
    switch (call.method) {
      case 'read':
        return secureStore[args['key']];
      case 'write':
        secureStore[args['key'] as String] = args['value'] as String;
        return null;
      case 'delete':
        secureStore.remove(args['key']);
        return null;
      case 'containsKey':
        return secureStore.containsKey(args['key']);
      case 'deleteAll':
        secureStore.clear();
        return null;
      case 'readAll':
        return secureStore;
      default:
        return null;
    }
  }

  Dio buildDio(_FlakyAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(AuthInterceptor(dio));
    return dio;
  }

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final channel in [
      'plugins.it_nomads.com/flutter_secure_storage',
      'plugins.flutter.io/flutter_secure_storage',
      'plugins.flutter.io/flutter_secure_storage_windows',
      'plugins.flutter.io/flutter_secure_storage_linux',
      'plugins.flutter.io/flutter_secure_storage_macos',
      'plugins.flutter.io/flutter_secure_storage_web',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              MethodChannel(channel), secureStorageHandler);
    }
  });

  setUp(() => secureStore.clear());

  test('刷新 token 失效（401）时只刷新一次并清空 token，不死循环', () async {
    await AuthInterceptor.saveTokens('expired-access', 'invalid-refresh');
    final adapter = _FlakyAdapter(refreshStatus: 401);
    final dio = buildDio(adapter);

    await expectLater(
      dio.get('/merchants'),
      throwsA(isA<DioException>()),
    );

    // 关键断言：只发起过一次 /auth/refresh，没有无限递归
    expect(adapter.refreshCalls, 1);
    // token 被清空，后续可走重新登录流程
    expect(secureStore['auth_token'], isNull);
    expect(secureStore['refresh_token'], isNull);
  });

  test('刷新成功：更新 token 并重试原请求', () async {
    await AuthInterceptor.saveTokens('expired-access', 'valid-refresh');
    final adapter = _FlakyAdapter(refreshStatus: 200);
    final dio = buildDio(adapter);

    final resp = await dio.get('/merchants');

    expect(resp.statusCode, 200);
    expect(adapter.refreshCalls, 1);
    expect(adapter.merchantsCalls, 2);
    // 新 access token 已写入
    expect(secureStore['auth_token'], 'new-token');
  });

  test('刷新请求不带旧的 Authorization 头', () async {
    await AuthInterceptor.saveTokens('expired-access', 'valid-refresh');
    final adapter = _FlakyAdapter(refreshStatus: 200);
    final dio = buildDio(adapter);

    String? refreshAuthHeader;
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path.endsWith('/auth/refresh')) {
          refreshAuthHeader = options.headers['Authorization'] as String?;
        }
        handler.next(options);
      },
    ));

    await dio.get('/merchants');
    expect(refreshAuthHeader, isNull);
  });
}
