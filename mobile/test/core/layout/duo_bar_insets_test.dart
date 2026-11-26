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

  group('普通 iPhone 的整条状态栏不能被当成 Duo 簇', () {
    // 实测 iPhone 18 Pro（402×874）：reservedRegions 上报整条状态栏
    const iPhone = DuoLayoutInfo(
      width: 402,
      height: 874,
      occlusions: [Rect.fromLTRB(0, 0, 402, 54)],
    );

    test('hasDuoCluster 为假（整宽状态栏被过滤）', () {
      expect(iPhone.hasDuoCluster, isFalse);
      expect(iPhone.clusters, isEmpty);
      expect(iPhone.topClusterInset, 0);
      expect(DuoBarInsets.of(iPhone), DuoBarInsets.none);
    });

    test('Duo 的角落簇仍然保留', () {
      const duo = DuoLayoutInfo(
        width: 669,
        height: 951,
        occlusions: [Rect.fromLTRB(525, 0, 669, 82)],
      );
      expect(duo.hasDuoCluster, isTrue);
      expect(duo.clusters, hasLength(1));
      expect(DuoBarInsets.of(duo).toolbarHeight, 82);
    });

    test('横屏 iPhone 的侧边刘海（垂直居中、不贴角）也被过滤', () {
      const landscape = DuoLayoutInfo(
        width: 874,
        height: 402,
        occlusions: [Rect.fromLTRB(0, 140, 37, 262)],
      );
      expect(landscape.hasDuoCluster, isFalse);
    });
  });

  group('isFoldableScreenShape：屏幕比例闸门', () {
    test('Duo 各姿态通过', () {
      for (final size in const [
        Size(466, 678), // 外屏竖屏
        Size(678, 466), // 外屏横屏
        Size(669, 951), // 内屏竖屏
        Size(951, 669), // 内屏横屏
        Size(469, 669), // 分屏左窗
      ]) {
        expect(isFoldableScreenShape(size), isTrue, reason: '$size');
      }
    });

    test('普通 iPhone 一律不通过（含 13 Pro / 18 Pro）', () {
      for (final size in const [
        Size(390, 844), // iPhone 13 Pro
        Size(402, 874), // iPhone 18 Pro
        Size(844, 390),
        Size(375, 667), // SE
      ]) {
        expect(isFoldableScreenShape(size), isFalse, reason: '$size');
      }
    });

    test('尺寸未知不通过', () {
      expect(isFoldableScreenShape(Size.zero), isFalse);
    });
  });
}
