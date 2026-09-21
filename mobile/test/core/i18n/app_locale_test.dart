import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/core/i18n/app_locale.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';

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
    // Material 组件的数字/日期来自 CLDR：intl 的 'ar' 数字符号是 ASCII，
    // 只有 ar-EG 才是阿拉伯-印度数字，因此 Material 层固定用 ar-EG。
    expect(flutterLocaleFor('ar'), const Locale('ar', 'EG'));
  });

  testWidgets('Arabic Material widgets format numbers as Arabic-Indic digits',
      (tester) async {
    late String decimal;
    await tester.pumpWidget(MaterialApp(
      locale: flutterLocaleFor('ar'),
      localeResolutionCallback: (_, __) => flutterLocaleFor('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales:
          supportedUiLocales.map(flutterLocaleFor).toList(growable: false),
      home: Builder(
        builder: (context) {
          decimal = MaterialLocalizations.of(context).formatDecimal(1234);
          return const SizedBox.shrink();
        },
      ),
    ));

    // 日期选择器/时间选择器的数字都走这里的 formatDecimal。
    expect(decimal, '١٬٢٣٤');
  });

  testWidgets('Arabic date picker renders Arabic-Indic day numbers',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: flutterLocaleFor('ar'),
      localeResolutionCallback: (_, __) => flutterLocaleFor('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales:
          supportedUiLocales.map(flutterLocaleFor).toList(growable: false),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDatePicker(
            context: context,
            initialDate: DateTime(2026, 9, 4),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('٣٠'), findsOneWidget);
    expect(find.text('30'), findsNothing);
  });
}
