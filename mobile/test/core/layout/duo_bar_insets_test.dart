import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/core/layout/vertical_bar_edge.dart';

/// 几何取自 iPhone Duo 模拟器实测日志（`flutter: DUO edge=… occlusions=[…]`），
/// 每个姿态都是系统真实上报的遮挡区。
void main() {
  group('DuoBarInsets.of：按系统遮挡区推导标题栏 / 底栏让位', () {
    test('展开竖屏 669×951：右上状态簇 144×82 → 标题栏高 82、右侧让 144、底栏全宽', () {
      final bar = DuoBarInsets.of(const DuoLayoutInfo(
        width: 669,
        height: 951,
        occlusions: [Rect.fromLTRB(525, 0, 669, 82)],
      ));
      expect(bar.toolbarHeight, 82);
      expect(bar.trailingInset, 144);
      expect(bar.leadingInset, 0);
      expect(bar.barLeadingInset, 0);
      expect(bar.barTrailingInset, 0);
      expect(bar.bottomInset, 0);
    });

    test('折叠横屏·曲边在下 678×466：右下簇 84×82 → 标题栏靠边、底栏右让 84、底部 82', () {
      final bar = DuoBarInsets.of(const DuoLayoutInfo(
        width: 678,
        height: 466,
        occlusions: [
          Rect.fromLTRB(611.7, 399.7, 648.7, 436.7), // 摄像头
          Rect.fromLTRB(594, 384, 678, 466), // 状态簇
        ],
      ));
      expect(bar.toolbarHeight, 0, reason: '顶部无系统簇，用默认标题栏高度');
      expect(bar.trailingInset, 0, reason: '标题栏按钮靠边');
      expect(bar.leadingInset, 0);
      expect(bar.barTrailingInset, 84);
      expect(bar.barLeadingInset, 0);
      expect(bar.bottomInset, 82);
    });

    test('折叠横屏·曲边在上 678×466：左上簇 174×84 → 标题栏高 84、左让 174、底栏全宽', () {
      final bar = DuoBarInsets.of(const DuoLayoutInfo(
        width: 678,
        height: 466,
        edge: VerticalBarEdge.leading,
        occlusions: [
          Rect.fromLTRB(29.3, 29.3, 66.3, 66.3), // 摄像头
          Rect.fromLTRB(0, 0, 174, 84), // 状态簇
        ],
      ));
      expect(bar.toolbarHeight, 84);
      expect(bar.leadingInset, 174);
      expect(bar.trailingInset, 0);
      expect(bar.barLeadingInset, 0);
      expect(bar.barTrailingInset, 0);
      expect(bar.bottomInset, 0);
    });

    test('折叠横屏·曲边在上（紧凑簇 84×82）：标题栏高 82、左让 84', () {
      final bar = DuoBarInsets.of(const DuoLayoutInfo(
        width: 678,
        height: 466,
        edge: VerticalBarEdge.leading,
        occlusions: [
          Rect.fromLTRB(29.3, 29.3, 66.3, 66.3),
          Rect.fromLTRB(0, 0, 84, 82),
        ],
      ));
      expect(bar.toolbarHeight, 82);
      expect(bar.leadingInset, 84);
    });

    test('过渡态细高条（82×200）不会撑高标题栏，改由侧向让位', () {
      final bar = DuoBarInsets.of(const DuoLayoutInfo(
        width: 678,
        height: 466,
        edge: VerticalBarEdge.leading,
        occlusions: [
          Rect.fromLTRB(29.3, 29.3, 66.3, 66.3),
          Rect.fromLTRB(0, 0, 82, 200),
        ],
      ));
      expect(bar.toolbarHeight, DuoBarInsets.maxToolbarHeight);
      expect(bar.leadingInset, 82);
    });

    test('镜像姿态：左下簇 → 底栏左让；右上簇 → 标题栏右让', () {
      final bottomLeft = DuoBarInsets.of(const DuoLayoutInfo(
        width: 678,
        height: 466,
        occlusions: [Rect.fromLTRB(0, 384, 84, 466)],
      ));
      expect(bottomLeft.barLeadingInset, 84);
      expect(bottomLeft.barTrailingInset, 0);
      expect(bottomLeft.bottomInset, 82);

      final topRight = DuoBarInsets.of(const DuoLayoutInfo(
        width: 678,
        height: 466,
        occlusions: [Rect.fromLTRB(504, 0, 678, 84)],
      ));
      expect(topRight.toolbarHeight, 84);
      expect(topRight.trailingInset, 174);
      expect(topRight.leadingInset, 0);
    });

    test('无遮挡区 / 尺寸未知：全部为 0（默认标题栏、全宽底栏）', () {
      expect(DuoBarInsets.of(const DuoLayoutInfo(width: 678, height: 466)),
          DuoBarInsets.none);
      expect(
        DuoBarInsets.of(const DuoLayoutInfo(
          occlusions: [Rect.fromLTRB(525, 0, 669, 82)],
        )),
        DuoBarInsets.none,
      );
    });
  });
}
