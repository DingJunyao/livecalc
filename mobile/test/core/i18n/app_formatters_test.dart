import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/core/i18n/app_formatters.dart';
import 'package:com_a4ding_livecalc/core/i18n/locale_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('formats dates, times, numbers, and money for zh-CN', () {
    final value = DateTime.utc(2026, 9, 4, 14, 30);

    expect(formatDate(value, formatLocale: 'zh-CN'), '2026/9/4');
    expect(
      formatDateTime(value, formatLocale: 'zh-CN'),
      contains('2026/9/4'),
    );
    expect(formatTime(value, formatLocale: 'zh-CN'), '14:30');
    expect(
      formatNumber(1234.5, formatLocale: 'zh-CN'),
      '1,234.5',
    );
    expect(
      formatMoney(1234.5, 'CNY', formatLocale: 'zh-CN'),
      '1,234.5 CNY',
    );
  });

  test('formats German numbers with comma decimals and dot grouping', () {
    expect(
      formatNumber(1234.5, formatLocale: 'de-DE'),
      '1.234,5',
    );
  });

  test('formats English day-first dates', () {
    final value = DateTime.utc(2026, 9, 4);

    expect(formatDate(value, formatLocale: 'en-GB'), '04/09/2026');
  });

  test('formats Arabic dates and numbers without throwing', () {
    final value = DateTime.utc(2026, 9, 4, 14, 30);

    expect(formatDate(value, formatLocale: 'ar-EG'), isNotEmpty);
    expect(formatNumber(1234.5, formatLocale: 'ar-EG'), isNotEmpty);
  });

  test('trims quantity trailing zeroes without losing precision', () {
    expect(formatQuantity(1.0), '1');
    expect(formatQuantity(1.25), '1.25');
  });

  test('formats percentage values', () {
    final result = formatPercentValue(12.3);

    expect(result, contains('12.3'));
    expect(result, contains('%'));
  });

  test('uses the current effective locale when none is provided', () {
    final originalSettings = localeSettingsStore.current;
    addTearDown(() => localeSettingsStore.update(originalSettings));
    localeSettingsStore.update(
      const LocaleSettings(uiLocale: 'en-US', formatLocale: 'de-DE'),
    );

    expect(formatNumber(1234.5), '1.234,5');
    expect(formatMoney(1234.5, 'CNY'), '1.234,5 CNY');
  });
}
