import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:com_a4ding_livecalc/core/api/api_client.dart';
import 'package:com_a4ding_livecalc/core/i18n/locale_settings.dart';
import 'package:com_a4ding_livecalc/features/auth/models/user.dart';
import 'package:com_a4ding_livecalc/features/auth/providers/auth_provider.dart';
import 'package:com_a4ding_livecalc/features/auth/repositories/auth_repository.dart';
import 'package:com_a4ding_livecalc/features/profile/screens/profile_screen.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class _RecordingAdapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> _users;
  final requests = <RequestOptions>[];

  _RecordingAdapter(Iterable<Map<String, dynamic>> users)
      : _users = List.of(users);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (_users.isEmpty) {
      throw StateError('No mocked users remain.');
    }
    return ResponseBody.fromString(
      jsonEncode(_users.removeAt(0)),
      200,
      headers: {
        'Content-Type': ['application/json']
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late MockAuthRepository repository;
  late AuthNotifier notifier;

  setUp(() {
    repository = MockAuthRepository();
    notifier = AuthNotifier(repository);
    ApiClient.instance.updateBaseUrl('https://example.test');
    SharedPreferences.setMockInitialValues({});
    const storageChannel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async => null);
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null));
  });

  Future<void> pumpProfile(
    WidgetTester tester, {
    required Locale locale,
    required LocaleSettingsController localeSettings,
    required _RecordingAdapter adapter,
    required User user,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dio = ApiClient.instance.dio;
    final originalAdapter = dio.httpClientAdapter;
    dio.httpClientAdapter = adapter;
    addTearDown(() => dio.httpClientAdapter = originalAdapter);

    notifier.state = AuthState(status: AuthStatus.authenticated, user: user);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => notifier),
        localeSettingsProvider.overrideWith((ref) => localeSettings),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ProfileScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> requestBody(RequestOptions options) {
    final data = options.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return Map<String, dynamic>.from(jsonDecode(data as String) as Map);
  }

  testWidgets('language options are fixed endonyms and English sends locale',
      (tester) async {
    final localeSettings = LocaleSettingsController()
      ..update(const LocaleSettings(uiLocale: 'zh-CN'));
    final adapter = _RecordingAdapter([
      {
        'id': 1,
        'username': 'alice',
        'email': 'a@test.com',
        'locale': 'ar',
        'format_locale': 'ja-JP',
      },
    ]);
    await pumpProfile(
      tester,
      locale: const Locale('en', 'US'),
      localeSettings: localeSettings,
      adapter: adapter,
      user: const User(
        id: 1,
        username: 'alice',
        email: 'a@test.com',
        locale: 'zh-CN',
      ),
    );

    expect(find.text('Language'), findsOneWidget);
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();

    expect(find.text('中文 (中国)'), findsOneWidget);
    expect(find.text('English (United States)'), findsOneWidget);
    expect(find.text('العربية'), findsOneWidget);
    await tester.tap(find.text('English (United States)').last);
    await tester.pumpAndSettle();

    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.path, '/auth/me');
    expect(requestBody(adapter.requests.single), {'locale': 'en-US'});
    expect(localeSettings.current.uiLocale, 'ar');
    expect(localeSettings.current.formatLocale, 'ja-JP');
  });

  testWidgets('regional format offers all locales and sends exact payloads',
      (tester) async {
    final localeSettings = LocaleSettingsController()
      ..update(const LocaleSettings(uiLocale: 'en-US'));
    final adapter = _RecordingAdapter([
      {
        'id': 1,
        'username': 'alice',
        'email': 'a@test.com',
        'locale': 'en-US',
        'format_locale': 'id-ID',
      },
      {
        'id': 1,
        'username': 'alice',
        'email': 'a@test.com',
        'locale': 'en-US',
      },
    ]);
    await pumpProfile(
      tester,
      locale: const Locale('en', 'US'),
      localeSettings: localeSettings,
      adapter: adapter,
      user: const User(
        id: 1,
        username: 'alice',
        email: 'a@test.com',
        locale: 'en-US',
      ),
    );

    await tester.tap(find.text('Regional format'));
    await tester.pumpAndSettle();
    for (final option in [
      'Follow language',
      'Chinese (China)',
      'Chinese (Taiwan)',
      'English (United States)',
      'English (United Kingdom)',
      'Japanese (Japan)',
      'German (Germany)',
      'Indonesian (Indonesia)',
      'Arabic (Egypt)',
    ]) {
      expect(find.text(option), findsOneWidget);
    }

    await tester.tap(find.text('German (Germany)'));
    await tester.pumpAndSettle();
    expect(adapter.requests, hasLength(1));
    expect(requestBody(adapter.requests.first), {
      'locale': 'en-US',
      'format_locale': 'de-DE',
    });
    expect(localeSettings.current.uiLocale, 'en-US');
    expect(localeSettings.current.formatLocale, 'id-ID');

    await tester.tap(find.text('Regional format'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Follow language'));
    await tester.pumpAndSettle();
    expect(adapter.requests, hasLength(2));
    expect(requestBody(adapter.requests.last), {'locale': 'en-US'});
    expect(localeSettings.current.formatLocale, isNull);
  });

  testWidgets('Arabic profile exposes localized locale settings',
      (tester) async {
    final localeSettings = LocaleSettingsController()
      ..update(const LocaleSettings(uiLocale: 'ar'));
    final adapter = _RecordingAdapter([
      {
        'id': 1,
        'username': 'alice',
        'email': 'a@test.com',
        'locale': 'ar',
      },
    ]);
    await pumpProfile(
      tester,
      locale: const Locale('ar'),
      localeSettings: localeSettings,
      adapter: adapter,
      user: const User(
        id: 1,
        username: 'alice',
        email: 'a@test.com',
        locale: 'ar',
      ),
    );

    expect(find.text('اللغة'), findsOneWidget);
    expect(find.text('التنسيق الإقليمي'), findsOneWidget);
  });
}
