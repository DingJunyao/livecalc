import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:com_a4ding_livecalc/core/api/locale_interceptor.dart';
import 'package:com_a4ding_livecalc/core/i18n/locale_settings.dart';

class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString('{"id":1}', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('sets Accept-Language and preserves existing request headers', () async {
    final adapter = _RecordingAdapter();
    final store = LocaleSettingsStore()
      ..update(const LocaleSettings(uiLocale: 'ar'));
    final dio = Dio()
      ..httpClientAdapter = adapter
      ..interceptors.add(LocaleInterceptor(store));

    await dio.get(
      '/auth/me',
      options: Options(headers: {
        'Authorization': 'Bearer valid-token',
        'X-Timezone': 'Asia/Makassar',
      }),
    );

    final headers = adapter.request!.headers;
    expect(headers['Accept-Language'], 'ar');
    expect(headers['Authorization'], 'Bearer valid-token');
    expect(headers['X-Timezone'], 'Asia/Makassar');
  });
}
