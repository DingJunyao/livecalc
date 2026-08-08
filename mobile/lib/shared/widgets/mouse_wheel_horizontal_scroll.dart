import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 桌面端鼠标滚轮水平滚动支持：把滚轮 dy 映射为水平滚动。
/// 触摸板双指横滑（dx）由 Flutter 原生支持，无需处理。
///
/// 原理：水平 Scrollable 的滚轮处理只取 dx（鼠标滚轮 dy → delta=0），
/// 不注册 PointerSignalResolver 也不滚动；事件落到外层页面垂直滚动。
/// 这里在滚动区域外包 Listener 主动注册 resolver（命中链上第一个注册者
/// 生效，此后外层页面 Scrollable 注册被忽略），消费 dy 转水平滚动。
/// 列表未溢出（maxScrollExtent=0）时不注册，滚轮交还页面垂直滚动。
/// 到边界后 jumpTo 无变化即视为已消费（不再冒泡），符合桌面横向
/// 滚动区域惯例（移出区域再滚页面）。
class MouseWheelHorizontalScroll extends StatelessWidget {
  final ScrollController controller;
  final Widget child;

  const MouseWheelHorizontalScroll({
    super.key,
    required this.controller,
    required this.child,
  });

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        event.kind != PointerDeviceKind.mouse) {
      return;
    }
    if (!controller.hasClients || controller.position.maxScrollExtent <= 0) {
      return; // 未溢出：不注册 resolver，滚轮交还外层垂直滚动
    }
    GestureBinding.instance.pointerSignalResolver
        .register(event, (e) => _handleScroll(e));
  }

  void _handleScroll(PointerSignalEvent e) {
    if (e is! PointerScrollEvent || !controller.hasClients) return;
    final next = (controller.offset + e.scrollDelta.dy)
        .clamp(0.0, controller.position.maxScrollExtent)
        .toDouble();
    if (next != controller.offset) controller.jumpTo(next);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(onPointerSignal: _handlePointerSignal, child: child);
  }
}
