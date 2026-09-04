import 'package:flutter/material.dart' show Locale;

const List<String> supportedUiLocales = ['zh-CN', 'en-US', 'ar'];

const Set<String> supportedFormatLocales = {
  'zh-CN',
  'zh-TW',
  'en-US',
  'en-GB',
  'ja-JP',
  'de-DE',
  'id-ID',
  'ar-EG',
};

const String defaultUiLocale = 'zh-CN';

const Map<String, String> _uiLocaleAliases = {
  'zh': 'zh-CN',
  'zh-Hans': 'zh-CN',
  'zh-CN': 'zh-CN',
  'en': 'en-US',
  'en-US': 'en-US',
  'ar': 'ar',
};

const Map<String, String> _defaultFormatLocales = {
  'zh-CN': 'zh-CN',
  'en-US': 'en-US',
  'ar': 'ar-EG',
};

const Map<String, Locale> _flutterLocales = {
  'zh-CN': Locale('zh', 'CN'),
  'en-US': Locale('en', 'US'),
  'ar': Locale('ar'),
};

String resolveUiLocale({
  String? userLocale,
  String? cachedLocale,
  List<Locale> systemLocales = const [],
}) {
  if (userLocale != null) {
    return _uiLocaleAliases[userLocale] ?? defaultUiLocale;
  }

  if (cachedLocale != null) {
    return _uiLocaleAliases[cachedLocale] ?? defaultUiLocale;
  }

  for (final systemLocale in systemLocales) {
    final locale = _normalizeSystemLocale(systemLocale);
    if (locale != null) {
      return locale;
    }
  }

  return defaultUiLocale;
}

String effectiveFormatLocale({required String uiLocale, String? formatLocale}) {
  if (formatLocale != null && supportedFormatLocales.contains(formatLocale)) {
    return formatLocale;
  }

  final normalizedUiLocale = _uiLocaleAliases[uiLocale] ?? defaultUiLocale;
  return _defaultFormatLocales[normalizedUiLocale] ?? defaultUiLocale;
}

Locale flutterLocaleFor(String uiLocale) {
  return _flutterLocales[_uiLocaleAliases[uiLocale] ?? defaultUiLocale]!;
}

String? _normalizeSystemLocale(Locale locale) {
  final languageCode = locale.languageCode;

  if (locale.scriptCode != null && locale.countryCode != null) {
    final scriptLocale = _uiLocaleAliases['$languageCode-${locale.scriptCode}'];
    if (scriptLocale != null) {
      return scriptLocale;
    }
  }

  final subtag = locale.scriptCode ?? locale.countryCode;
  return _uiLocaleAliases[
      subtag == null ? languageCode : '$languageCode-$subtag'];
}
