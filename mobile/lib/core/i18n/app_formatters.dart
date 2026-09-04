import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'locale_settings.dart';

String _intlLocale(String? formatLocale) {
  final effectiveLocale =
      formatLocale ?? localeSettingsStore.current.effectiveFormatLocale;
  return effectiveLocale.replaceAll('-', '_');
}

String formatDate(DateTime value, {String? formatLocale}) {
  final locale = _intlLocale(formatLocale);
  initializeDateFormatting(locale);
  return DateFormat.yMd(locale).format(value);
}

String formatDateTime(DateTime value, {String? formatLocale}) {
  final locale = _intlLocale(formatLocale);
  initializeDateFormatting(locale);
  return DateFormat.yMd(locale).add_Hm().format(value);
}

String formatTime(DateTime value, {String? formatLocale}) {
  final locale = _intlLocale(formatLocale);
  initializeDateFormatting(locale);
  return DateFormat.Hm(locale).format(value);
}

String formatNumber(
  num value, {
  int minimumFractionDigits = 0,
  int maximumFractionDigits = 2,
  String? formatLocale,
}) {
  final formatter = NumberFormat.decimalPatternDigits(
    locale: _intlLocale(formatLocale),
    decimalDigits: maximumFractionDigits,
  )..minimumFractionDigits = minimumFractionDigits;
  return formatter.format(value);
}

String formatQuantity(num value, {String? formatLocale}) {
  return formatNumber(
    value,
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
    formatLocale: formatLocale,
  );
}

String formatPercentValue(
  num value, {
  int maximumFractionDigits = 1,
  String? formatLocale,
}) {
  return '${formatNumber(
    value,
    minimumFractionDigits: 0,
    maximumFractionDigits: maximumFractionDigits,
    formatLocale: formatLocale,
  )}%';
}

String formatMoney(
  num amount,
  String currencyCode, {
  String? formatLocale,
}) {
  return '${formatNumber(amount, formatLocale: formatLocale)} $currencyCode';
}
