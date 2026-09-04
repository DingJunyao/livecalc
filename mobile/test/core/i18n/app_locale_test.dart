import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/core/i18n/app_locale.dart';

void main() {
  test('locale whitelists match the shared specification', () {
    expect(supportedUiLocales, ['zh-CN', 'en-US', 'ar']);
    expect(supportedFormatLocales, {
      'zh-CN',
      'zh-TW',
      'en-US',
      'en-GB',
      'ja-JP',
      'de-DE',
      'id-ID',
      'ar-EG',
    });
    expect(defaultUiLocale, 'zh-CN');
  });

  test('server locale wins, cache is second, then normalized system locale',
      () {
    expect(
      resolveUiLocale(
        userLocale: 'ar',
        cachedLocale: 'en-US',
        systemLocales: const [Locale('zh', 'CN')],
      ),
      'ar',
    );
    expect(
      resolveUiLocale(
        cachedLocale: 'en-US',
        systemLocales: const [Locale('zh', 'CN')],
      ),
      'en-US',
    );
    expect(
      resolveUiLocale(systemLocales: const [
        Locale('fr', 'FR'),
        Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
          countryCode: 'CN',
        ),
      ]),
      'zh-CN',
    );
    expect(resolveUiLocale(systemLocales: const [Locale('en')]), 'en-US');
    expect(resolveUiLocale(systemLocales: const [Locale('ar')]), 'ar');
    expect(resolveUiLocale(systemLocales: const []), 'zh-CN');
  });

  test('format locale follows explicit choice or UI default', () {
    expect(effectiveFormatLocale(uiLocale: 'ar'), 'ar-EG');
    expect(
      effectiveFormatLocale(uiLocale: 'ar', formatLocale: 'de-DE'),
      'de-DE',
    );
    expect(
      effectiveFormatLocale(uiLocale: 'zh-CN', formatLocale: 'unsupported'),
      'zh-CN',
    );
    expect(flutterLocaleFor('zh-CN'), const Locale('zh', 'CN'));
    expect(flutterLocaleFor('en-US'), const Locale('en', 'US'));
    expect(flutterLocaleFor('ar'), const Locale('ar'));
  });
}
