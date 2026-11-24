import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/core/layout/device_form.dart';
import 'package:com_a4ding_livecalc/core/layout/vertical_bar_edge.dart';

DisplayFeature hinge() => const DisplayFeature(
      bounds: Rect.fromLTRB(0, 0, 8, 800),
      type: DisplayFeatureType.hinge,
      state: DisplayFeatureState.postureFlat,
    );

void main() {
  group('shellModeFor（iPhone Duo 折叠屏壳层判定）', () {
    test('iPhone Duo 外屏折叠态（466×678）→ 尾缘竖条', () {
      expect(shellModeFor(const Size(466, 678), const []), ShellMode.edgeRail);
    });

    test('iPhone Duo 内屏竖屏（669×951）→ 标准横条（HIG 例外）', () {
      expect(
        shellModeFor(const Size(669, 951), const []),
        ShellMode.bottomBar,
      );
    });

    test('iPhone Duo 内屏横屏（951×669）→ 尾缘竖条', () {
      expect(shellModeFor(const Size(951, 669), const []), ShellMode.edgeRail);
    });

    test('常规 iPhone 竖屏（430×932，高宽比 2.17）→ 底栏', () {
      expect(shellModeFor(const Size(430, 932), const []), ShellMode.bottomBar);
    });

    test('常规 iPhone 横屏（932×430）→ 底栏', () {
      expect(shellModeFor(const Size(932, 430), const []), ShellMode.bottomBar);
    });

    test('iPhone SE（375×667，高宽比 1.78）→ 底栏', () {
      expect(shellModeFor(const Size(375, 667), const []), ShellMode.bottomBar);
    });

    test('平板（834×1194）→ 左 rail', () {
      expect(shellModeFor(const Size(834, 1194), const []), ShellMode.sideRail);
    });

    test('平板横屏（1194×834）→ 左 rail', () {
      expect(shellModeFor(const Size(1194, 834), const []), ShellMode.sideRail);
    });

    test('Android 折叠屏（hinge 特征）横屏内屏 → 尾缘竖条', () {
      expect(shellModeFor(const Size(904, 771), [hinge()]), ShellMode.edgeRail);
    });

    test('Android 折叠屏封面（380×904）→ 底栏', () {
      expect(
        shellModeFor(const Size(380, 904), [hinge()]),
        ShellMode.bottomBar,
      );
    });

    test('cutout（刘海）不算折叠特征：直板屏走底栏', () {
      const cutout = DisplayFeature(
        bounds: Rect.fromLTRB(0, 0, 100, 40),
        type: DisplayFeatureType.cutout,
        state: DisplayFeatureState.unknown,
      );
      expect(shellModeFor(const Size(390, 844), [cutout]), ShellMode.bottomBar);
    });

    test('边界：竖屏宽 440 高宽比恰好 1.5 → 尾缘竖条', () {
      expect(shellModeFor(const Size(440, 660), const []), ShellMode.edgeRail);
    });

    test('边界：竖屏宽 440 高宽比 1.6 → 底栏', () {
      expect(shellModeFor(const Size(440, 704), const []), ShellMode.bottomBar);
    });

    test('系统竖条存在 + 矮横屏（678×466 折叠横屏）→ 底栏（竖条放不下）', () {
      expect(
        shellModeFor(const Size(678, 466), const [],
            edge: VerticalBarEdge.trailing),
        ShellMode.bottomBar,
      );
    });

    test('系统竖条存在 + 高瘦竖屏（669×951 展开竖屏）→ 保留底栏', () {
      expect(
        shellModeFor(const Size(669, 951), const [],
            edge: VerticalBarEdge.trailing),
        ShellMode.bottomBar,
      );
    });

    test('系统竖条存在 + 分屏窄窗（478×669）→ 竖条', () {
      expect(
        shellModeFor(const Size(478, 669), const [],
            edge: VerticalBarEdge.leading),
        ShellMode.edgeRail,
      );
    });

    test('边界：竖屏宽 600 → 标准横条（内屏竖屏下限）', () {
      expect(shellModeFor(const Size(600, 852), const []), ShellMode.bottomBar);
    });
  });
}
