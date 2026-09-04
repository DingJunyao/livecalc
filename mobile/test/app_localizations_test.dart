import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:com_a4ding_livecalc/app.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';
import 'package:com_a4ding_livecalc/core/i18n/locale_settings.dart';
import 'package:com_a4ding_livecalc/features/auth/providers/auth_provider.dart';
import 'package:com_a4ding_livecalc/features/auth/repositories/auth_repository.dart';
import 'package:com_a4ding_livecalc/features/auth/providers/server_provider.dart';
import 'package:com_a4ding_livecalc/features/profile/providers/startup_page_provider.dart';

/// 防回归：app.dart 配置了中文 localizations，Material 内置组件
/// （返回按钮 tooltip、文本框长按菜单等）必须显示中文而非英文默认值。
void main() {
  testWidgets('中文配置下 BackButton tooltip 为「返回」', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: const [Locale('zh', 'CN')],
        locale: const Locale('zh', 'CN'),
        home: Scaffold(
          appBar: AppBar(title: const Text('测试')),
          body: const BackButton(),
        ),
      ),
    );
    expect(find.byTooltip('返回'), findsOneWidget);
    // 英文默认文案不应存在
    expect(find.byTooltip('Back'), findsNothing);
  });

  testWidgets('LiveCalcApp exposes all supported locales and resolves ar',
      (tester) async {
    final localeSettings = LocaleSettingsController()
      ..update(const LocaleSettings(uiLocale: 'ar'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localeSettingsProvider.overrideWith((_) => localeSettings),
          serverConfigProvider.overrideWith((_) => _NoopServerConfig()),
          startupPageProvider.overrideWith((_) => _NoopStartupPage()),
          authProvider.overrideWith((_) => _NoopAuthNotifier()),
        ],
        child: const LiveCalcApp(),
      ),
    );
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, const Locale('ar'));
    expect(app.supportedLocales, const [
      Locale('zh', 'CN'),
      Locale('en', 'US'),
      Locale('ar'),
    ]);
    expect(
      app.localizationsDelegates?.contains(AppLocalizations.delegate),
      isTrue,
    );
    expect(
      app.localizationsDelegates
          ?.contains(GlobalMaterialLocalizations.delegate),
      isTrue,
    );
    expect(
      app.localizationsDelegates
          ?.contains(GlobalCupertinoLocalizations.delegate),
      isTrue,
    );
    expect(
      app.localizationsDelegates?.contains(GlobalWidgetsLocalizations.delegate),
      isTrue,
    );
    expect(
      app.localeResolutionCallback
          ?.call(const Locale('fr'), app.supportedLocales),
      const Locale('ar'),
    );
  });
}

class _NoopServerConfig extends ServerConfigNotifier {
  @override
  Future<void> load() async {}
}

class _NoopStartupPage extends StartupPageNotifier {
  @override
  Future<void> load() async {}
}

class _NoopAuthNotifier extends AuthNotifier {
  _NoopAuthNotifier() : super(AuthRepository());

  @override
  Future<void> checkAuth() async {}
}
