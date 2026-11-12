import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:com_a4ding_livecalc/features/calc_scope/models/calc_scope.dart';
import 'package:com_a4ding_livecalc/features/calc_scope/providers/calc_scope_provider.dart';
import 'package:com_a4ding_livecalc/features/calc_scope/repositories/calc_scope_repository.dart';
import 'package:com_a4ding_livecalc/features/calc_scope/screens/calc_scope_form_screen.dart';
import 'package:com_a4ding_livecalc/features/merchants/repositories/merchant_repository.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';

class _FakeCalcScopeRepository extends CalcScopeRepository {
  Map<String, dynamic>? lastCreated;

  @override
  Future<List<CalcScope>> listScopes() async => const [];

  @override
  Future<CalcScope> createScope(Map<String, dynamic> body) async {
    lastCreated = body;
    return CalcScope.fromJson({'id': 1, 'name': body['name'], 'region_ids': body['region_ids']});
  }
}

/// 内存地区数据：国家 100（中国）→ 省 200（河南省）→ 市 300（三门峡市）。
class _FakeRegionRepository extends MerchantRepository {
  @override
  Future<List<Map<String, dynamic>>> listRegions(
      {int? parentId, int? level}) async {
    if (parentId == null) {
      return [
        {'id': 100, 'name': '中国', 'display_name': '中国', 'level': 0},
      ];
    }
    if (parentId == 100) {
      return [
        {'id': 200, 'name': '河南省', 'display_name': '河南省', 'level': 1},
      ];
    }
    if (parentId == 200) {
      return [
        {'id': 300, 'name': '三门峡市', 'display_name': '三门峡市', 'level': 2},
      ];
    }
    return const [];
  }

  @override
  Future<Map<String, dynamic>> getRegion(int id) async => {
        'id': id,
        'name': 'x',
        'level': 2,
        'ancestors': [],
      };
}

/// 打开级联下拉并选中某项。下拉用 ValueKey('multi_region_<level>_<sel>') 定位。
Future<void> _pickRegion(
    WidgetTester tester, int level, int? previousSel, String optionText) async {
  await tester.tap(find.byKey(ValueKey('multi_region_${level}_${previousSel ?? "null"}')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text(optionText).last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Widget _host(GoRouter router, CalcScopeRepository scopeRepo) => ProviderScope(
      overrides: [
        calcScopeListProvider
            .overrideWith((ref) => CalcScopeListNotifier(scopeRepo)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );

GoRouter _routerWithFakeRegions(MerchantRepository regionRepo) => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, __) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push('/new'),
                child: const Text('打开新建'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/new',
          builder: (_, __) =>
              CalcScopeFormScreen(regionRepository: regionRepo),
        ),
      ],
    );

void main() {
  testWidgets('新建范围：填名称、选地区、保存提交 name+region_ids', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final scopeRepo = _FakeCalcScopeRepository();
    final regionRepo = _FakeRegionRepository();

    await tester.pumpWidget(_host(_routerWithFakeRegions(regionRepo), scopeRepo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('打开新建'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CalcScopeFormScreen), findsOneWidget);

    // 选地区：国家 → 省 → 市（级联逐级出现）
    await _pickRegion(tester, 0, null, '中国');
    await _pickRegion(tester, 1, null, '河南省');
    await _pickRegion(tester, 2, null, '三门峡市');
    await tester.tap(find.text('添加当前地区'));
    await tester.pump();
    expect(find.byType(InputChip), findsOneWidget);

    // 填名称 + 保存（AppBar TextButton，避免与标题同名冲突）
    await tester.enterText(
      find.widgetWithText(TextFormField, '范围名称'),
      '老家周边',
    );
    await tester.tap(find.widgetWithText(TextButton, '添加'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 1));

    expect(scopeRepo.lastCreated, isNotNull);
    expect(scopeRepo.lastCreated!['name'], '老家周边');
    expect(scopeRepo.lastCreated!['region_ids'], [300]);
    expect(find.text('打开新建'), findsOneWidget);
  });

  testWidgets('未选地区保存被拦截并提示', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final scopeRepo = _FakeCalcScopeRepository();
    final regionRepo = _FakeRegionRepository();

    await tester.pumpWidget(_host(_routerWithFakeRegions(regionRepo), scopeRepo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('打开新建'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(
      find.widgetWithText(TextFormField, '范围名称'),
      '只有名称',
    );
    await tester.tap(find.widgetWithText(TextButton, '添加'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 未选地区被拦截：未提交，且页面未退出
    expect(scopeRepo.lastCreated, isNull);
    expect(find.byType(CalcScopeFormScreen), findsOneWidget);
    expect(find.text('至少选择一个地区'), findsOneWidget);
  });
}
