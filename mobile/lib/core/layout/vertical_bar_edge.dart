import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show ThemeExtension;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 系统竖条所在侧（iPhone Duo）。
enum VerticalBarEdge {
  /// 无竖条 / 未知（常规 iPhone、平板、横屏未启用竖条的姿态）。
  unspecified,

  /// 竖条在 leading 侧（LTR 下即左缘）：分屏多任务中的**左窗**。
  leading,

  /// 竖条在 trailing 侧（LTR 下即右缘）：独占全屏或分屏**右窗**。
  trailing,
}

/// iPhone Duo 的布局信息（一侧竖条 + 系统遮挡区）。
///
/// - [edge]：竖条在哪一侧（分屏左窗 = leading）。
/// - [occlusions]：系统遮挡区（摄像头 / 状态簇）在本视图坐标系的矩形。折叠态
///   摄像头可能在左下或右下角，遮挡区随之落在竖条底部——导航项要放到相反一端，
///   否则会压住系统元素。
class DuoLayoutInfo {
  const DuoLayoutInfo({
    this.edge = VerticalBarEdge.unspecified,
    this.width = 0,
    this.height = 0,
    this.occlusions = const [],
    this.divisions = const [],
  });

  final VerticalBarEdge edge;
  final double width;
  final double height;
  final List<Rect> occlusions;

  /// 折叠区（半开时把显示分成两块的带状区域）；完全展开时为空。
  final List<Rect> divisions;

  /// 真正属于 Duo 的系统簇（摄像头 / 侧边状态列）。
  ///
  /// **普通 iPhone 会把整条状态栏也当作 occlusion 上报**（实测 iPhone 18 Pro
  /// 402×874：`Rect(0, 0, 402, 54)`）。若照单全收就会被误判成 Duo：页面顶部的
  /// 系统内边距被移除（标题栏跑到刘海 / 灵动岛上面）、`trailingInset` 算成整屏宽
  /// （右侧按钮被推出屏幕外）。Duo 的系统簇一定**贴在某条侧边、并且落在某个角落**
  /// （同时贴上/下边），且不会占满整宽或整高——按这个几何特征过滤。
  List<Rect> get clusters {
    // 尺寸未知时无法校验几何特征：一律当作没有 Duo 簇（宁可退回普通布局，
    // 也不能把真机上未经校验的遮挡区当成 Duo 用）。
    if (width <= 0 || height <= 0) return const [];
    return [
      for (final r in occlusions)
        if (_isSideCluster(r)) r,
    ];
  }

  /// 是否存在 Duo 系统簇（有才算 Duo 设备/姿态）。
  bool get hasDuoCluster => clusters.isNotEmpty;

  bool _isSideCluster(Rect r) {
    if (r.isEmpty) return false;
    const eps = 1.5;
    // 底部簇不一定贴死下边（home indicator 区域可能被排除），留安全区量级的容差。
    const cornerTolerance = 40.0;
    final touchesSide = r.left <= eps || r.right >= width - eps;
    final nearTopOrBottom =
        r.top <= cornerTolerance || r.bottom >= height - cornerTolerance;
    // 整条状态栏 / 整列状态条：占满某个方向，不属于 Duo 的角落簇
    final spansFullWidth = r.width >= width - eps;
    final spansFullHeight = r.height >= height - eps;
    return touchesSide &&
        nearTopOrBottom &&
        !spansFullWidth &&
        !spansFullHeight;
  }

  /// 原始遮挡区（含普通 iPhone 的整条状态栏）**不应直接用于布局**——用 [clusters]。

  /// 折叠区中心 x（横屏半展开）：用于让分栏对齐铰链而不是简单对半分。
  /// 折叠区中心 x（横屏半展开）：用于让分栏对齐铰链而不是简单对半分。
  ///
  /// 优先用 `.division` 保留区；若系统未上报（部分姿态/版本），退而用
  /// 「细高遮挡带」识别：宽度 ≤ 80pt 且高度超过屏幕 55% 的区域即折痕带。
  double? get foldX {
    if (divisions.isNotEmpty) return divisions.first.center.dx;
    if (height <= 0) return null;
    // 折痕带不贴侧边，不能用「侧边簇」过滤，用原始遮挡区。
    for (final r in occlusions) {
      if (r.height >= height * 0.55 && r.width > 0 && r.width <= 80) {
        return r.center.dx;
      }
    }
    return null;
  }

  /// 系统簇（摄像头/状态）占据到顶部的哪一行（pt）；无则 0。
  ///
  /// 竖条里的页面动作必须从这条线**下方**开始，否则会被系统状态图标挡住。
  double get topClusterInset {
    var bottom = 0.0;
    for (final r in clusters) {
      if (height > 0 && r.center.dy < height * 0.45) {
        bottom = bottom > r.bottom ? bottom : r.bottom;
      }
    }
    return bottom;
  }

  /// 系统簇是否在底部（摄像头在左下/右下）。
  bool get clusterAtBottom =>
      height > 0 && clusters.any((r) => r.center.dy > height * 0.55);

  /// 系统簇（底部摄像头/状态）从底部向上占用多少（pt）；无则 0。
  ///
  /// 竖条底部 tab 需要让开这段，避免压在摄像头区上。
  double get bottomClusterInset {
    if (height <= 0) return 0;
    var inset = 0.0;
    for (final r in clusters) {
      if (r.center.dy > height * 0.55) {
        final fromBottom = height - r.top;
        if (fromBottom > inset) inset = fromBottom;
      }
    }
    return inset;
  }
}

/// Duo「横条模式」（展开竖屏 / 折叠横屏）下，系统簇（状态图标 + 摄像头）对标题栏
/// 与底栏的让位规格，全部由系统上报的遮挡区矩形推导。
///
/// 系统给的安全区是**整条**侧边内缩（摄像头所在侧 84pt，不分上下），照搬会让标题栏、
/// 正文空出一整条；实际上系统 UI 只占摄像头所在的那个角，所以只在该角让位：
/// - 簇在**顶部**：标题栏高度与簇底边平齐、按钮排到簇的旁边；底栏保持全宽；
/// - 簇在**底部**：标题栏不再内缩（按钮靠边）；底栏与底部弹层让开该角。
///
/// 同时作为 [ThemeExtension] 挂在页面主题上（[ShellAppBar] 据此把返回键排到系统簇
/// 右边）；非 Duo 横条形态下不存在。
class DuoBarInsets extends ThemeExtension<DuoBarInsets> {
  const DuoBarInsets({
    this.toolbarHeight = 0,
    this.leadingInset = 0,
    this.trailingInset = 0,
    this.barLeadingInset = 0,
    this.barTrailingInset = 0,
    this.bottomInset = 0,
    this.contentCenterY = 0,
  });

  /// 标题栏工具区高度（与顶部系统簇底边平齐）；0 = 用默认高度。
  final double toolbarHeight;

  /// 标题栏 leading 侧需要让开的宽度（顶部簇在该侧时 > 0）。
  final double leadingInset;

  /// 标题栏 trailing 侧需要让开的宽度。
  final double trailingInset;

  /// 底栏 leading / trailing 侧需要让开的宽度（底部簇在该侧时 > 0）。
  final double barLeadingInset;
  final double barTrailingInset;

  /// 底部系统簇从屏幕底边向上占用的高度；0 = 无底部簇。
  final double bottomInset;

  /// 标题栏内容的垂直中心（pt）：与系统状态图标同一条光轴。
  ///
  /// 单行状态簇（高 ≤100，如展开竖屏 82、曲边在上 84）里系统图标与摄像头共用
  /// 实测 48pt 的光轴中心（与竖条图标列同一基准），按簇矩形几何中心（41）居中
  /// 会整体偏高 7pt；更高的簇（过渡态上报 124）取簇中心。
  final double contentCenterY;

  @override
  DuoBarInsets copyWith({
    double? toolbarHeight,
    double? leadingInset,
    double? trailingInset,
    double? barLeadingInset,
    double? barTrailingInset,
    double? bottomInset,
    double? contentCenterY,
  }) =>
      DuoBarInsets(
        toolbarHeight: toolbarHeight ?? this.toolbarHeight,
        leadingInset: leadingInset ?? this.leadingInset,
        trailingInset: trailingInset ?? this.trailingInset,
        barLeadingInset: barLeadingInset ?? this.barLeadingInset,
        barTrailingInset: barTrailingInset ?? this.barTrailingInset,
        bottomInset: bottomInset ?? this.bottomInset,
        contentCenterY: contentCenterY ?? this.contentCenterY,
      );

  @override
  DuoBarInsets lerp(ThemeExtension<DuoBarInsets>? other, double t) {
    if (other is! DuoBarInsets) return this;
    return DuoBarInsets(
      toolbarHeight: ui.lerpDouble(toolbarHeight, other.toolbarHeight, t)!,
      leadingInset: ui.lerpDouble(leadingInset, other.leadingInset, t)!,
      trailingInset: ui.lerpDouble(trailingInset, other.trailingInset, t)!,
      barLeadingInset:
          ui.lerpDouble(barLeadingInset, other.barLeadingInset, t)!,
      barTrailingInset:
          ui.lerpDouble(barTrailingInset, other.barTrailingInset, t)!,
      bottomInset: ui.lerpDouble(bottomInset, other.bottomInset, t)!,
      contentCenterY: ui.lerpDouble(contentCenterY, other.contentCenterY, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DuoBarInsets &&
      other.toolbarHeight == toolbarHeight &&
      other.leadingInset == leadingInset &&
      other.trailingInset == trailingInset &&
      other.barLeadingInset == barLeadingInset &&
      other.barTrailingInset == barTrailingInset &&
      other.bottomInset == bottomInset &&
      other.contentCenterY == contentCenterY;

  @override
  int get hashCode => Object.hash(toolbarHeight, leadingInset, trailingInset,
      barLeadingInset, barTrailingInset, bottomInset, contentCenterY);

  /// 标题栏高度上限：过渡态可能上报细高条（如 82×200），不能让它撑高标题栏，
  /// 超出部分改由侧向内缩让位。
  static const double maxToolbarHeight = 96;

  static const DuoBarInsets none = DuoBarInsets();

  factory DuoBarInsets.of(DuoLayoutInfo info) {
    final w = info.width;
    final h = info.height;
    if (w <= 0 || h <= 0) return none;
    var topBottom = 0.0;
    var topLeading = 0.0;
    var topTrailing = 0.0;
    var botLeading = 0.0;
    var botTrailing = 0.0;
    var botTop = h;
    for (final r in info.clusters) {
      if (r.isEmpty) continue;
      final top = r.center.dy < h / 2;
      final leading = r.center.dx < w / 2;
      if (top) {
        if (r.bottom > topBottom) topBottom = r.bottom;
        if (leading) {
          if (r.right > topLeading) topLeading = r.right;
        } else {
          if (w - r.left > topTrailing) topTrailing = w - r.left;
        }
      } else {
        if (leading) {
          if (r.right > botLeading) botLeading = r.right;
        } else {
          if (w - r.left > botTrailing) botTrailing = w - r.left;
        }
        if (r.top < botTop) botTop = r.top;
      }
    }
    final toolbarHeight =
        topBottom > 56 ? topBottom.clamp(56.0, maxToolbarHeight) : 0.0;
    return DuoBarInsets(
      toolbarHeight: toolbarHeight,
      contentCenterY:
          toolbarHeight == 0 ? 0 : (topBottom <= 100 ? 48.0 : topBottom / 2),
      leadingInset: topLeading,
      trailingInset: topTrailing,
      barLeadingInset: botLeading,
      barTrailingInset: botTrailing,
      bottomInset: botTop < h ? h - botTop : 0,
    );
  }
}

/// 屏幕比例是否像折叠屏 / 平板。
///
/// Duo 各姿态（外屏 466×678、内屏 669×951 / 951×669）短边/长边都 ≥0.68；
/// 普通 iPhone（iPhone 13 Pro 390×844、iPhone 18 Pro 402×874）约 0.46。
/// 用比例把普通手机整体排除在 Duo 布局之外——真机上它们上报的遮挡区形态与
/// 模拟器不同（iPhone 13 Pro 真机曾把标题栏顶到刘海下面），只靠矩形过滤不够稳。
bool isFoldableScreenShape(Size size) {
  final shortest = math.min(size.width, size.height);
  final longest = math.max(size.width, size.height);
  if (longest <= 0) return false;
  return shortest / longest >= 0.6;
}

/// 读取 UIKit 的 Duo 布局信息（`UITraitCollection.verticalBarEdge`
/// 与 `UIView.reservedRegions(of: .occlusion)`，均 iOS 27.1+）。
///
/// 分屏时系统保留条只出现在本窗口靠外的一侧（左窗 leading / 右窗 trailing），
/// 而 Flutter 的 `viewPadding` 在分屏场景不一定反映该信息，因此以 UIKit 为准。
/// 非 iOS 或低版本返回空信息（[DuoLayoutInfo] 默认值）。
class DuoLayoutChannel {
  DuoLayoutChannel({MethodChannel? channel})
      : _channel =
            channel ?? const MethodChannel('com.a4ding.livecalc/duo_layout');

  final MethodChannel _channel;

  Future<DuoLayoutInfo> layoutInfo() async {
    // 不按平台短路：非 iOS 上通道未注册，捕获 MissingPluginException 后返回
    // 空信息即可（这样 widget 测试也能 mock 通道验证侧别逻辑）。
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('layoutInfo');
      if (raw == null) return const DuoLayoutInfo();
      final edge = switch (raw['edge']) {
        1 => VerticalBarEdge.leading,
        2 => VerticalBarEdge.trailing,
        _ => VerticalBarEdge.unspecified,
      };
      List<Rect> parseRects(String key) {
        final out = <Rect>[];
        for (final item in (raw[key] as List?) ?? const []) {
          if (item is Map) {
            out.add(Rect.fromLTWH(
              (item['x'] as num?)?.toDouble() ?? 0,
              (item['y'] as num?)?.toDouble() ?? 0,
              (item['width'] as num?)?.toDouble() ?? 0,
              (item['height'] as num?)?.toDouble() ?? 0,
            ));
          }
        }
        return out;
      }

      return DuoLayoutInfo(
        edge: edge,
        width: (raw['width'] as num?)?.toDouble() ?? 0,
        height: (raw['height'] as num?)?.toDouble() ?? 0,
        occlusions: parseRects('occlusions'),
        divisions: parseRects('divisions'),
      );
    } on MissingPluginException {
      return const DuoLayoutInfo();
    } on PlatformException {
      return const DuoLayoutInfo();
    }
  }

  /// 仅取竖条侧别（保持向后兼容的轻量接口）。
  Future<VerticalBarEdge> verticalBarEdge() async => (await layoutInfo()).edge;
}

/// 向下暴露 Duo 布局信息（折叠区位置、竖条宽度），供页面做「不跨铰链」布局。
class DuoLayoutScope extends InheritedWidget {
  const DuoLayoutScope({
    super.key,
    required this.layout,
    required this.railWidth,
    required super.child,
  });

  final DuoLayoutInfo layout;

  /// 竖条占用的宽度（页面内容被内缩的量），用于把折叠区坐标换算到内容坐标。
  final double railWidth;

  static DuoLayoutInfo? infoOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DuoLayoutScope>()?.layout;

  /// 折叠区在**内容坐标系**中的 x（横屏半展开时非空）：分栏应在此处断开，
  /// 避免内容横跨铰链。
  static double? foldXOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<DuoLayoutScope>();
    final foldX = scope?.layout.foldX;
    if (scope == null || foldX == null) return null;
    final rail = scope.railWidth;
    if (rail <= 0) return foldX;
    // 竖条在左时内容整体右移，在右时内容不移动但宽度减小。
    final leftRail = scope.layout.edge == VerticalBarEdge.leading;
    return leftRail ? foldX - rail : foldX;
  }

  @override
  bool updateShouldNotify(DuoLayoutScope oldWidget) =>
      oldWidget.layout != layout || oldWidget.railWidth != railWidth;
}
