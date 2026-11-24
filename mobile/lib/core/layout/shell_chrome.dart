import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// 页面发布到壳层竖条（尾缘/左缘）的工具栏动作。
///
/// Duo 的竖条（折叠态、内屏横屏、分屏）里，页面自己的操作按钮应放在**系统状态
/// 图标下方**的同一列里，而不是页面标题栏右侧——HIG：竖条自上而下是
/// 系统状态 → 工具栏（导航控件置顶、主要操作随后）→ tab 栏。
class ShellAction {
  /// 图标动作（渲染为 44×44 的图标按钮）。
  const ShellAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  }) : child = null;

  /// 自定义控件动作（如带弹层的 CalcContextMenuButton）。
  const ShellAction.custom({required Widget this.child, required this.label})
      : icon = null,
        onPressed = null;

  final IconData? icon;
  final Widget? child;
  final String label;
  final VoidCallback? onPressed;

  bool _sameAs(ShellAction other) =>
      label == other.label &&
      icon == other.icon &&
      (child == null) == (other.child == null);
}

/// 壳层工具栏注册表：页面在 build 中 publish 自己的动作，竖条渲染它们。
///
/// 页面同时根据 [ShellChromeScope.isRailMode] 决定是否隐藏自己的 AppBar
/// actions / FAB（竖条模式下由竖条负责展示）。
///
/// **动作按「发布者路由」隔离**：转场期间上一页仍挂在 Navigator 上并会重建
/// （于是再次 publish），单一槽位会被它覆盖 → 返回上一页 / 下钻子页面后竖条残留
/// 上一页的按钮（实测：个人中心残留「新增」、单位偏好返回后残留「保存」对勾、
/// 菜谱分析页残留菜谱详情的收藏/分析/⋮）。所以每个路由各存一份，只渲染与当前
/// 路由一致的那份；切回旧页面时它的动作还在，不需要等重建。
class ShellChrome extends ChangeNotifier {
  /// 路由 → 该页发布的动作（插入顺序用于裁剪，最多保留 [maxEntries] 条）。
  final Map<String, ({List<ShellAction> actions, ShellAction? primary})>
      _entries =
      <String, ({List<ShellAction> actions, ShellAction? primary})>{};

  /// 当前路由位置（壳层通过 [bindLocation] 同步，含命令式 push 的页面）。
  String? _location;

  bool _scheduled = false;

  static const int maxEntries = 12;

  List<ShellAction> get actions => _entries[_location]?.actions ?? const [];
  ShellAction? get primary => _entries[_location]?.primary;

  /// 壳层同步当前路由（转场期间不动已存的动作，切回旧页时仍可用）。
  void bindLocation(String location) => _location = location;

  /// 页面在 build 中调用：注册**本页**动作（竖条模式下才需要调用）。
  void publish({
    required String location,
    List<ShellAction> actions = const [],
    ShellAction? primary,
  }) {
    final prev = _entries[location];
    if (prev != null) {
      // 只比结构 + 可用性（`onPressed` 是否为 null）：页面依赖 ShellChromeScope，
      // notify 会让它重建并再次 publish，比闭包/子控件身份会形成重建循环；而禁用态
      // （保存中 / 未选商家）必须能传达给竖条，所以空/非空要区分。
      final sameActions = actions.length == prev.actions.length &&
          actions.asMap().entries.every((e) {
            final old = prev.actions[e.key];
            final now = e.value;
            return now._sameAs(old) &&
                (now.onPressed == null) == (old.onPressed == null);
          });
      final samePrimary = (primary == null && prev.primary == null) ||
          (primary != null &&
              prev.primary != null &&
              primary._sameAs(prev.primary!) &&
              (primary.onPressed == null) == (prev.primary!.onPressed == null));
      if (sameActions && samePrimary) return;
    }
    _entries[location] =
        (actions: List.unmodifiable(actions), primary: primary);
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
    _scheduleNotify();
  }

  /// 清空全部（壳层不接管工具时调用，避免动作留在竖条里）。
  void clear() {
    if (_entries.isEmpty) return;
    _entries.clear();
    _scheduleNotify();
  }

  void _scheduleNotify() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      notifyListeners();
    });
  }
}

/// 系统竖条相对当前窗口所在的一侧。
enum ShellStripSide { none, leading, trailing }

/// 壳层对**浮层**（底部弹层 / 对话框 / 菜单）安全区的接管信号。
///
/// 浮层挂在 Navigator 上，拿不到壳层给页面准备的 MediaQuery：
/// - 竖条模式：竖条所在侧的系统条内边距（Duo 84pt）会让弹层空出一整条；
/// - Duo 横条模式：系统条只占摄像头所在的角，整条内缩同样让弹层空出一整条，
///   而底部簇（摄像头）会压住弹层的右下 / 左下角，需要把弹层抬到簇之上。
///
/// 壳层在 build 中声明该去掉 / 抬高什么（[schedule]），由 [ShellOverlayInsetsScope]
/// 在 Navigator 之上套一层 MediaQuery。
class ShellOverlayInsets extends ChangeNotifier {
  ShellStripSide _stripSide = ShellStripSide.none;
  bool _dropHorizontal = false;
  double _bottomFloor = 0;
  ({ShellStripSide side, bool dropHorizontal, double bottomFloor})? _pending;
  bool _scheduled = false;

  /// 竖条所在侧（该侧水平内边距去掉）；[ShellStripSide.none] = 无竖条。
  ShellStripSide get stripSide => _stripSide;

  /// 两侧水平内边距全部去掉（Duo 横条模式：系统 UI 只占一个角）。
  bool get dropHorizontal => _dropHorizontal;

  /// 底部内边距至少抬到这个高度（Duo 折叠横屏、摄像头朝下时 = 底部簇高度）。
  double get bottomFloor => _bottomFloor;

  /// 壳层在 build 中调用。本对象在 Navigator 之上，构建期间通知会抛
  /// 「markNeedsBuild called during build」，所以有变化时帧末再应用（页面侧的
  /// 同等处理由壳层直接给出，不依赖这里，浮层晚一帧无感）。
  void schedule({
    ShellStripSide stripSide = ShellStripSide.none,
    bool dropHorizontal = false,
    double bottomFloor = 0,
  }) {
    if (stripSide == _stripSide &&
        dropHorizontal == _dropHorizontal &&
        bottomFloor == _bottomFloor) {
      return;
    }
    _pending = (
      side: stripSide,
      dropHorizontal: dropHorizontal,
      bottomFloor: bottomFloor,
    );
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      final next = _pending;
      _pending = null;
      if (next == null) return;
      var changed = false;
      if (next.side != _stripSide) {
        _stripSide = next.side;
        changed = true;
      }
      if (next.dropHorizontal != _dropHorizontal) {
        _dropHorizontal = next.dropHorizontal;
        changed = true;
      }
      if (next.bottomFloor != _bottomFloor) {
        _bottomFloor = next.bottomFloor;
        changed = true;
      }
      if (changed) notifyListeners();
    });
  }
}

/// 在 `MaterialApp.router` 的 `builder` 里包住 Navigator：按 [insets] 调整
/// 整棵导航树的 `MediaQuery.padding`（浮层据此铺满 / 让开摄像头）。
class ShellOverlayInsetsScope extends StatelessWidget {
  const ShellOverlayInsetsScope({
    super.key,
    required this.insets,
    required this.child,
  });

  final ShellOverlayInsets insets;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: insets,
      child: child,
      builder: (context, child) {
        final data = MediaQuery.of(context);
        final padding = data.padding;
        // 恒定包一层 MediaQuery（不随状态增减节点，避免 Navigator 被重新挂载）；
        // 数据没变时 MediaQuery 不会通知子树。
        return MediaQuery(
          data: data.copyWith(
            padding: padding.copyWith(
              left: insets.dropHorizontal ||
                      insets.stripSide == ShellStripSide.leading
                  ? 0
                  : null,
              right: insets.dropHorizontal ||
                      insets.stripSide == ShellStripSide.trailing
                  ? 0
                  : null,
              bottom: padding.bottom < insets.bottomFloor
                  ? insets.bottomFloor
                  : null,
            ),
          ),
          child: child!,
        );
      },
    );
  }
}

/// 向下暴露 [ShellChrome] 与「当前是否竖条导航」。
class ShellChromeScope extends InheritedNotifier<ShellChrome> {
  const ShellChromeScope({
    super.key,
    required ShellChrome chrome,
    required this.isRailMode,
    this.tabRoot = false,
    required super.child,
  }) : super(notifier: chrome);

  /// 当前为竖条导航（折叠态 / 内屏横屏 / 分屏）：页面动作交给竖条渲染。
  final bool isRailMode;

  /// 当前页是**宽底栏**下的一级目的地（Duo 展开竖屏 / 折叠横屏：底栏直接列出全部
  /// 目的地，列表页本身就是 tab，没有「返回上一页」的语义）→ 页面不显示返回键。
  final bool tabRoot;

  static ShellChrome? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellChromeScope>()?.notifier;

  /// 竖条导航下页面应隐藏自己的 AppBar actions 与 FAB。
  static bool isRail(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ShellChromeScope>()
          ?.isRailMode ??
      false;

  /// 当前页是宽底栏下的一级目的地：不显示返回键。
  static bool isTabRoot(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellChromeScope>()?.tabRoot ??
      false;

  @override
  bool updateShouldNotify(ShellChromeScope oldWidget) =>
      super.updateShouldNotify(oldWidget) ||
      oldWidget.isRailMode != isRailMode ||
      oldWidget.tabRoot != tabRoot;
}

extension ShellChromeContext on BuildContext {
  /// 当前是否竖条导航（页面应隐藏 AppBar actions / FAB）。
  bool get shellRailMode => ShellChromeScope.isRail(this);

  /// 当前页是宽底栏（Duo 展开竖屏 / 折叠横屏）下的一级目的地：列表页不应再显示返回键。
  bool get shellTabRoot => ShellChromeScope.isTabRoot(this);

  /// 竖条模式下把本页动作交给壳层竖条渲染。
  void publishShellActions({
    List<ShellAction> actions = const [],
    ShellAction? primary,
  }) {
    final chrome = ShellChromeScope.maybeOf(this);
    if (chrome == null) return;
    chrome.publish(
      // 发布者路由：转场中旧页的迟到发布会被壳层丢弃（见 ShellChrome 注释）。
      location: GoRouterState.of(this).matchedLocation,
      actions: actions,
      primary: primary,
    );
  }
}
