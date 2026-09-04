import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:com_a4ding_livecalc/core/i18n/locale_settings.dart';
import 'package:com_a4ding_livecalc/features/auth/models/user.dart';

User _user({String? locale, String? formatLocale}) {
  return User(
    id: 1,
    username: 'ding',
    email: 'ding@example.test',
    locale: locale,
    formatLocale: formatLocale,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('load uses validated cache before normalized system locale', () async {
    SharedPreferences.setMockInitialValues({
      'mobile.ui_locale': 'en-US',
      'mobile.format_locale': 'en-GB',
    });
    final controller = LocaleSettingsController();

    await controller.load(systemLocales: const [Locale('zh', 'CN')]);

    expect(controller.current.uiLocale, 'en-US');
    expect(controller.current.formatLocale, 'en-GB');
    expect(controller.current.effectiveFormatLocale, 'en-GB');
  });

  test('load falls back to the first supported normalized system locale',
      () async {
    final controller = LocaleSettingsController();

    await controller.load(systemLocales: const [
      Locale('fr', 'FR'),
      Locale('zh', 'TW'),
      Locale('en'),
    ]);

    expect(controller.current.uiLocale, 'en-US');
    expect(controller.current.formatLocale, isNull);
    expect(controller.current.effectiveFormatLocale, 'en-US');
  });

  test('load ignores invalid cached locale values', () async {
    SharedPreferences.setMockInitialValues({
      'mobile.ui_locale': 'fr-FR',
      'mobile.format_locale': 'fr-FR',
    });
    final controller = LocaleSettingsController();

    await controller.load(systemLocales: const [Locale('en')]);

    expect(controller.current.uiLocale, 'en-US');
    expect(controller.current.formatLocale, isNull);
    expect(controller.current.effectiveFormatLocale, 'en-US');
  });

  test('applyUser lets the signed-in server preference override cache',
      () async {
    SharedPreferences.setMockInitialValues({
      'mobile.ui_locale': 'en-US',
      'mobile.format_locale': 'en-GB',
    });
    final controller = LocaleSettingsController();
    await controller.load(systemLocales: const [Locale('zh', 'CN')]);

    await controller.applyUser(
      _user(locale: 'ar', formatLocale: 'de-DE'),
    );

    expect(controller.current.uiLocale, 'ar');
    expect(controller.current.formatLocale, 'de-DE');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('mobile.ui_locale'), 'ar');
    expect(prefs.getString('mobile.format_locale'), 'de-DE');
  });

  test('applyUser(null) clears authenticated cache and returns to system',
      () async {
    final controller = LocaleSettingsController();
    await controller.load(systemLocales: const [Locale('zh', 'CN')]);
    await controller.applyUser(
      _user(locale: 'en-US', formatLocale: 'en-GB'),
    );

    await controller.applyUser(null);

    expect(controller.current.uiLocale, 'zh-CN');
    expect(controller.current.formatLocale, isNull);
    expect(controller.current.effectiveFormatLocale, 'zh-CN');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('mobile.ui_locale'), isFalse);
    expect(prefs.containsKey('mobile.format_locale'), isFalse);
  });
}
