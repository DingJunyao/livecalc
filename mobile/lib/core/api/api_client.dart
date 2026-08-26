import 'package:dio/dio.dart';
import 'dart:developer';

import 'auth_interceptor.dart';
import '../../shared/providers/calc_context_provider.dart';

class ApiClient {
  static ApiClient? _instance;
  late final Dio dio;
  String _baseUrl = '';

  ApiClient._() {
    dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));
    dio.interceptors.add(AuthInterceptor(dio));
    dio.interceptors.add(CalcContextInterceptor());
    dio.interceptors.add(LogInterceptor(
      request: true,
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => log(obj.toString()),
    ));
  }

  static ApiClient get instance {
    _instance ??= ApiClient._();
    return _instance!;
  }

  void updateBaseUrl(String baseUrl) {
    if (_baseUrl == baseUrl) return;
    _baseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    dio.options.baseUrl = '$_baseUrl/api/v1';
  }

  String get baseUrl => _baseUrl;
}


/// 会话级临时覆盖拦截器：导航栏切换币种/地区后，向请求注入 X-Currency / X-Region 头。
class CalcContextInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final ctx = currentCalcContext;
    if (ctx.currency != null && ctx.currency!.isNotEmpty) {
      options.headers['X-Currency'] = ctx.currency;
    }
    if (ctx.effectiveRegionId != null) {
      options.headers['X-Region'] = '${ctx.effectiveRegionId}';
    }
    handler.next(options);
  }
}