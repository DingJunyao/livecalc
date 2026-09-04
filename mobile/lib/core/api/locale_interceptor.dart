import 'package:dio/dio.dart';

import '../i18n/locale_settings.dart';

class LocaleInterceptor extends Interceptor {
  final LocaleSettingsStore _store;

  LocaleInterceptor(this._store);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['Accept-Language'] = _store.current.uiLocale;
    handler.next(options);
  }
}
