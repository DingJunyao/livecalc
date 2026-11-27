import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:com_a4ding_livecalc/core/layout/shell_chrome.dart';
import 'package:com_a4ding_livecalc/core/router/app_router.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';

GoRouter _router({String initial = '/home'}) {
  return GoRouter(
    initialLocation: initial,
    routes: [
      ShellRoute(
        builder: (_, __, child) => ScaffoldWithNavBar(child: child),
        routes: [
          GoRoute(
              path: '/home',
              builder: (_, __) => const Scaffold(body: Text('推荐页'))),
          GoRoute(
              path: '/prices',
              builder: (_, __) => const Scaffold(body: Text('计价页'))),
          GoRoute(
              path: '/prices/record',
              builder: (_, __) => Scaffold(
                  appBar: AppBar(leading: const BackButton()),
                  body: const Text('新增价格记录页'))),
          GoRoute(
              path: '/recipes',
              builder: (_, __) => const Scaffold(body: Text('菜谱页'))),
          GoRoute(
              path: '/recipes/123',
              builder: (_, __) => const Scaffold(body: Text('菜谱详情页'))),
          GoRoute(
              path: '/ingredients',
              builder: (_, __) => const Scaffold(body: Text('原料页'))),
          GoRoute(
              path: '/products',
              builder: (_, __) => const Scaffold(body: Text('商品页'))),
          GoRoute(
              path: '/products/new',
              builder: (_, __) => const Scaffold(body: Text('新增商品页'))),
          // 键盘内边距探针：全屏表单路由（壳层隐藏底栏），正文高度可测量。
          GoRoute(
              path: '/products/1/edit',
              builder: (_, __) => const _KeyboardProbePage()),
          GoRoute(
              path: '/merchants',
              builder: (_, __) => const Scaffold(body: Text('商家页'))),
          GoRoute(
              path: '/profile',
              builder: (_, __) => const Scaffold(body: Text('我的页'))),
          GoRoute(
              path: '/input',
              builder: (_, __) => const _InputPage()),
          GoRoute(
              path: '/publishing',
              builder: (_, __) => const _PublishingPage()),
        ],
      ),
    ],
  );
}

/// 竖条工具栏测试桩页：竖条模式下把「新增/筛选」发布给壳层，并隐藏自己的
/// AppBar 动作与 FAB（与真实页面的接入方式一致）。
class _PublishingPage extends StatelessWidget {
  const _PublishingPage();

  @override
  Widget build(BuildContext context) {
    final rail = context.shellRailMode;
    if (rail) {
      context.publishShellActions(
        primary: ShellAction(
          icon: Icons.add,
          label: '新增',
          onPressed: () {},
        ),
        actions: [
          ShellAction(icon: Icons.tune, label: '筛选', onPressed: () {}),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('发布页'),
        actions: rail
            ? const []
            : const [IconButton(icon: Icon(Icons.tune), onPressed: null)],
      ),
      floatingActionButton:
          rail ? null : FloatingActionButton(onPressed: () {}),
      body: const Center(child: Text('发布页正文')),
    );
  }
}

/// 键盘内边距探针：把页面正文可用高度记录下来，供「键盘只扣一次」的回归测试断言。
double? _probeBodyHeight;

class _KeyboardProbePage extends StatelessWidget {
  const _KeyboardProbePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('表单页')),
      body: LayoutBuilder(builder: (context, constraints) {
        _probeBodyHeight = constraints.maxHeight;
        return const SizedBox.expand();
      }),
    );
  }
}

/// 树形恒定测试用的输入桩页：TextField 内容随 State 存续。
class _InputPage extends StatefulWidget {
  const _InputPage();

  @override
  State<_InputPage> createState() => _InputPageState();
}

class _InputPageState extends State<_InputPage> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TextField(controller: _controller),
    );
  }
}

void main() {
  Future<void> pump(
    WidgetTester tester, {
    String initial = '/home',
    Locale locale = const Locale('zh', 'CN'),
    Size size = const Size(400, 800),
    FakeViewPadding systemPadding = FakeViewPadding.zero,
    FakeViewPadding viewInsets = FakeViewPadding.zero,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = systemPadding;
    tester.view.viewPadding = systemPadding;
    tester.view.viewInsets = viewInsets;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp.router(
        routerConfig: _router(initial: initial),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
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
    expect(
        find.byIcon(Icons.receipt_long, skipOffstage: false), findsOneWidget);

    // 返回后落在计价页
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('计价页'), findsOneWidget);
    expect(find.byIcon(Icons.receipt_long), findsOneWidget);
  });

  testWidgets('表单页（/products/new）隐藏底栏 tab，避免误触丢失填写内容', (tester) async {
    await pump(tester, initial: '/products/new');

    expect(find.text('新增商品页'), findsOneWidget);
    expect(find.byKey(const ValueKey('tab-计价')), findsNothing);
    expect(find.text('更多'), findsNothing);
  });

  testWidgets('表单页（/products/new）在宽屏下也隐藏侧栏 tab', (tester) async {
    await pump(
      tester,
      initial: '/products/new',
      size: const Size(900, 1200),
    );

    expect(find.text('新增商品页'), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('弹键盘时页面正文只扣一次键盘高度（不出现大片空白）', (tester) async {
    const keyboard = 329.0;
    _probeBodyHeight = null;
    await pump(
      tester,
      initial: '/products/1/edit',
      size: const Size(390, 844),
      viewInsets: const FakeViewPadding(bottom: keyboard),
    );

    // 壳层 Scaffold 先把 body 收缩到键盘之上（844-329=515），页面正文再扣
    // 自己的 AppBar（56）→ 459；若壳层包 MediaQuery 时把键盘内边距又带回来，
    // 内层 Scaffold 会再扣一次，正文只剩 130（等于键盘高度扣两遍）。
    expect(_probeBodyHeight, isNotNull);
    expect(_probeBodyHeight, closeTo(844 - keyboard - kToolbarHeight, 1));
  });

  testWidgets('桌面 rail 显示全部 7 项，无更多', (tester) async {
    await pump(tester, size: const Size(900, 1200));

    expect(find.byType(NavigationRail), findsOneWidget);
    for (final label in ['推荐', '计价', '菜谱', '原料', '商品', '商家', '我的']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('更多'), findsNothing);
  });

  testWidgets('桌面 rail 点击商家切换页面', (tester) async {
    await pump(tester, size: const Size(900, 1200));

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

  testWidgets('desktop navigation rail localizes shell tabs in English',
      (tester) async {
    await pump(
      tester,
      locale: const Locale('en', 'US'),
      size: const Size(900, 1200),
    );

    for (final label in ['Home', 'Prices', 'Recipes', 'Profile']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('desktop navigation rail localizes shell tabs in Arabic',
      (tester) async {
    await pump(
      tester,
      locale: const Locale('ar'),
      size: const Size(900, 1200),
    );

    for (final label in ['الرئيسية', 'الأسعار', 'الوصفات', 'الملف الشخصي']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('desktop navigation rail keeps Chinese shell labels unchanged',
      (tester) async {
    await pump(
      tester,
      locale: const Locale('zh', 'CN'),
      size: const Size(900, 1200),
    );

    for (final label in ['推荐', '计价', '菜谱', '我的']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('桌面 rail 顺序对齐 web：商品在原料前（leading 方向）', (tester) async {
    await pump(tester, size: const Size(900, 1200));

    final products = tester.getRect(find.text('商品'));
    final ingredients = tester.getRect(find.text('原料'));
    // 竖排 rail：商品项在原料项上方（web 侧栏顺序：商品→原料）
    expect(products.top, lessThan(ingredients.top));
  });

  group('iPhone Duo 折叠屏壳层（HIG 定调）', () {
    testWidgets('外屏折叠态（466×678）走尾缘竖条（trailing、图标无文字）',
        (tester) async {
      await pump(tester, initial: '/prices', size: const Size(466, 678));

      expect(find.byKey(const ValueKey('edge-rail')), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      // 底栏不出现；竖条 4 项
      expect(find.byKey(const ValueKey('tab-计价')), findsNothing);
      for (final label in ['推荐', '计价', '菜谱', '更多']) {
        expect(find.byKey(ValueKey('edge-tab-$label')), findsOneWidget);
      }
      // 竖条图标无文字：目的地语义存在（button），可见文本不存在
      final sem = tester.getSemantics(
        find.byKey(const ValueKey('edge-tab-计价')),
      );
      expect(sem.flagsCollection.isButton, isTrue);
      expect(find.text('计价'), findsNothing);
    });

    testWidgets('内屏竖屏（669×951）走标准横条（底部 tab bar，无竖条）',
        (tester) async {
      await pump(tester, initial: '/prices', size: const Size(669, 951));

      expect(find.byKey(const ValueKey('edge-rail')), findsNothing);
      expect(find.byKey(const ValueKey('tab-计价')), findsOneWidget);
    });

    testWidgets('展开竖屏（669×951）：底栏显示全部目的地（无「更多」）', (tester) async {
      await pump(tester, initial: '/prices', size: const Size(669, 951));

      for (final label in ['推荐', '计价', '菜谱', '原料', '商品', '商家', '收藏', '试算', '我的']) {
        expect(find.byKey(ValueKey('tab-$label')), findsOneWidget,
            reason: '展开竖屏底栏应包含 $label');
      }
      expect(find.byKey(const ValueKey('tab-更多')), findsNothing);
    });

    testWidgets('手机竖屏（400×800）：底栏仍是 4 个 + 更多', (tester) async {
      await pump(tester, initial: '/prices', size: const Size(400, 800));
      expect(find.byKey(const ValueKey('tab-更多')), findsOneWidget);
      expect(find.byKey(const ValueKey('tab-原料')), findsNothing);
    });

    testWidgets('内屏横屏（951×669）走尾缘竖条', (tester) async {
      await pump(tester, initial: '/prices', size: const Size(951, 669));

      expect(find.byKey(const ValueKey('edge-rail')), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('尾缘竖条点按目的地切换页面', (tester) async {
      await pump(tester, initial: '/prices', size: const Size(466, 678));

      await tester.tap(find.byKey(const ValueKey('edge-tab-菜谱')));
      await tester.pumpAndSettle();
      expect(find.text('菜谱页'), findsOneWidget);
    });

    testWidgets('无竖条信息（trait 未上报）时按完全展开处理：竖条在右缘', (tester) async {
      await pump(
        tester,
        initial: '/prices',
        size: const Size(478, 669),
        systemPadding: const FakeViewPadding(left: 84, bottom: 34),
      );

      final rail = find.byKey(const ValueKey('edge-rail'));
      expect(rail, findsOneWidget);
      // 不再用 padding 猜测侧别：默认 trailing（完全展开），避免误判左侧留白。
      expect(tester.getTopRight(rail).dx,
          moreOrLessEquals(478, epsilon: 0.5));
    });

    testWidgets('分屏左窗（trait=leading，padding 未体现）：竖条靠左缘', (tester) async {
      // 分屏左窗：UIKit trait 返回 leading，但 viewPadding 可能仍是右侧值
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.a4ding.livecalc/duo_layout'),
        (call) async => call.method == 'layoutInfo'
            ? <String, dynamic>{
                'edge': 1,
                'width': 478.0,
                'height': 669.0,
                'occlusions': [],
                'divisions': [],
              }
            : null,
      );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.a4ding.livecalc/duo_layout'),
          null,
        );
      });

      await pump(
        tester,
        initial: '/prices',
        size: const Size(478, 669),
        systemPadding: const FakeViewPadding(left: 84, bottom: 34),
      );
      await tester.pump(); // 异步查询回填
      await tester.pump();

      final rail = find.byKey(const ValueKey('edge-rail'));
      expect(tester.getTopLeft(rail).dx, moreOrLessEquals(0, epsilon: 0.5));
      final iconCenter = tester.getCenter(
        find.descendant(
          of: find.byKey(const ValueKey('edge-tab-计价')),
          matching: find.byType(Icon),
        ),
      );
      expect(iconCenter.dx, moreOrLessEquals(48, epsilon: 1.0));
    });

    testWidgets('折叠横屏（678×466，摄像头左上）：走全宽底栏、无竖条', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.a4ding.livecalc/duo_layout'),
        (call) async => call.method == 'layoutInfo'
            ? <String, dynamic>{
                'edge': 1,
                'width': 678.0,
                'height': 466.0,
                'occlusions': [
                  <String, dynamic>{
                    'x': 29.3,
                    'y': 29.3,
                    'width': 37.0,
                    'height': 37.0,
                  },
                  <String, dynamic>{
                    'x': 0.0,
                    'y': 0.0,
                    'width': 84.0,
                    'height': 82.0,
                  },
                ],
                'divisions': <dynamic>[],
              }
            : null,
      );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.a4ding.livecalc/duo_layout'),
          null,
        );
      });

      await pump(
        tester,
        initial: '/prices',
        size: const Size(678, 466),
        systemPadding: const FakeViewPadding(left: 84),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('edge-rail')), findsNothing);
      // 底栏横跨全宽（10 项）
      final tab = find.byKey(const ValueKey('tab-计价'));
      expect(tab, findsOneWidget);
      expect(tester.getRect(tab).width, lessThan(678 / 4));
    });

    testWidgets('折叠态摄像头在左下：tab 仍在底部，但整体上移让开摄像头区',
        (tester) async {
      // layoutInfo：竖条在右缘，遮挡区（摄像头）中心在屏幕下 3/4 处
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.a4ding.livecalc/duo_layout'),
        (call) async => call.method == 'layoutInfo'
            ? <String, dynamic>{
                'edge': 2,
                'width': 478.0,
                'height': 669.0,
                'occlusions': [
                  <String, dynamic>{
                    'x': 394.0,
                    'y': 560.0,
                    'width': 84.0,
                    'height': 84.0,
                  },
                ],
                'divisions': <dynamic>[],
              }
            : null,
      );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.a4ding.livecalc/duo_layout'),
          null,
        );
      });

      await pump(
        tester,
        initial: '/prices',
        size: const Size(478, 669),
        systemPadding: const FakeViewPadding(right: 84, bottom: 34),
      );
      await tester.pump();
      await tester.pump();

      // tab 仍在竖直方向的下半段（Spacer 在工具与 tab 之间）
      final recipes = tester.getCenter(
        find.byKey(const ValueKey('edge-tab-菜谱')),
      );
      expect(recipes.dy, greaterThan(669 * 0.5));
      // 但整体让开底部摄像头区（560 起）
      expect(recipes.dy, lessThan(560));
    });

    testWidgets('分屏右窗（trait=trailing）：竖条靠右缘', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.a4ding.livecalc/duo_layout'),
        (call) async => call.method == 'layoutInfo'
            ? <String, dynamic>{
                'edge': 2,
                'width': 478.0,
                'height': 669.0,
                'occlusions': [],
                'divisions': [],
              }
            : null,
      );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.a4ding.livecalc/duo_layout'),
          null,
        );
      });

      await pump(
        tester,
        initial: '/prices',
        size: const Size(478, 669),
        systemPadding: const FakeViewPadding(right: 84, bottom: 34),
      );
      await tester.pump();
      await tester.pump();

      final rail = find.byKey(const ValueKey('edge-rail'));
      expect(tester.getTopRight(rail).dx, moreOrLessEquals(478, epsilon: 0.5));
    });

    testWidgets(
        '内屏横屏真实几何（951×669、右保留条 84pt）：竖条宽 84、只有 4 个目的地、'
        '图标中心对齐系统图标列（距右缘 48pt）、尺寸 20、点按可用', (tester) async {
      // 真机探针实测：size 951×669，padding=(0,0,84,34)
      await pump(
        tester,
        initial: '/prices',
        size: const Size(951, 669),
        systemPadding: const FakeViewPadding(right: 84, bottom: 34),
      );

      final rail = find.byKey(const ValueKey('edge-rail'));
      expect(rail, findsOneWidget);
      // 竖条宽度 = 系统保留条宽度（84），不能额外内缩把内容压成 0 宽
      expect(tester.getSize(rail).width, 84);

      // 与底栏同构：只有 4 个目的地（推荐/计价/菜谱/更多）
      for (final label in ['推荐', '计价', '菜谱', '更多']) {
        expect(find.byKey(ValueKey('edge-tab-$label')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('edge-tab-原料')), findsNothing);
      expect(find.byKey(const ValueKey('edge-tab-商品')), findsNothing);

      // 图标中心对齐系统状态图标列：距右缘 48pt（像素实测；条几何中心 42 是偏的）
      final iconCenter = tester.getCenter(
        find.descendant(
          of: find.byKey(const ValueKey('edge-tab-计价')),
          matching: find.byType(Icon),
        ),
      );
      expect(iconCenter.dx, moreOrLessEquals(951 - 48, epsilon: 1.0));

      // 图标尺寸与系统 WiFi 图标一致（20）
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(const ValueKey('edge-tab-计价')),
          matching: find.byType(Icon),
        ),
      );
      expect(icon.size, 20);

      // 点按目的地可切换（SafeArea 重复内缩会让 hit 区塌陷 → 此断言会失败）
      await tester.tap(find.byKey(const ValueKey('edge-tab-菜谱')));
      await tester.pumpAndSettle();
      expect(find.text('菜谱页'), findsOneWidget);

      // 第 4 项「更多」打开底部弹层，弹层里是其余目的地
      await tester.tap(find.byKey(const ValueKey('edge-tab-更多')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('more-商品')), findsOneWidget);
      expect(find.byKey(const ValueKey('more-原料')), findsOneWidget);
    });

    testWidgets('竖条模式：页面动作进竖条（标题栏无动作、无 FAB）', (tester) async {
      await pump(tester, initial: '/publishing', size: const Size(466, 678));
      await tester.pump(); // publish 的 post-frame 通知

      expect(find.byKey(const ValueKey('edge-rail')), findsOneWidget);
      // 竖条渲染：新增（主要操作）+ 筛选，带语义标签
      expect(find.bySemanticsLabel('新增'), findsOneWidget);
      expect(find.bySemanticsLabel('筛选'), findsOneWidget);
      // 页面自身不再有 FAB / AppBar 动作（旧位置为空）
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('横条/平板模式：页面动作仍在标题栏右侧，竖条不渲染动作', (tester) async {
      await pump(tester, initial: '/publishing', size: const Size(400, 800));
      await tester.pump();

      expect(find.byKey(const ValueKey('edge-rail')), findsNothing);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.tune), findsOneWidget); // AppBar 动作
    });

    testWidgets('外屏 ↔ 内屏切换不丢输入 State（树形恒定）', (tester) async {
      await pump(tester, initial: '/input', size: const Size(466, 678));
      await tester.enterText(find.byType(TextField), '花生 300g');
      await tester.pump();
      final before = tester.element(find.byType(TextField));

      // 仅改视口（不重建路由树），模拟外屏 → 内屏竖屏切换
      tester.view.physicalSize = const Size(669, 951);
      tester.view.devicePixelRatio = 1.0;
      await tester.pump();

      expect(find.text('花生 300g'), findsOneWidget);
      expect(identical(tester.element(find.byType(TextField)), before),
          isTrue);
    });
  });
}
