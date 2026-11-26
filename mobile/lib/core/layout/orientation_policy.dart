import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'vertical_bar_edge.dart';

/// 屏幕方向策略：**iOS 普通手机锁竖屏，平板与折叠屏（iPhone Duo）允许旋转**。
///
/// 起因：普通 iPhone 横屏时灵动岛在侧边，标题栏没有按侧边让位（Duo 那套让位逻辑
/// 不适用于普通手机）；与其为普通手机补一套横屏避让，不如按用户建议直接不旋转。
/// 其他平台（Android）保持原行为——Android 折叠屏本来就走 `displayFeatures`。
class OrientationPolicy {
  const OrientationPolicy._();

  /// 允许的屏幕方向（纯函数，便于单测）。
  ///
  /// - 非 iOS：全部方向（保持原行为）。
  /// - iOS 平板（最短边 ≥600）或折叠屏（有 Duo 系统簇 / 竖条侧别）：允许旋转。
  /// - 其余 iOS（普通手机）：仅竖屏。
  static List<DeviceOrientation> allowedOrientations({
    required bool isIOS,
    required Size size,
    DuoLayoutInfo duo = const DuoLayoutInfo(),
  }) {
    if (!isIOS) return DeviceOrientation.values;
    final shortest = math.min(size.width, size.height);
    // 折叠屏还要看屏幕比例：普通 iPhone 真机可能上报奇怪的遮挡区/侧别，
    // 只靠这些信号会把手机误解锁成可旋转。
    final foldable = isFoldableScreenShape(size) &&
        (duo.hasDuoCluster || duo.edge != VerticalBarEdge.unspecified);
    final rotatable = shortest >= 600 || foldable;
    if (rotatable) {
      return const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ];
    }
    return const [DeviceOrientation.portraitUp];
  }

  static List<DeviceOrientation>? _lastApplied;

  /// 按当前窗口尺寸 + Duo 布局信息应用方向策略（重复调用无副作用）。
  static Future<void> apply(
      {required Size size, DuoLayoutInfo duo = const DuoLayoutInfo()}) async {
    final next = allowedOrientations(
      isIOS: !kIsWeb && Platform.isIOS,
      size: size,
      duo: duo,
    );
    if (_lastApplied != null && listEquals(_lastApplied, next)) return;
    _lastApplied = next;
    if (kDebugMode) {
      debugPrint('ORIENT apply=${next.map((e) => e.name).join(',')} '
          'size=$size duo=${duo.hasDuoCluster} edge=${duo.edge}');
    }
    try {
      await SystemChrome.setPreferredOrientations(next);
    } on Object {
      // 通道不可用（无 binding 的测试 / 桌面）时忽略：这只是界面层面的偏好。
    }
  }

  /// 冷启动时用平台视图尺寸 + 原生布局信息跑一次策略。
  ///
  /// 发后即忘（不 await、不加超时）：原生通道在测试 / 冷启动瞬间可能永远不回包，
  /// 挂起一个 Timer 会让测试的 pending-timer 断言失败；拿不到信息就按「非 Duo」
  /// 处理（普通手机本就锁竖屏，无副作用），壳层后续拿到信息时会再跑一次。
  static void applyForCurrentView() {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view == null) return;
    final size = view.physicalSize / view.devicePixelRatio;
    DuoLayoutChannel().layoutInfo().then((duo) {
      apply(size: size, duo: duo);
    }).catchError((Object _) {
      // 通道不可用：按「非 Duo」处理。
    });
  }
}
