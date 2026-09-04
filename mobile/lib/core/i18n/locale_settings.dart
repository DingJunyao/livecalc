import 'package:flutter/material.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/models/user.dart';
import 'app_locale.dart' as locale_utils;

class LocaleSettings {
  final String uiLocale;
  final String? formatLocale;

  const LocaleSettings({
    required this.uiLocale,
    this.formatLocale,
  });

  String get effectiveFormatLocale => locale_utils.effectiveFormatLocale(
        uiLocale: uiLocale,
        formatLocale: formatLocale,
      );
}

class LocaleSettingsStore {
  LocaleSettings _current = const LocaleSettings(
    uiLocale: locale_utils.defaultUiLocale,
  );

  LocaleSettings get current => _current;

  void update(LocaleSettings settings) {
    _current = settings;
  }
}

final LocaleSettingsStore localeSettingsStore = LocaleSettingsStore();

class LocaleSettingsController extends StateNotifier<LocaleSettings> {
  static const _uiLocaleKey = 'mobile.ui_locale';
  static const _formatLocaleKey = 'mobile.format_locale';

  final LocaleSettingsStore _store;
  List<Locale> _systemLocales = const [];

  LocaleSettingsController({LocaleSettingsStore? store})
      : _store = store ?? localeSettingsStore,
        super(const LocaleSettings(
          uiLocale: locale_utils.defaultUiLocale,
        ));

  LocaleSettings get current => state;

  Future<void> load({required List<Locale> systemLocales}) async {
    _systemLocales = List.unmodifiable(systemLocales);
    final prefs = await SharedPreferences.getInstance();

    _update(
      LocaleSettings(
        uiLocale: locale_utils.resolveUiLocale(
          cachedLocale: _validatedCachedUiLocale(
            prefs.getString(_uiLocaleKey),
          ),
          systemLocales: _systemLocales,
        ),
        formatLocale: _validatedFormatLocale(
          prefs.getString(_formatLocaleKey),
        ),
      ),
    );
  }

  Future<void> applyUser(User? user) async {
    final prefs = await SharedPreferences.getInstance();

    if (user == null) {
      await prefs.remove(_uiLocaleKey);
      await prefs.remove(_formatLocaleKey);
      _update(LocaleSettings(
        uiLocale: locale_utils.resolveUiLocale(
          systemLocales: _systemLocales,
        ),
      ));
      return;
    }

    final uiLocale = locale_utils.resolveUiLocale(
      userLocale: user.locale,
      cachedLocale: _validatedCachedUiLocale(
        prefs.getString(_uiLocaleKey),
      ),
      systemLocales: _systemLocales,
    );
    final formatLocale = _validatedFormatLocale(user.formatLocale);
    await prefs.setString(_uiLocaleKey, uiLocale);
    if (formatLocale == null) {
      await prefs.remove(_formatLocaleKey);
    } else {
      await prefs.setString(_formatLocaleKey, formatLocale);
    }

    _update(LocaleSettings(
      uiLocale: uiLocale,
      formatLocale: formatLocale,
    ));
  }

  void update(LocaleSettings settings) => _update(settings);

  void _update(LocaleSettings settings) {
    state = settings;
    _store.update(settings);
  }

  String? _validatedFormatLocale(String? formatLocale) {
    if (formatLocale == null ||
        !locale_utils.supportedFormatLocales.contains(formatLocale)) {
      return null;
    }
    return formatLocale;
  }

  String? _validatedCachedUiLocale(String? uiLocale) {
    if (uiLocale == null ||
        !locale_utils.supportedUiLocales.contains(uiLocale)) {
      return null;
    }
    return uiLocale;
  }
}

final localeSettingsProvider =
    StateNotifierProvider<LocaleSettingsController, LocaleSettings>((ref) {
  return LocaleSettingsController(store: localeSettingsStore);
});
