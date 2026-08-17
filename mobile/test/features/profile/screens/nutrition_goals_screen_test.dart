import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:com_a4ding_livecalc/features/auth/models/user.dart';
import 'package:com_a4ding_livecalc/features/auth/providers/auth_provider.dart';
import 'package:com_a4ding_livecalc/features/auth/repositories/auth_repository.dart';
import 'package:com_a4ding_livecalc/features/profile/screens/nutrition_goals_screen.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockAuth;
  late AuthNotifier notifier;

  setUp(() {
    mockAuth = MockAuthRepository();
    notifier = AuthNotifier(mockAuth);
  });

  Future<void> pumpScreen(WidgetTester tester, {User? user}) async {
    notifier.state = AuthState(
      status: AuthStatus.authenticated,
      user: user ??
          const User(
            id: 1,
            username: 'alice',
            email: 'a@test.com',
            nutritionGoals: {
              'daily_calorie_target': 2000,
              'daily_protein_target': 60,
              'daily_carb_target': 300,
              'daily_fat_target': 65
            },
          ),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [authProvider.overrideWith((ref) => notifier)],
      child: MaterialApp(home: NutritionGoalsScreen(authRepository: mockAuth)),
    ));
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
  }

  testWidgets('初值渲染（kcal 默认 2000/60/300/65）', (tester) async {
    await pumpScreen(tester);

    expect(find.text('每日热量（kcal）'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '2000'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '60'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '300'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '65'), findsOneWidget);
  });

  testWidgets('kJ 偏好时热量显示 ×4.184，保存换算回 kcal', (tester) async {
    when(() => mockAuth.updateMe(any())).thenAnswer(
        (_) async => const User(id: 1, username: 'alice', email: 'a@test.com'));

    await pumpScreen(
      tester,
      user: const User(
        id: 1,
        username: 'alice',
        email: 'a@test.com',
        unitPreferences: UnitPreferences(energyUnit: 'kJ'),
      ),
    );

    // 2000 kcal → 8368 kJ
    expect(find.text('每日热量（kJ）'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '8368'), findsOneWidget);

    // 输入 4184 kJ → 存回 1000 kcal
    await tester.enterText(find.widgetWithText(TextFormField, '8368'), '4184');
    await save(tester);

    final captured = verify(() => mockAuth.updateMe(captureAny())).captured;
    final body = captured.first as Map<String, dynamic>;
    expect(body['daily_calorie_target'], 1000);
  });

  testWidgets('改蛋白质保存，4 字段全量提交', (tester) async {
    when(() => mockAuth.updateMe(any())).thenAnswer(
        (_) async => const User(id: 1, username: 'alice', email: 'a@test.com'));

    await pumpScreen(tester);
    await tester.enterText(find.widgetWithText(TextFormField, '60'), '80');
    await save(tester);

    final captured = verify(() => mockAuth.updateMe(captureAny())).captured;
    final body = captured.first as Map<String, dynamic>;
    expect(body, {
      'daily_calorie_target': 2000,
      'daily_protein_target': 80,
      'daily_carb_target': 300,
      'daily_fat_target': 65,
    });
  });

  testWidgets('热量超范围提示且不发请求', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.widgetWithText(TextFormField, '2000'), '6000');
    await save(tester);

    expect(find.text('每日热量需在 500-5000 千卡范围内'), findsOneWidget);
    verifyNever(() => mockAuth.updateMe(any()));
  });

  testWidgets('空输入存 null 清除目标', (tester) async {
    when(() => mockAuth.updateMe(any())).thenAnswer(
        (_) async => const User(id: 1, username: 'alice', email: 'a@test.com'));

    await pumpScreen(tester);
    await tester.enterText(find.widgetWithText(TextFormField, '2000'), '');
    await save(tester);

    final captured = verify(() => mockAuth.updateMe(captureAny())).captured;
    final body = captured.first as Map<String, dynamic>;
    expect(body['daily_calorie_target'], isNull);
    expect(body['daily_protein_target'], 60);
  });

  testWidgets('400 时显示后端 detail', (tester) async {
    when(() => mockAuth.updateMe(any())).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/auth/me'),
        response: Response(
          requestOptions: RequestOptions(path: '/auth/me'),
          statusCode: 400,
          data: {'detail': '目标值超出范围'},
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    await pumpScreen(tester);
    await tester.enterText(find.widgetWithText(TextFormField, '60'), '80');
    await save(tester);

    expect(find.text('目标值超出范围'), findsOneWidget);
  });
}
