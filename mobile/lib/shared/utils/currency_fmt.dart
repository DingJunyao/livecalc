import 'package:intl/intl.dart';

import '../../core/i18n/app_formatters.dart' as app_formatters;

String currencySymbol(String code) {
  try {
    final fmt = NumberFormat.simpleCurrency(name: code);
    final s = fmt.currencySymbol;
    return s.isEmpty ? code : s;
  } catch (_) {
    return code;
  }
}

String formatMoney(
  num amount,
  String code, {
  String? formatLocale,
}) {
  final cur = code.isNotEmpty ? code : 'CNY';
  return app_formatters.formatMoney(amount, cur, formatLocale: formatLocale);
}

num convertAmount(num amount, num? exchangeRate) {
  return amount * (exchangeRate ?? 1);
}

String formatMoneyWithConvert(
  num amount,
  String code,
  String targetCode, {
  num? exchangeRate,
  String? formatLocale,
}) {
  final native = formatMoney(amount, code, formatLocale: formatLocale);
  final nativeCode = code.trim().toUpperCase();
  final target = targetCode.trim().toUpperCase();
  final rate = exchangeRate;
  if (nativeCode.isEmpty ||
      nativeCode == target ||
      rate == null ||
      rate <= 0) {
    return nativeCode == target
        ? formatMoney(amount, target, formatLocale: formatLocale)
        : native;
  }
  return '$native ≈ ${formatMoney(convertAmount(amount, rate), target, formatLocale: formatLocale)}';
}
