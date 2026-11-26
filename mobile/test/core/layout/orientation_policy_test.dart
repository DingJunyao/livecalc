import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/core/layout/orientation_policy.dart';
import 'package:com_a4ding_livecalc/core/layout/vertical_bar_edge.dart';

/// iOS 普通手机不旋转（横屏时灵动岛在侧边，标题栏没有针对性让位）；
/// 平板与折叠屏（Duo）允许旋转。
void main() {
  const duoTall = DuoLayoutInfo(
    width: 951,
    height: 669,
    occlusions: [Rect.fromLTRB(867, 0, 951, 124)],
  );
  // 普通 iPhone 上报的整条状态栏（不是 Duo 簇）
  const iPhone = DuoLayoutInfo(
    width: 402,
    height: 874,
    occlusions: [Rect.fromLTRB(0, 0, 402, 54)],
  );

  test('iOS 普通手机（402×874）：仅竖屏', () {
    expect(
      OrientationPolicy.allowedOrientations(
          isIOS: true, size: const Size(402, 874), duo: iPhone),
      [DeviceOrientation.portraitUp],
    );
    // 即使当前恰好是横屏尺寸，也不给横屏
    expect(
      OrientationPolicy.allowedOrientations(
          isIOS: true, size: const Size(874, 402), duo: iPhone),
      [DeviceOrientation.portraitUp],
    );
  });

  test('iOS 平板（最短边 ≥600）：允许旋转', () {
    expect(
      OrientationPolicy.allowedOrientations(
          isIOS: true, size: const Size(820, 1180)),
      containsAll(<DeviceOrientation>[
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
      ]),
    );
  });

  test('iOS 折叠屏（有 Duo 角落簇）：允许旋转', () {
    expect(
      OrientationPolicy.allowedOrientations(
          isIOS: true, size: const Size(951, 669), duo: duoTall),
      contains(DeviceOrientation.landscapeLeft),
    );
  });

  test('折叠状态（466×678，有角落在下）：仍允许旋转', () {
    const folded = DuoLayoutInfo(
      width: 469,
      height: 669,
      edge: VerticalBarEdge.leading,
    );
    expect(
      OrientationPolicy.allowedOrientations(
          isIOS: true, size: const Size(469, 669), duo: folded),
      contains(DeviceOrientation.landscapeRight),
    );
  });

  test('普通手机比例时，即使上报像 Duo 的信号也不解锁旋转', () {
    const odd = DuoLayoutInfo(
      edge: VerticalBarEdge.leading,
      width: 390,
      height: 844,
      occlusions: [Rect.fromLTRB(0, 0, 150, 32)],
    );
    expect(
      OrientationPolicy.allowedOrientations(
          isIOS: true, size: const Size(390, 844), duo: odd),
      [DeviceOrientation.portraitUp],
    );
  });

  test('非 iOS（Android）：保持全部方向', () {
    expect(
      OrientationPolicy.allowedOrientations(
          isIOS: false, size: const Size(402, 874)),
      DeviceOrientation.values,
    );
  });
}
