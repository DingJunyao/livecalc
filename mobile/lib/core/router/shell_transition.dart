import 'package:flutter/widgets.dart';

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
