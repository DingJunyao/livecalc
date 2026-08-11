import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:com_a4ding_livecalc/core/router/app_router.dart';

GoRouter _router({String initial = '/home'}) {
  return GoRouter(
    initialLocation: initial,
    routes: [
      ShellRoute(
        builder: (_, __, child) => ScaffoldWithNavBar(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('推荐页'))),
          GoRoute(path: '/prices', builder: (_, __) => const Scaffold(body: Text('计价页'))),
          GoRoute(path: '/prices/record', builder: (_, __) => Scaffold(appBar: AppBar(), body: const Text('新增价格记录页'))),
          GoRoute(path: '/recipes', builder: (_, __) => const Scaffold(body: Text('菜谱页'))),
          GoRoute(path: '/recipes/123', builder: (_, __) => const Scaffold(body: Text('菜谱详情页'))),
          GoRoute(path: '/ingredients', builder: (_, __) => const Scaffold(body: Text('原料页'))),
          GoRoute(path: '/products', builder: (_, __) => const Scaffold(body: Text('商品页'))),
          GoRoute(path: '/merchants', builder: (_, __) => const Scaffold(body: Text('商家页'))),
          GoRoute(path: '/profile', builder: (_, __) => const Scaffold(body: Text('我的页'))),
        ],
      ),
    ],
  );
}

void main() {
  Future<void> pump(WidgetTester tester, {String initial = '/home'}) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp.router(routerConfig: _router(initial: initial)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('手机底栏显示 4 项，隐藏二级项', (tester) async {
    await pump(tester);

    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('计价'), findsOneWidget);
    expect(find.text('菜谱'), findsOneWidget);
    expect(find.text('更多'), findsOneWidget);
    expect(find.text('原料'), findsNothing);
    expect(find.text('商品'), findsNothing);
    expect(find.text('商家'), findsNothing);
    expect(find.text('我的'), findsNothing);
  });

  testWidgets('更多弹出二级菜单，点选切换页面', (tester) async {
    await pump(tester);

    await tester.tap(find.text('更多'));
    await tester.pumpAndSettle();
    expect(find.text('原料'), findsOneWidget);
    expect(find.text('商品'), findsOneWidget);
    expect(find.text('商家'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);

    await tester.tap(find.text('原料'));
    await tester.pumpAndSettle();
    expect(find.text('原料页'), findsOneWidget);
  });

  testWidgets('二级页（原料）时「更多」保持选中高亮', (tester) async {
    await pump(tester, initial: '/ingredients');

    final moreLabel = tester.widget<Text>(find.text('更多'));
    expect(moreLabel.style?.fontWeight, FontWeight.w600);
    // 推荐未选中（outlined 图标）
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
  });

  testWidgets('详情页（/recipes/123）时菜谱 tab 选中', (tester) async {
    await pump(tester, initial: '/recipes/123');

    expect(find.text('菜谱详情页'), findsOneWidget);
    expect(find.byIcon(Icons.restaurant), findsOneWidget); // filled 选中
    expect(find.byIcon(Icons.restaurant_outlined), findsNothing);
  });

  testWidgets('长按计价：切到计价页并打开新增记录页', (tester) async {
    await pump(tester);

    await tester.longPress(find.byKey(const ValueKey('tab-计价')));
    await tester.pumpAndSettle();

    // push('/prices/record') 打开表单页
    expect(find.text('新增价格记录页'), findsOneWidget);
    // 底层 tab 已切到计价（filled 图标选中态；底栏被覆盖 offstage，须跳过检测）
    expect(find.byIcon(Icons.receipt_long, skipOffstage: false), findsOneWidget);

    // 返回后落在计价页
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('计价页'), findsOneWidget);
    expect(find.byIcon(Icons.receipt_long), findsOneWidget);
  });

  testWidgets('桌面 rail 显示全部 7 项，无更多', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp.router(routerConfig: _router()),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    for (final label in ['推荐', '计价', '菜谱', '原料', '商品', '商家', '我的']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('更多'), findsNothing);
  });

  testWidgets('桌面 rail 点击商家切换页面', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp.router(routerConfig: _router()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('商家'));
    await tester.pumpAndSettle();
    expect(find.text('商家页'), findsOneWidget);
  });

  testWidgets('底栏项带选中语义（selected + button）', (tester) async {
    await pump(tester); // 默认 /home →「推荐」选中

    // find.text('推荐') 的最近语义祖先即 _NavItem 的 Semantics 节点。
    // 不用 matchesSemantics：节点还带 InkWell 的 tap/focus 动作与
    // isFocusable/hasSelectedState 附带标志，精确全量匹配耦合实现细节。
    // 直接断言目标标志：选中态 + 按钮角色。
    final selectedNode = tester.getSemantics(find.text('推荐'));
    expect(selectedNode.flagsCollection.isSelected, Tristate.isTrue);
    expect(selectedNode.flagsCollection.isButton, isTrue);
    // 非选中项无 selected 标志
    final unselectedNode = tester.getSemantics(find.text('计价'));
    expect(unselectedNode.flagsCollection.isSelected, Tristate.isFalse);
    expect(unselectedNode.flagsCollection.isButton, isTrue);
  });
}
