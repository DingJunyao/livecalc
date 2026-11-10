import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:com_a4ding_livecalc/core/api/api_client.dart';
import 'package:com_a4ding_livecalc/shared/providers/calc_context_provider.dart';

/// 捕获请求头的假适配器（不发出真实网络请求）。
class _CaptureAdapter implements HttpClientAdapter {
  final List<RequestOptions> captured = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured.add(options);
    return ResponseBody.fromBytes(
      utf8.encode('{}'),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  // 模块级 _calcContext 是全局单例，逐用例重置避免串扰。
  tearDownAll(() {
    CalcContextNotifier().clear();
  });

  test('默认无会话覆盖时不注入 X-Region', () async {
    CalcContextNotifier().clear();
    final adapter = _CaptureAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
      ..httpClientAdapter = adapter
      ..interceptors.add(CalcContextInterceptor());

    await dio.get('/ping');

    expect(adapter.captured.single.headers.containsKey('X-Region'), isFalse);
  });

  test('会话选择「全部地区」时显式注入 X-Region: all', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container
        .read(calcContextProvider.notifier)
        .apply(regionId: null, scope: '', currency: null);

    final adapter = _CaptureAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
      ..httpClientAdapter = adapter
      ..interceptors.add(CalcContextInterceptor());

    await dio.get('/ping');

    expect(adapter.captured.single.headers['X-Region'], 'all');
  });

  test('未设置会话币种时不注入 X-Currency，设置后注入', () async {
    CalcContextNotifier().clear();
    final adapter = _CaptureAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
      ..httpClientAdapter = adapter
      ..interceptors.add(CalcContextInterceptor());

    await dio.get('/ping');
    expect(adapter.captured.first.headers.containsKey('X-Currency'), isFalse);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container
        .read(calcContextProvider.notifier)
        .apply(regionId: null, scope: null, currency: 'USD');
    await dio.get('/ping');

    expect(adapter.captured.last.headers['X-Currency'], 'USD');
    // scope 为 null（跟随配置）且 effectiveRegionId 为空 → 仍不注入 X-Region
    expect(adapter.captured.last.headers.containsKey('X-Region'), isFalse);
  });
}
