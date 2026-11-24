import 'package:flutter/widgets.dart';

import '../layout/device_form.dart';

/// shell（底部 tab）切换动画的滑动起点。
///
/// LTR：切到更靠后的 tab（视觉上向右）时新页面从右侧滑入，
/// 切到更靠前的 tab 时从左侧滑入。
/// RTL：tab 的视觉顺序相反，滑动方向必须镜像，
/// 否则阿拉伯语下「下一页」会从错误的一侧进入。
Offset shellTabSlideBegin({
  required bool toEarlierTab,
  required bool isRtl,
}) {
  final fromLeft = isRtl ? !toEarlierTab : toEarlierTab;
  return Offset(fromLeft ? -1.0 : 1.0, 0.0);
}

/// 竖向导航（竖条在侧边）的页面切换起点：沿竖条方向滑动——
/// 切到更靠下的目的地面时新页面从下方滑入，切回上方时从上滑入。
Offset shellRailSlideBegin({required bool toEarlierTab}) =>
    Offset(0.0, toEarlierTab ? -1.0 : 1.0);

/// 页面切换起点：竖向导航（尾缘/左缘竖条）沿竖条方向上下滑动，
/// 横条 / 底栏 / 平板左 rail 保持左右滑动（RTL 镜像）。
Offset shellPageSlideBegin({
  required ShellMode mode,
  required bool toEarlierTab,
  required bool isRtl,
}) =>
    mode == ShellMode.edgeRail
        ? shellRailSlideBegin(toEarlierTab: toEarlierTab)
        : shellTabSlideBegin(toEarlierTab: toEarlierTab, isRtl: isRtl);
