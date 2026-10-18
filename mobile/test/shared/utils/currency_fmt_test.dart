import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/core/i18n/locale_settings.dart';
import 'package:com_a4ding_livecalc/shared/utils/currency_fmt.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('format money uses the current effective format locale', () {
    final originalSettings = localeSettingsStore.current;
    addTearDown(() => localeSettingsStore.update(originalSettings));
    localeSettingsStore.update(
      const LocaleSettings(uiLocale: 'en-US', formatLocale: 'de-DE'),
    );

    expect(formatMoney(1234.5, 'CNY'), '1.234,5 CNY');
  });

  test('format money accepts an explicit locale and ISO code', () {
    expect(
      formatMoney(1234.5, 'CNY', formatLocale: 'en-GB'),
      '1,234.5 CNY',
    );
    expect(
      formatMoney(1234.5, 'CNY', formatLocale: 'zh-CN'),
      isNot(contains('¥')),
    );
  });

  test('format money defaults an empty currency to CNY', () {
    expect(
      formatMoney(1234.5, '', formatLocale: 'zh-CN'),
      '1,234.5 CNY',
    );
  });

  test('price keeps its native currency and converts a foreign record', () {
    expect(
      formatMoneyWithConvert(
        1250,
        'IDR',
        'CNY',
        exchangeRate: 0.1,
        formatLocale: 'zh-CN',
      ),
      '1,250 IDR ≈ 125 CNY',
    );
    expect(
      formatMoneyWithConvert(
        1250,
        'IDR',
        'CNY',
        exchangeRate: null,
        formatLocale: 'zh-CN',
      ),
      '1,250 IDR',
    );
    expect(
      formatMoneyWithConvert(
        1250,
        'cny',
        'CNY',
        exchangeRate: 0.1,
        formatLocale: 'zh-CN',
      ),
      '1,250 CNY',
    );
  });
}
