import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:com_a4ding_livecalc/features/auth/models/user.dart';
import 'package:com_a4ding_livecalc/features/auth/providers/auth_provider.dart';
import 'package:com_a4ding_livecalc/features/auth/repositories/auth_repository.dart';
import 'package:com_a4ding_livecalc/features/profile/models/unit_option.dart';
import 'package:com_a4ding_livecalc/features/profile/repositories/profile_repository.dart';
import 'package:com_a4ding_livecalc/features/profile/screens/unit_preferences_screen.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}
class MockAuthRepository extends Mock implements AuthRepository {}

const _units = [
  UnitOption(id: 3, name: '克', abbreviation: 'g', unitType: 'mass'),
  UnitOption(id: 4, name: '千克', abbreviation: 'kg', unitType: 'mass'),
  UnitOption(id: 5, name: '毫升', abbreviation: 'ml', unitType: 'volume'),
  UnitOption(id: 6, name: '个', abbreviation: '个', unitType: 'count'),
  UnitOption(id: 7, name: '米', abbreviation: 'm', unitType: 'length'),
];

User _user({UnitPreferences? prefs}) => User(
      id: 1,
      username: 'alice',
      email: 'a@test.com',
      unitPreferences: prefs,
    );

void main() {
  late MockProfileRepository mockProfile;
  late MockAuthRepository mockAuth;
  late AuthNotifier notifier;

  setUp(() {
    mockProfile = MockProfileRepository();
    mockAuth = MockAuthRepository();
    notifier = AuthNotifier(mockAuth);
    when(() => mockProfile.getUnits()).thenAnswer((_) async => _units);
  });

  Future<void> pumpScreen(WidgetTester tester, {User? user}) async {
    notifier.state = AuthState(
      status: AuthStatus.authenticated,
      user: user ?? _user(),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [authProvider.overrideWith((ref) => notifier)],
      child: MaterialApp(
        home: UnitPreferencesScreen(
          repository: mockProfile,
          authRepository: mockAuth,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// 打开指定下拉并选择文本为 [choice] 的项。
  Future<void> pick(WidgetTester tester, String label, String choice) async {
    await tester.tap(find.byKey(ValueKey(label)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(choice).last);
    await tester.pumpAndSettle();
  }

  testWidgets('加载单位列表，4 个下拉渲染且按类型过滤', (tester) async {
    await pumpScreen(tester);

    expect(find.text('能量单位'), findsOneWidget);
    expect(find.text('默认质量单位'), findsOneWidget);
    expect(find.text('默认容积单位'), findsOneWidget);
    expect(find.text('默认记价单位（含个/包/瓶）'), findsOneWidget);

    // 质量下拉只含 mass 类型
    await tester.tap(find.byKey(const ValueKey('默认质量单位')));
    await tester.pumpAndSettle();
    expect(find.text('克（g）'), findsWidgets);
    expect(find.text('毫升（ml）'), findsNothing);
    expect(find.text('米（m）'), findsNothing);
    await tester.tap(find.text('不设置').last);
    await tester.pumpAndSettle();

    // 记价下拉含 mass/volume/count，不含 length
    await tester.tap(find.byKey(const ValueKey('默认记价单位（含个/包/瓶）')));
    await tester.pumpAndSettle();
    expect(find.text('克（g）'), findsWidgets);
    expect(find.text('个'), findsWidgets);
    expect(find.text('米（m）'), findsNothing);
  });

  testWidgets('初值来自用户单位偏好', (tester) async {
    await pumpScreen(
      tester,
      user: _user(
        prefs: const UnitPreferences(
          energyUnit: 'kJ',
          massUnit: UnitPreference(id: 3, name: '克', abbreviation: 'g'),
          volumeUnit: UnitPreference(id: 5, name: '毫升', abbreviation: 'ml'),
          priceUnit: UnitPreference(id: 6, name: '个', abbreviation: '个'),
        ),
      ),
    );

    expect(find.text('千焦（kJ）'), findsOneWidget);
    expect(find.text('克（g）'), findsOneWidget);
    expect(find.text('毫升（ml）'), findsOneWidget);
    expect(find.text('个'), findsOneWidget);
  });

  testWidgets('改能量单位保存，只传变化字段', (tester) async {
    when(() => mockAuth.updateMe(any())).thenAnswer((_) async => _user(
          prefs: const UnitPreferences(energyUnit: 'kJ'),
        ));

    await pumpScreen(tester);
    await pick(tester, '能量单位', '千焦（kJ）');

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final captured = verify(() => mockAuth.updateMe(captureAny())).captured;
    expect(captured.first, {'default_energy_unit': 'kJ'});
    expect(notifier.state.user?.unitPreferences?.energyUnit, 'kJ');
  });

  testWidgets('改质量单位保存，只传质量字段', (tester) async {
    when(() => mockAuth.updateMe(any())).thenAnswer((_) async => _user());

    await pumpScreen(tester);
    await pick(tester, '默认质量单位', '千克（kg）');

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final captured = verify(() => mockAuth.updateMe(captureAny())).captured;
    expect(captured.first, {'default_mass_unit_id': 4});
  });

  testWidgets('无修改保存提示且不发请求', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('没有需要保存的修改'), findsOneWidget);
    verifyNever(() => mockAuth.updateMe(any()));
  });

  testWidgets('400 时显示后端 detail', (tester) async {
    when(() => mockAuth.updateMe(any())).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/auth/me'),
        response: Response(
          requestOptions: RequestOptions(path: '/auth/me'),
          statusCode: 400,
          data: {'detail': '无效的单位'},
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    await pumpScreen(tester);
    await pick(tester, '能量单位', '千焦（kJ）');

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('无效的单位'), findsOneWidget);
  });
}
