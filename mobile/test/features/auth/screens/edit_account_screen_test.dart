import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:com_a4ding_livecalc/features/auth/models/account_response.dart';
import 'package:com_a4ding_livecalc/features/auth/models/user.dart';
import 'package:com_a4ding_livecalc/features/auth/providers/auth_provider.dart';
import 'package:com_a4ding_livecalc/features/auth/repositories/auth_repository.dart';
import 'package:com_a4ding_livecalc/features/auth/screens/edit_account_screen.dart';
import 'package:com_a4ding_livecalc/features/merchants/repositories/merchant_repository.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockRegionRepo extends Mock implements MerchantRepository {}

void main() {
  late MockAuthRepository mockRepo;
  late MockRegionRepo regionRepo;
  late AuthNotifier notifier;

  setUp(() {
    mockRepo = MockAuthRepository();
    regionRepo = MockRegionRepo();
    // 地区级联数据：国家/地区 → 省份两级
    when(() => regionRepo.listRegions(
        parentId: any(named: 'parentId'), level: any(named: 'level')))
        .thenAnswer((invocation) async {
      final parentId = invocation.namedArguments[#parentId] as int?;
      final level = invocation.namedArguments[#level] as int?;
      if (parentId == null && level == 0) {
        return [
          {'id': 1, 'name': '中国'},
          {'id': 9, 'name': '美国'},
        ];
      }
      if (parentId == 1) {
        return [
          {'id': 2, 'name': '上海市'},
        ];
      }
      return const <Map<String, dynamic>>[];
    });
    notifier = AuthNotifier(mockRepo);
    notifier.state = const AuthState(
      status: AuthStatus.authenticated,
      user: User(id: 1, username: 'alice', email: 'a@test.com'),
    );
  });

  /// 通过按钮 push 编辑页，保证保存后 pop 有去处。
  /// 视口调高，避免表单（含地区级联与密码区）超出屏幕导致按钮不可见。
  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [authProvider.overrideWith((ref) => notifier)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EditAccountScreen(
                      repository: mockRepo,
                      regionRepository: regionRepo,
                    ),
                  ),
                ),
                child: const Text('进入编辑'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('进入编辑'));
    await tester.pumpAndSettle();
  }

  testWidgets('表单预填当前用户信息，显示昵称与头像区', (tester) async {
    await pumpScreen(tester);

    expect(find.text('编辑个人信息'), findsOneWidget);
    expect(find.text('点击更换头像'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'alice'),
      findsOneWidget,
    );
    expect(find.text('a@test.com'), findsOneWidget);
    // 补齐 web 用户信息编辑：地区与修改密码区块存在
    expect(find.text('所在地区'), findsOneWidget);
    expect(find.text('修改密码（可选）'), findsOneWidget);
  });

  testWidgets('改昵称保存，只传变化字段', (tester) async {
    when(() => mockRepo.updateAccount(any()))
        .thenAnswer((_) async => const UserAccountResponse(
              user: User(
                  id: 1,
                  username: 'alice',
                  email: 'a@test.com',
                  nickname: '小艾'),
            ));

    await pumpScreen(tester);

    await tester.enterText(find.widgetWithText(TextFormField, '昵称'), '小艾');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final captured =
        verify(() => mockRepo.updateAccount(captureAny())).captured;
    final body = captured.first as Map<String, dynamic>;
    expect(body, {'nickname': '小艾'});
    // 未变化的用户名/邮箱/手机/地区不传
    expect(body.containsKey('username'), false);
    expect(body.containsKey('email'), false);
    expect(notifier.state.user?.nickname, '小艾');
  });

  testWidgets('选择地区后保存携带 region_id', (tester) async {
    when(() => mockRepo.updateAccount(any()))
        .thenAnswer((_) async => const UserAccountResponse(
              user: User(
                  id: 1,
                  username: 'alice',
                  email: 'a@test.com',
                  regionId: 1),
            ));

    await pumpScreen(tester);

    // 打开国家/地区下拉并选择「中国」
    await tester.tap(find.text('请选择').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('中国'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final captured =
        verify(() => mockRepo.updateAccount(captureAny())).captured;
    final body = captured.first as Map<String, dynamic>;
    expect(body['region_id'], 1);
  });

  testWidgets('修改密码：填当前+新+确认，携带 sha256 哈希', (tester) async {
    when(() => mockRepo.updateAccount(any()))
        .thenAnswer((_) async => const UserAccountResponse(
              user: User(id: 1, username: 'alice', email: 'a@test.com'),
            ));

    await pumpScreen(tester);

    await tester.enterText(
        find.widgetWithText(TextFormField, '当前密码'), 'oldpass');
    await tester.enterText(
        find.widgetWithText(TextFormField, '新密码（至少 6 个字符）'),
        'newpass123');
    await tester.enterText(
        find.widgetWithText(TextFormField, '确认新密码'), 'newpass123');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final captured =
        verify(() => mockRepo.updateAccount(captureAny())).captured;
    final body = captured.first as Map<String, dynamic>;
    expect(
        body['current_password'],
        sha256.convert(utf8.encode('oldpass')).toString());
    expect(
        body['new_password'],
        sha256.convert(utf8.encode('newpass123')).toString());
  });

  testWidgets('密码组校验：缺当前密码/过短/两次不一致均拦截', (tester) async {
    await pumpScreen(tester);

    // 只填新密码（6 位以下）+ 确认不一致 → 三条校验同时触发
    await tester.enterText(
        find.widgetWithText(TextFormField, '新密码（至少 6 个字符）'), '123');
    await tester.enterText(
        find.widgetWithText(TextFormField, '确认新密码'), '456');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('修改密码需提供当前密码'), findsOneWidget);
    expect(find.text('新密码至少 6 个字符'), findsOneWidget);
    expect(find.text('两次输入的新密码不一致'), findsOneWidget);
    verifyNever(() => mockRepo.updateAccount(any()));
  });

  testWidgets('校验失败不发请求（用户名过短）', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.widgetWithText(TextFormField, '用户名 *'), 'ab');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('用户名长度需为 3-50 个字符'), findsOneWidget);
    verifyNever(() => mockRepo.updateAccount(any()));
  });

  testWidgets('无任何修改时提示且不发请求', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('没有需要保存的修改'), findsOneWidget);
    verifyNever(() => mockRepo.updateAccount(any()));
  });

  testWidgets('400 时显示后端 detail', (tester) async {
    when(() => mockRepo.updateAccount(any())).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/auth/me/account'),
        response: Response(
          requestOptions: RequestOptions(path: '/auth/me/account'),
          statusCode: 400,
          data: {'detail': '用户名已被占用'},
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    await pumpScreen(tester);

    await tester.enterText(
        find.widgetWithText(TextFormField, '用户名 *'), 'bob2');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('用户名已被占用'), findsOneWidget);
  });
}
