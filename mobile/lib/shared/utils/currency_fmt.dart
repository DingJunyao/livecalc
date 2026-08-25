import 'package:intl/intl.dart';

String currencySymbol(String code) {
  try {
    final fmt = NumberFormat.simpleCurrency(name: code);
    final s = fmt.currencySymbol;
    return s.isEmpty ? code : s;
  } catch (_) {
    return code;
  }
}

String formatMoney(num amount, String code) {
  final cur = code.isNotEmpty ? code : 'CNY';
  try {
    return NumberFormat.simpleCurrency(name: cur).format(amount);
  } catch (_) {
    return '${amount.toStringAsFixed(2)} $cur';
  }
}

num convertAmount(num amount, num? exchangeRate) {
  return amount * (exchangeRate ?? 1);
}