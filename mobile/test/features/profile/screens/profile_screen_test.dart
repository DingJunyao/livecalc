import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:com_a4ding_livecalc/core/api/api_client.dart';
import 'package:com_a4ding_livecalc/features/auth/models/user.dart';
import 'package:com_a4ding_livecalc/features/auth/providers/auth_provider.dart';
import 'package:com_a4ding_livecalc/features/auth/repositories/auth_repository.dart';
import 'package:com_a4ding_livecalc/features/profile/screens/profile_screen.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

/// 测试环境下真实 HTTP 会挂起：让 /currencies 请求立即失败，
/// 使默认币种对话框走本地兜底币种列表（覆盖列表文案展示）。
class _OfflineAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      message: 'offline in test',
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late AuthNotifier notifier;

  setUp(() {
    ApiClient.instance.updateBaseUrl('https://example.test');
    notifier = AuthNotifier(MockAuthRepository());
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    User user, {
    Locale locale = const Locale('zh', 'CN'),
  }) async {
    notifier.state = AuthState(status: AuthStatus.authenticated, user: user);
    await tester.pumpWidget(ProviderScope(
      overrides: [authProvider.overrideWith((ref) => notifier)],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ProfileScreen(),
      ),
    ));
  }

  testWidgets('显示昵称（nickname 优先）与邮箱', (tester) async {
    await pumpScreen(
      tester,
      const User(
        id: 1,
        username: 'alice',
        email: 'a@test.com',
        nickname: '小艾',
      ),
    );

    expect(find.text('小艾'), findsOneWidget);
    expect(find.text('a@test.com'), findsOneWidget);
    expect(find.text('alice'), findsNothing);
  });

  testWidgets('English profile shows localized settings labels',
      (tester) async {
    await pumpScreen(
      tester,
      const User(id: 1, username: 'alice', email: 'a@test.com'),
      locale: const Locale('en', 'US'),
    );

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Regional format'), findsOneWidget);
  });

  testWidgets('无昵称时显示用户名', (tester) async {
    await pumpScreen(
      tester,
      const User(id: 2, username: 'bob', email: 'b@test.com'),
    );

    expect(find.text('bob'), findsOneWidget);
  });

  testWidgets('有头像时 CircleAvatar 使用网络图，卡片可点（chevron）', (tester) async {
    await pumpScreen(
      tester,
      const User(
        id: 1,
        username: 'alice',
        email: 'a@test.com',
        avatar: 'avatars/x.png',
      ),
    );

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar).first);
    expect(avatar.foregroundImage, isA<NetworkImage>());
    expect(
      find.descendant(
        of: find.byType(Card).first,
        matching: find.byIcon(Icons.chevron_right),
      ),
      findsOneWidget,
    );
  });

  testWidgets('无头像时 CircleAvatar 显示首字母', (tester) async {
    await pumpScreen(
      tester,
      const User(id: 3, username: 'carol', email: 'c@test.com'),
    );

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar).first);
    expect(avatar.foregroundImage, isNull);
    expect(find.text('c'), findsOneWidget);
  });

  testWidgets('设置区无预算设置，单位偏好/营养目标可点', (tester) async {
    notifier.state = const AuthState(
      status: AuthStatus.authenticated,
      user: User(id: 1, username: 'alice', email: 'a@test.com'),
    );
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (_, __) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/profile/settings/unit-preferences',
          builder: (_, __) => const Scaffold(body: Text('单位偏好页')),
        ),
        GoRoute(
          path: '/profile/settings/nutrition-goals',
          builder: (_, __) => const Scaffold(body: Text('营养目标页')),
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [authProvider.overrideWith((ref) => notifier)],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('预算设置'), findsNothing);
    expect(find.text('单位偏好'), findsOneWidget);
    expect(find.text('营养目标'), findsOneWidget);

    await tester.tap(find.text('单位偏好'));
    await tester.pumpAndSettle();
    expect(find.text('单位偏好页'), findsOneWidget);
  });

  testWidgets('启动时起始页：默认推荐，选计价后更新并持久化', (tester) async {
    SharedPreferences.setMockInitialValues({});
    notifier.state = const AuthState(
      status: AuthStatus.authenticated,
      user: User(id: 1, username: 'alice', email: 'a@test.com'),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [authProvider.overrideWith((ref) => notifier)],
      child: const MaterialApp(
        locale: Locale('zh', 'CN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProfileScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    // 设置区出现「启动时起始页」，trailing 显示当前值「推荐」
    expect(find.text('启动时起始页'), findsOneWidget);
    expect(find.text('推荐'), findsOneWidget);

    // 打开对话框，三个选项都在
    await tester.tap(find.text('启动时起始页'));
    await tester.pumpAndSettle();
    expect(find.text('计价'), findsOneWidget);
    expect(find.text('菜谱'), findsOneWidget);

    // 选「计价」→ 对话框关闭 → trailing 更新
    await tester.tap(find.text('计价'));
    await tester.pumpAndSettle();
    expect(find.text('启动时起始页'), findsOneWidget);
    expect(find.text('推荐'), findsNothing);
    expect(find.text('计价'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('startup_page'), 'prices');
  });

  testWidgets('默认计算范围对话框：省份/城市/区县表述统一', (tester) async {
    notifier.state = const AuthState(
      status: AuthStatus.authenticated,
      user: User(id: 1, username: 'alice', email: 'a@test.com'),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [authProvider.overrideWith((ref) => notifier)],
      child: const MaterialApp(
        locale: Locale('zh', 'CN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProfileScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('默认计算范围'));
    await tester.pumpAndSettle();

    // 与商家维护页「国家/地区、省份、城市、区县」表述一致，不再用省级/地级/县级
    expect(find.text('省份'), findsOneWidget);
    expect(find.text('城市'), findsOneWidget);
    expect(find.text('区县'), findsOneWidget);
    expect(find.text('省级'), findsNothing);
    expect(find.text('地级'), findsNothing);
    expect(find.text('县级'), findsNothing);
  });

  testWidgets('默认币种对话框：列表显示「名称 代码」', (tester) async {
    notifier.state = const AuthState(
      status: AuthStatus.authenticated,
      user: User(id: 1, username: 'alice', email: 'a@test.com'),
    );
    // AuthInterceptor 会在测试环境挂起于 secure storage 平台通道：
    // mock 通道返回 null，让请求继续走到 offline adapter 并快速失败。
    const storageChannel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async => null);
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null));
    // 让 /currencies 请求立即失败，走兜底列表
    final dio = ApiClient.instance.dio;
    final originalAdapter = dio.httpClientAdapter;
    dio.httpClientAdapter = _OfflineAdapter();
    addTearDown(() => dio.httpClientAdapter = originalAdapter);
    await tester.pumpWidget(ProviderScope(
      overrides: [authProvider.overrideWith((ref) => notifier)],
      child: const MaterialApp(
        locale: Locale('zh', 'CN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProfileScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('默认币种'));
    await tester.pumpAndSettle();

    // 列表项为「全称 三字母」，不再是「符号 全称」
    expect(find.text('人民币 CNY'), findsOneWidget);
    expect(find.text('美元 USD'), findsOneWidget);
    expect(find.textContaining('¥ 人民币'), findsNothing);
  });

  testWidgets('English fallback currency names are localized', (tester) async {
    const expectedNames = {
      'CNY': 'Chinese yuan',
      'USD': 'US dollar',
      'EUR': 'Euro',
      'GBP': 'British pound',
      'JPY': 'Japanese yen',
      'HKD': 'Hong Kong dollar',
      'KRW': 'South Korean won',
      'SGD': 'Singapore dollar',
      'AUD': 'Australian dollar',
      'CAD': 'Canadian dollar',
      'TWD': 'New Taiwan dollar',
      'THB': 'Thai baht',
      'MYR': 'Malaysian ringgit',
      'VND': 'Vietnamese dong',
      'RUB': 'Russian ruble',
      'AED': 'UAE dirham',
      'BGN': 'Bulgarian lev',
      'BRL': 'Brazilian real',
      'CHF': 'Swiss franc',
      'CZK': 'Czech koruna',
      'DKK': 'Danish krone',
      'HUF': 'Hungarian forint',
      'IDR': 'Indonesian rupiah',
      'ILS': 'Israeli new shekel',
      'INR': 'Indian rupee',
      'ISK': 'Icelandic króna',
      'MXN': 'Mexican peso',
      'NOK': 'Norwegian krone',
      'NZD': 'New Zealand dollar',
      'PHP': 'Philippine peso',
      'PLN': 'Polish złoty',
      'RON': 'Romanian leu',
      'SEK': 'Swedish krona',
      'TRY': 'Turkish lira',
      'ZAR': 'South African rand',
    };

    notifier.state = const AuthState(
      status: AuthStatus.authenticated,
      user: User(id: 1, username: 'alice', email: 'a@test.com'),
    );
    const storageChannel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async => null);
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null));
    final dio = ApiClient.instance.dio;
    final originalAdapter = dio.httpClientAdapter;
    dio.httpClientAdapter = _OfflineAdapter();
    addTearDown(() => dio.httpClientAdapter = originalAdapter);

    await pumpScreen(
      tester,
      const User(id: 1, username: 'alice', email: 'a@test.com'),
      locale: const Locale('en', 'US'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Default currency'));
    await tester.pumpAndSettle();

    expectedNames.forEach((code, name) {
      expect(find.text('$name $code'), findsOneWidget);
    });
  });

  testWidgets('Arabic fallback currency names are localized', (tester) async {
    const expectedNames = {
      'CNY': 'اليوان الصيني',
      'USD': 'الدولار الأمريكي',
      'EUR': 'اليورو',
      'GBP': 'الجنيه الإسترليني',
      'JPY': 'الين الياباني',
      'HKD': 'الدولار الهونغ كونغي',
      'KRW': 'الوون الكوري الجنوبي',
      'SGD': 'الدولار السنغافوري',
      'AUD': 'الدولار الأسترالي',
      'CAD': 'الدولار الكندي',
      'TWD': 'الدولار التايواني الجديد',
      'THB': 'البات التايلاندي',
      'MYR': 'الرينغيت الماليزي',
      'VND': 'الدونغ الفيتنامي',
      'RUB': 'الروبل الروسي',
      'AED': 'الدرهم الإماراتي',
      'BGN': 'الليف البلغاري',
      'BRL': 'الريال البرازيلي',
      'CHF': 'الفرنك السويسري',
      'CZK': 'الكورونا التشيكية',
      'DKK': 'الكرون الدنماركي',
      'HUF': 'الفورنت المجري',
      'IDR': 'الروبية الإندونيسية',
      'ILS': 'الشيكل الإسرائيلي الجديد',
      'INR': 'الروبية الهندية',
      'ISK': 'الكرونة الآيسلندية',
      'MXN': 'البيزو المكسيكي',
      'NOK': 'الكرونة النرويجية',
      'NZD': 'الدولار النيوزيلندي',
      'PHP': 'البيزو الفلبيني',
      'PLN': 'الزلوتي البولندي',
      'RON': 'الليو الروماني',
      'SEK': 'الكرونا السويدية',
      'TRY': 'الليرة التركية',
      'ZAR': 'الراند الجنوب أفريقي',
    };

    notifier.state = const AuthState(
      status: AuthStatus.authenticated,
      user: User(id: 1, username: 'alice', email: 'a@test.com'),
    );
    const storageChannel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async => null);
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null));
    final dio = ApiClient.instance.dio;
    final originalAdapter = dio.httpClientAdapter;
    dio.httpClientAdapter = _OfflineAdapter();
    addTearDown(() => dio.httpClientAdapter = originalAdapter);

    await pumpScreen(
      tester,
      const User(id: 1, username: 'alice', email: 'a@test.com'),
      locale: const Locale('ar'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('العملة الافتراضية'));
    await tester.pumpAndSettle();

    expectedNames.forEach((code, name) {
      expect(find.text('$name $code'), findsOneWidget);
    });
  });
}
