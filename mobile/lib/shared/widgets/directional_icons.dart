import 'package:flutter/material.dart';

/// 方向性图标统一出口。
///
/// Flutter 自带的 [Icon] 会对 [IconData.matchTextDirection] 为 true 的图标
/// （`arrow_back` / `arrow_forward` / `chevron_left` / `chevron_right` 等）
/// 按当前 [Directionality] 自动做镜像。因此这里必须返回“正向”图标本身，
/// 不能再按 RTL 手动翻转：否则 LTR/RTL 各翻一次会互相抵消，
/// 阿拉伯语下返回/前进箭头方向会与语言方向相反。
class DirectionalIcons {
  const DirectionalIcons._();

  static IconData backArrow(BuildContext context) {
    return Icons.arrow_back;
  }

  static IconData forwardArrow(BuildContext context) {
    return Icons.arrow_forward;
  }

  /// 「进入下一页」箭头：LTR 为 ›，RTL 由 Flutter 镜像为 ‹。
  static IconData forwardChevron(BuildContext context) {
    return Icons.chevron_right;
  }

  /// 「返回上一页」箭头：LTR 为 ‹，RTL 由 Flutter 镜像为 ›。
  static IconData backChevron(BuildContext context) {
    return Icons.chevron_left;
  }

  /// 「A → B」这类流程文本箭头：RTL 下需要反向，
  /// 否则阅读顺序（右→左）会让箭头指向流程起点。
  static String flowArrow(BuildContext context) {
    return _isRtl(context) ? '\u2190' : '\u2192';
  }

  static bool _isRtl(BuildContext context) {
    return Directionality.of(context) == TextDirection.rtl;
  }
}
