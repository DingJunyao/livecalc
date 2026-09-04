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
