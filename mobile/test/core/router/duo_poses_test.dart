import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:com_a4ding_livecalc/core/layout/shell_app_bar.dart';
import 'package:com_a4ding_livecalc/core/layout/shell_chrome.dart';
import 'package:com_a4ding_livecalc/core/router/app_router.dart';
import 'package:com_a4ding_livecalc/core/theme/app_theme.dart';
import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';
import 'package:com_a4ding_livecalc/shared/widgets/app_back_button.dart';

/// 一个 Duo 姿态的系统实测几何（遮挡区取自模拟器日志 `DUO edge=… occlusions=[…]`）。
class _Pose {
  const _Pose(this.name, this.size, this.edge, this.occlusions, this.padding);

  final String name;
  final Size size;

  /// 0 = unspecified、1 = leading、2 = trailing（通道协议）。
  final int edge;
  final List<Rect> occlusions;
  final FakeViewPadding padding;
}

const _innerPortrait = _Pose(
  '展开竖屏',
  Size(669, 951),
  0,
  [Rect.fromLTRB(525, 0, 669, 82)],
  FakeViewPadding(top: 10, right: 10, bottom: 21),
);

const _foldedClusterDown = _Pose(
  '折叠横屏·曲边在下',
  Size(678, 466),
  2,
  [
    Rect.fromLTRB(611.7, 399.7, 648.7, 436.7), // 摄像头
    Rect.fromLTRB(594, 384, 678, 466), // 系统簇
  ],
  FakeViewPadding(right: 84, bottom: 21),
);

const _foldedClusterUp = _Pose(
  '折叠横屏·曲边在上',
  Size(678, 466),
  1,
  [
    Rect.fromLTRB(29.3, 29.3, 66.3, 66.3), // 摄像头
    Rect.fromLTRB(0, 0, 174, 84), // 系统簇
  ],
  FakeViewPadding(left: 84, bottom: 21),
);

const _phonePortrait = _Pose(
  '手机竖屏',
  Size(390, 844),
  0,
  [],
  FakeViewPadding(top: 24, bottom: 21),
);

/// 切换瞬间原生还没上报布局信息（reservedRegions 未就绪）的空姿态。
const _innerPortraitNoInfo = _Pose(
  '展开竖屏·空信息',
  Size(669, 951),
  0,
  [],
  FakeViewPadding(top: 10, right: 10, bottom: 21),
);

/// 分屏左窗：竖条在左缘，系统没有上报任何遮挡区。
const _splitLeft = _Pose(
  '分屏左窗',
  Size(469, 669),
  1,
  [],
  FakeViewPadding(left: 84, bottom: 34),
);

const _innerLandscape = _Pose(
  '内屏横屏',
  Size(951, 669),
  2,
  [Rect.fromLTRB(867, 0, 951, 124)],
  FakeViewPadding(right: 84, bottom: 34),
);

/// 模拟器实测：内屏竖屏稳态是 144×82，但刚从横屏转过来时系统会先上报
/// 84×124（上一姿态的形状）1~10 秒再切换。
const _innerPortraitTallCluster = _Pose(
  '展开竖屏·过渡态状态簇',
  Size(669, 951),
  0,
  [Rect.fromLTRB(585, 0, 669, 124)],
  FakeViewPadding(top: 11, right: 10, bottom: 21),
);

void _mockDuoLayout(_Pose pose) => _mockDuoLayoutWith(() => pose);

/// [pose] 每次查询时取值，测试中途可以换姿态（模拟系统上报的变化）。
void _mockDuoLayoutWith(_Pose Function() pose) {
  const channel = MethodChannel('com.a4ding.livecalc/duo_layout');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    if (call.method != 'layoutInfo') return null;
    final current = pose();
    return <String, dynamic>{
      'edge': current.edge,
      'width': current.size.width,
      'height': current.size.height,
      'occlusions': [
        for (final r in current.occlusions)
          <String, dynamic>{
            'x': r.left,
            'y': r.top,
            'width': r.width,
            'height': r.height,
          },
      ],
      'divisions': <dynamic>[],
    };
  });
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}

/// 首页：两个入口分别 push「显式返回键」与「自动返回键」的详情页。
class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ElevatedButton(
            key: const Key('go-detail'),
            onPressed: () => context.push('/detail'),
            child: const Text('进详情'),
          ),
          ElevatedButton(
            key: const Key('go-detail-auto'),
            onPressed: () => context.push('/detail-auto'),
            child: const Text('进自动返回详情'),
          ),
        ],
      ),
    );
  }
}

GoRouter _router(ShellOverlayInsets insets, String initial) => GoRouter(
      initialLocation: initial,
      routes: [
        ShellRoute(
          builder: (_, __, child) =>
              ScaffoldWithNavBar(child: child, overlayInsets: insets),
          routes: [
            GoRoute(path: '/home', builder: (_, __) => const _HomePage()),
            GoRoute(
              path: '/detail',
              builder: (_, __) => const _DetailPage(explicitBack: true),
            ),
            GoRoute(
              path: '/detail-auto',
              builder: (_, __) => const _DetailPage(explicitBack: false),
            ),
            GoRoute(path: '/products', builder: (_, __) => const _ListPage()),
            GoRoute(path: '/pub', builder: (_, __) => const _PubPage()),
            GoRoute(
              path: '/analysis',
              builder: (_, __) => const _PlainPage(),
            ),
            GoRoute(
              path: '/sheet',
              builder: (_, __) => const _SheetPage(),
            ),
            // 整页表单路由：壳层隐藏底栏
            GoRoute(
              path: '/ingredients/new',
              builder: (_, __) => const _SheetPage(),
            ),
          ],
        ),
      ],
    );

/// 带「返回 + 3 个动作」标题栏的详情页：竖条模式下把动作发布给壳层（与真实页面同构）。
/// [explicitBack] = false 时走 AppBar 的自动返回键。
class _DetailPage extends StatelessWidget {
  const _DetailPage({required this.explicitBack});

  final bool explicitBack;

  @override
  Widget build(BuildContext context) {
    final rail = context.shellRailMode;
    if (rail) {
      context.publishShellActions(actions: [
        ShellAction(icon: Icons.favorite, label: '收藏', onPressed: () {}),
        ShellAction(icon: Icons.analytics, label: '分析', onPressed: () {}),
        ShellAction(icon: Icons.more_vert, label: '更多', onPressed: () {}),
      ]);
    }
    return Scaffold(
      appBar: ShellAppBar(
        leading: explicitBack ? const AppBackButton() : null,
        title: const Text('详情'),
        actions: rail
            ? const []
            : [
                IconButton(icon: const Icon(Icons.favorite), onPressed: () {}),
                IconButton(icon: const Icon(Icons.analytics), onPressed: () {}),
                IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
              ],
      ),
      body: Center(
        child: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('go-analysis'),
            onPressed: () => context.push('/analysis'),
            child: const Text('去分析'),
          ),
        ),
      ),
    );
  }
}

/// 宽底栏下的一级目的地列表页（商品/原料/收藏等）：tab 根页不显示返回键。
class _ListPage extends StatelessWidget {
  const _ListPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ShellAppBar(
        title: const Text('商品'),
        leading: context.shellTabRoot ? null : const AppBackButton(),
      ),
      body: const SizedBox.expand(),
    );
  }
}

/// 会向竖条发布「新增 + 一个动作」的页面（无返回键，模拟 tab 根页）。
class _PubPage extends StatelessWidget {
  const _PubPage();

  @override
  Widget build(BuildContext context) {
    if (context.shellRailMode) {
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
      appBar: ShellAppBar(title: const Text('发布页')),
      body: const SizedBox.expand(),
    );
  }
}

/// 不发布任何竖条动作的页面（模拟菜谱分析页）：竖条不应显示上一页的按钮。
class _PlainPage extends StatelessWidget {
  const _PlainPage();

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: ShellAppBar(title: const Text('分析')),
      body: const SizedBox.expand());
}

/// 打开一个普通底部弹层的页面。弹层内容自己负责底部安全区（与 App 内弹层一致：
/// Flutter 的 modal sheet 只让顶部与左右，底部由内容决定）。
class _SheetPage extends StatelessWidget {
  const _SheetPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ShellAppBar(title: const Text('弹层页')),
      body: Center(
        child: ElevatedButton(
          key: const Key('open-sheet'),
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            builder: (_) => const SafeArea(
              top: false,
              left: false,
              right: false,
              child: SizedBox(
                key: Key('sheet-body'),
                height: 120,
                child: ColoredBox(color: Colors.red),
              ),
            ),
          ),
          child: const Text('打开弹层'),
        ),
      ),
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Pose pose, {
  String initial = '/home',
  _Pose Function()? poseSource,
}) async {
  _mockDuoLayoutWith(poseSource ?? () => pose);
  tester.view.physicalSize = pose.size;
  tester.view.devicePixelRatio = 1.0;
  tester.view.padding = pose.padding;
  tester.view.viewPadding = pose.padding;
  addTearDown(tester.view.reset);
  final insets = ShellOverlayInsets();
  addTearDown(insets.dispose);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        routerConfig: _router(insets, initial),
        theme: AppTheme.lightTheme,
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // 与正式 App 相同：浮层安全区在 Navigator 之上统一接管。
        builder: (context, child) =>
            ShellOverlayInsetsScope(insets: insets, child: child!),
      ),
    ),
  );
  // 通道异步回填 + 浮层信号的帧末应用
  await tester.pumpAndSettle();
  await tester.pump();
}

Future<void> _tapAndSettle(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.pump();
}

/// 从首页 push 进详情：这样才有可返回的路由（自动返回键 / 竖条返回才出现）。
Future<void> _openDetail(WidgetTester tester, {bool auto = false}) =>
    _tapAndSettle(tester, Key(auto ? 'go-detail-auto' : 'go-detail'));

Future<void> _openSheet(WidgetTester tester) =>
    _tapAndSettle(tester, const Key('open-sheet'));

Finder get _appBar => find.byType(AppBar);

Finder _inAppBar(Finder matching) =>
    find.descendant(of: _appBar, matching: matching);

/// 标题栏里某个图标所在按钮（IconButton，48 宽命中区）的矩形。
Rect _buttonRect(WidgetTester tester, IconData icon) => tester.getRect(
      find.ancestor(
        of: _inAppBar(find.byIcon(icon)),
        matching: find.byType(IconButton),
      ),
    );

/// [icon] 右缘到屏幕右缘的距离。
double _trailingGap(WidgetTester tester, IconData icon) =>
    tester.view.physicalSize.width -
    tester.getTopRight(_inAppBar(find.byIcon(icon))).dx;

void main() {
  group('iPhone Duo 横条模式的标题栏 / 底栏（系统实测几何）', () {
    testWidgets('展开竖屏：标题栏与状态簇底边平齐（82）、右侧按钮排在状态簇左边、贴顶', (tester) async {
      await _pump(tester, _innerPortrait, initial: '/detail');

      // 状态簇 Rect(525, 0, 669, 82)：标题栏高度 = 簇底边，顶到屏幕上沿
      expect(tester.getSize(_appBar).height, 82);
      expect(tester.getTopLeft(_appBar).dy, 0);

      // 右侧动作整体让到 x = 525 左边，不再被时间 / 电量盖住：
      // 末项按钮右缘距屏幕右缘 144 + 8
      expect(669 - _buttonRect(tester, Icons.more_vert).right, 144 + 8);
      // 三个动作仍在标题栏里（横条模式不走竖条）
      expect(_inAppBar(find.byType(IconButton)), findsNWidgets(4));

      // 返回键：leading 宽 64 → 图标离左缘 20（默认 16）
      expect(
          tester.getTopLeft(_inAppBar(find.byIcon(Icons.arrow_back))).dx, 20);

      // 文本 / 图标与系统状态图标同一条光轴：垂直中心 48（簇高 82 的几何中心是 41）
      expect(tester.getCenter(find.text('详情')).dy,
          moreOrLessEquals(48, epsilon: 0.5));
      expect(tester.getCenter(_inAppBar(find.byIcon(Icons.more_vert))).dy,
          moreOrLessEquals(48, epsilon: 0.5));
      expect(tester.getCenter(_inAppBar(find.byIcon(Icons.arrow_back))).dy,
          moreOrLessEquals(48, epsilon: 0.5));

      // 底栏全宽 10 项
      expect(tester.getTopRight(find.byKey(const ValueKey('tab-我的'))).dx,
          moreOrLessEquals(669, epsilon: 0.5));
    });

    testWidgets('状态簇形状变化（旋转后先报上一姿态的形状）：标题栏平滑过渡，不瞬跳', (tester) async {
      var current = _innerPortrait;
      await _pump(tester, _innerPortrait,
          initial: '/detail', poseSource: () => current);
      expect(tester.getSize(_appBar).height, 82);

      // 系统改报过渡态 84×124（高度被上限夹到 96）；metrics 变化触发壳层重查
      current = _innerPortraitTallCluster;
      tester.view.padding = _innerPortraitTallCluster.padding;
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      final mid = tester.getSize(_appBar).height;
      expect(mid, greaterThan(82), reason: '已经在过渡');
      expect(mid, lessThan(96), reason: '还没跳到终值');

      await tester.pumpAndSettle();
      expect(tester.getSize(_appBar).height, 96);
      // 动作整体让到 x = 585 左边
      expect(669 - _buttonRect(tester, Icons.more_vert).right, 84 + 8);
    });

    testWidgets('折叠横屏展开成竖屏、某一帧原生返回空信息：标题栏不往下掉（仍贴顶）', (tester) async {
      var current = _foldedClusterDown;
      await _pump(tester, _foldedClusterDown,
          initial: '/detail', poseSource: () => current);
      expect(tester.getTopLeft(_appBar).dy, 0);

      // 展开：尺寸变竖屏，但这一帧 native 返回空（无 edge、无 occlusions）
      current = _innerPortraitNoInfo;
      tester.view.physicalSize = _innerPortraitNoInfo.size;
      tester.view.padding = _innerPortraitNoInfo.padding;
      tester.view.viewPadding = _innerPortraitNoInfo.padding;
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      // 已见过 Duo：顶部内边距仍移除，标题栏贴顶（此前会把系统 top padding 加回来，
      // 标题栏整条掉到状态簇下面）
      expect(tester.getTopLeft(_appBar).dy, 0);
      expect(tester.getTopLeft(find.text('详情')).dy, lessThan(56));

      // 按钮仍要给状态簇让位：标题栏高度 = 簇底边 82，末项按钮距右缘 144+8，
      // 文本垂直中心在状态图标光轴 48（此前这一帧会退化成 56 高、按钮贴边）
      await tester.pumpAndSettle();
      expect(tester.getSize(_appBar).height, 82);
      expect(669 - _buttonRect(tester, Icons.more_vert).right, 144 + 8);
      expect(tester.getCenter(find.text('详情')).dy,
          moreOrLessEquals(48, epsilon: 0.5));
    });

    testWidgets('展开竖屏：详情页返回键可点，回到上一页', (tester) async {
      await _pump(tester, _innerPortrait);
      await _openDetail(tester);
      expect(find.text('详情'), findsOneWidget);

      await tester.tap(_inAppBar(find.byIcon(Icons.arrow_back)));
      await tester.pumpAndSettle();
      expect(find.text('详情'), findsNothing);
      expect(find.byKey(const Key('go-detail')), findsOneWidget);
    });

    testWidgets('折叠横屏·曲边在下：标题栏按钮靠边，底栏让开右下摄像头 / 系统簇', (tester) async {
      await _pump(tester, _foldedClusterDown, initial: '/detail');

      // 顶部没有系统簇：默认标题栏高度，动作贴到右边（此前被安全区 + 主题叠了两层 84）
      expect(tester.getSize(_appBar).height, 56);
      // 图标右缘 = 8（动作区间距）+ 12（按钮内边距）
      expect(_trailingGap(tester, Icons.more_vert), 8 + 12);

      // 底栏：左侧照常贴边，右侧让开 Rect(594, 384, 678, 466)
      expect(tester.getTopLeft(find.byKey(const ValueKey('tab-推荐'))).dx, 0);
      expect(tester.getTopRight(find.byKey(const ValueKey('tab-我的'))).dx,
          moreOrLessEquals(594, epsilon: 0.5));
    });

    testWidgets('折叠横屏·曲边在上：标题栏与系统簇平齐（84）、返回键排到簇右边，底栏全宽不变', (tester) async {
      await _pump(tester, _foldedClusterUp, initial: '/detail');

      expect(tester.getSize(_appBar).height, 84);
      // 系统簇 Rect(0, 0, 174, 84)：返回键图标在 x = 174 右边（leading 区 238 宽，键靠尾端）
      expect(tester.getTopLeft(_inAppBar(find.byIcon(Icons.arrow_back))).dx,
          greaterThanOrEqualTo(174));
      // 右侧无系统簇：动作靠边
      expect(_trailingGap(tester, Icons.more_vert), 8 + 12);

      // 底栏按钮位置不变：全宽
      expect(tester.getTopLeft(find.byKey(const ValueKey('tab-推荐'))).dx, 0);
      expect(tester.getTopRight(find.byKey(const ValueKey('tab-我的'))).dx,
          moreOrLessEquals(678, epsilon: 0.5));
    });

    testWidgets('折叠横屏·曲边在上：自动返回键同样排到系统簇右边', (tester) async {
      await _pump(tester, _foldedClusterUp);
      await _openDetail(tester, auto: true);

      expect(tester.getTopLeft(_inAppBar(find.byIcon(Icons.arrow_back))).dx,
          greaterThanOrEqualTo(174));
    });

    testWidgets('折叠横屏·曲边在下：有底栏时弹层铺满、底部只让 home indicator', (tester) async {
      await _pump(tester, _foldedClusterDown, initial: '/sheet');
      await _openSheet(tester);

      final sheet = tester.getRect(find.byType(BottomSheet));
      expect(sheet.left, 0, reason: '弹层左侧贴边');
      expect(sheet.right, 678, reason: '弹层右侧不留系统条空白');
      // 弹层挂在壳层导航上：位于底栏之上；底部簇已由底栏在水平方向让开，
      // 弹层不需要再抬高（只让 home indicator）。
      final navTop = tester.getTopLeft(find.byKey(const ValueKey('tab-推荐'))).dy;
      expect(sheet.bottom, lessThanOrEqualTo(navTop));
      expect(
        tester.getBottomLeft(find.byKey(const Key('sheet-body'))).dy,
        moreOrLessEquals(sheet.bottom - 21, epsilon: 0.5),
      );
    });

    testWidgets('折叠横屏·曲边在下：整页表单（无底栏）的弹层抬到底部系统簇之上', (tester) async {
      await _pump(tester, _foldedClusterDown, initial: '/ingredients/new');
      expect(find.byKey(const ValueKey('tab-推荐')), findsNothing);
      await _openSheet(tester);

      expect(tester.getRect(find.byType(BottomSheet)).right, 678);
      expect(tester.getBottomLeft(find.byKey(const Key('sheet-body'))).dy,
          lessThanOrEqualTo(384),
          reason: '弹层内容底边在系统簇（Rect.fromLTRB(594, 384, 678, 466)）之上');
    });
  });

  group('宽底栏（展开竖屏 / 折叠横屏）的 tab 根页不显示返回键', () {
    testWidgets('展开竖屏（669×951）：商品列表没有返回键', (tester) async {
      await _pump(tester, _innerPortrait, initial: '/products');
      expect(tester.getSize(_appBar).height, 82, reason: '仍是 Duo 标题栏');
      expect(_inAppBar(find.byIcon(Icons.arrow_back)), findsNothing);
      expect(_inAppBar(find.byType(IconButton)), findsNothing);
    });

    testWidgets('折叠横屏（678×466）：商品列表没有返回键', (tester) async {
      await _pump(tester, _foldedClusterDown, initial: '/products');
      expect(_inAppBar(find.byIcon(Icons.arrow_back)), findsNothing);
      expect(_inAppBar(find.byType(IconButton)), findsNothing);
    });

    testWidgets('手机竖屏（390×844，底栏 4 项 + 更多）：保留返回键', (tester) async {
      await _pump(tester, _phonePortrait, initial: '/products');
      expect(_inAppBar(find.byIcon(Icons.arrow_back)), findsOneWidget);
    });
  });

  group('分屏左窗（竖条在左，无遮挡区）', () {
    testWidgets('上部分按钮与下部分按钮距屏幕边缘对称（不再贴着上沿）', (tester) async {
      await _pump(tester, _splitLeft, initial: '/pub');

      final rail = find.byKey(const ValueKey('edge-rail'));
      expect(rail, findsOneWidget);
      // 竖条贴左缘、宽 84（= 系统保留条）；工具与 tab 同列居中（距左缘 48）
      expect(tester.getTopLeft(rail).dx, 0);
      expect(tester.getSize(rail).width, 84);

      final primaryIcon = find.descendant(
        of: rail,
        matching: find.byIcon(Icons.add),
      );
      expect(primaryIcon, findsOneWidget);
      expect(
          tester.getCenter(primaryIcon).dx, moreOrLessEquals(48, epsilon: 1));
      // 顶部没有遮挡区：工具按底部 home indicator 的距离（34）让开上沿
      expect(tester.getRect(primaryIcon).top, greaterThanOrEqualTo(34));

      // 下部分（最后一个 tab）仍贴底、只让 home indicator（每项外层还有 2pt）
      final tab = find.byKey(const ValueKey('edge-tab-更多'));
      expect(tester.getBottomLeft(tab).dy,
          moreOrLessEquals(669 - 34 - 2, epsilon: 0.5));
      // 两者横向同列
      final tabIcon = find.descendant(of: tab, matching: find.byType(Icon));
      expect(tester.getCenter(tabIcon).dx,
          moreOrLessEquals(tester.getCenter(primaryIcon).dx, epsilon: 0.5));
    });
  });

  group('iPhone Duo 竖条模式（内屏横屏 951×669）', () {
    testWidgets('标题栏上没有任何按钮（返回 / 动作全在竖条里），标题在内容区居中', (tester) async {
      await _pump(tester, _innerLandscape);
      await _openDetail(tester);

      final rail = find.byKey(const ValueKey('edge-rail'));
      expect(rail, findsOneWidget);
      // 标题栏内：无 IconButton、无图标
      expect(_inAppBar(find.byType(IconButton)), findsNothing);
      expect(_inAppBar(find.byType(Icon)), findsNothing);
      expect(tester.widget<AppBar>(_appBar).leading, isNull);
      expect(tester.widget<AppBar>(_appBar).actions, isNull);

      // 动作在竖条里（3 个动作 + 返回）
      for (final icon in [
        Icons.favorite,
        Icons.analytics,
        Icons.more_vert,
        Icons.arrow_back,
      ]) {
        expect(
          find.descendant(of: rail, matching: find.byIcon(icon)),
          findsOneWidget,
          reason: '$icon 应在竖条里',
        );
      }

      // 系统条的 84pt 已由内容整体让出：标题栏不再被二次内缩，标题在内容区居中
      expect(tester.getTopRight(_appBar).dx,
          moreOrLessEquals(951 - 84, epsilon: 0.5));
      expect(tester.getCenter(find.text('详情')).dx,
          moreOrLessEquals((951 - 84) / 2, epsilon: 1));
    });

    testWidgets('下钻不发布动作的子页面：竖条里不残留上一页（详情）的按钮', (tester) async {
      await _pump(tester, _innerLandscape);
      await _openDetail(tester);
      final rail = find.byKey(const ValueKey('edge-rail'));
      expect(
        find.descendant(of: rail, matching: find.byIcon(Icons.favorite)),
        findsOneWidget,
      );

      await _tapAndSettle(tester, const Key('go-analysis'));
      expect(_inAppBar(find.byType(IconButton)), findsNothing);
      for (final icon in [Icons.favorite, Icons.analytics, Icons.more_vert]) {
        expect(
          find.descendant(of: rail, matching: find.byIcon(icon)),
          findsNothing,
          reason: '$icon 属于上一页，不应残留',
        );
      }
      // 返回上一页后，它的动作回来
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: rail, matching: find.byIcon(Icons.favorite)),
        findsOneWidget,
      );
    });

    testWidgets('自动返回键的页面：竖条模式下标题栏同样没有返回键', (tester) async {
      await _pump(tester, _innerLandscape);
      await _openDetail(tester, auto: true);

      expect(_inAppBar(find.byType(BackButton)), findsNothing);
      expect(_inAppBar(find.byType(Icon)), findsNothing);
      // 返回在竖条里
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('edge-rail')),
          matching: find.byIcon(Icons.arrow_back),
        ),
        findsOneWidget,
      );
    });

    testWidgets('底部弹层铺满内容区，右侧不再空出系统条', (tester) async {
      await _pump(tester, _innerLandscape, initial: '/sheet');
      await _openSheet(tester);

      // 弹层挂在壳层导航上：范围 = 内容区（竖条仍在右侧可用），内容区内铺满
      final contentRight = tester.getTopRight(_appBar).dx;
      expect(contentRight, moreOrLessEquals(951 - 84, epsilon: 0.5));
      final sheet = tester.getRect(find.byType(BottomSheet));
      expect(sheet.left, 0);
      expect(sheet.right, contentRight, reason: '弹层右缘贴到内容区右缘，不再空出 84pt 系统条');
    });
  });
}
