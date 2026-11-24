import 'dart:math';
import 'vertical_bar_edge.dart';
import 'dart:ui' show DisplayFeature, DisplayFeatureType;

import 'package:flutter/material.dart';

/// Shell 布局模式（iPhone Duo 折叠屏 HIG 定调，见
/// agent_doc/FEATURE_iPhoneDuo折叠屏适配调研.md 与 原型/iPhoneDuo适配设计稿.html）。
enum ShellMode {
  /// 底部 tab bar（4 tab + 「更多」）：内屏竖屏 / 常规 iPhone 竖横屏。
  bottomBar,

  /// 尾缘竖条（trailing edge，LTR 下在右）：外屏折叠态 / 内屏横屏。
  /// 竖条 = 系统状态/摄像头保留区（顶部）+ 工具栏区（页面操作，后续接入）+ tab 目的地（沉底）。
  edgeRail,

  /// 左侧 NavigationRail：平板（shortestSide ≥ 700），沿用既有 iPad 行为。
  sideRail,
}

/// 按视口尺寸与折叠特征判定壳层模式。
///
/// 规则（HIG《Designing for iPhone Duo》+ 设计稿实证）：
/// - **折叠屏**（Android 上由 displayFeatures 判定；iOS Duo 在 Flutter 3.50.1
///   不上报 displayFeatures，靠外屏宽矮特征识别）：内屏横屏 → 尾缘竖条；
///   折叠态封面 / 内屏竖屏 → 底部 tab bar（连续屏不分区）。
/// - **平板**（shortestSide ≥ 700）：左 rail。
/// - **内屏竖屏**（竖屏宽 ≥ 600，如 669×951）：标准横条——HIG 例外：竖屏保留
///   顶部导航栏 + 底部 tab bar。
/// - **外屏折叠态**（竖屏 440 ≤ 宽 < 600 且高宽比 ≤ 1.5，如 466×678）：尾缘竖条
///   ——外屏比常规 iPhone（440×956，高宽比 2.17）更宽更矮。
/// - **常规 iPhone**（高宽比 > 1.5）：底部 tab bar。
ShellMode shellModeFor(
  Size size,
  List<DisplayFeature> displayFeatures, {
  VerticalBarEdge? edge,
}) {
  final w = size.width;
  final h = size.height;
  // Android 折叠屏：hinge/fold 特征存在即认定折叠屏（cutout 是刘海，不算）。
  // iOS Duo 在 Flutter 3.50.1 不上报 displayFeatures，走下方尺寸特征分支。
  final isFoldable = displayFeatures.any((f) =>
      f.type == DisplayFeatureType.hinge || f.type == DisplayFeatureType.fold);
  // 系统已明确「竖条存在」时（Duo 折叠态 / 内屏横屏 / 分屏）：除「高瘦的
  // 内屏竖屏」保留横向底栏外，一律用竖条——竖条所在侧同时给摄像头让位，
  // 标题栏也随之缩进，避免摄像机压在标题栏左侧。
  if (edge != null && edge != VerticalBarEdge.unspecified) {
    // 内屏竖屏（高瘦）：标准横条。
    if (w < h && h >= 800) return ShellMode.bottomBar;
    // 折叠横屏（矮，如 678×466）：竖条放不下内容，改全宽底栏——
    // 摄像头只在角落，用标题栏/底栏的局部内边距让位即可。
    if (h < 620) return ShellMode.bottomBar;
    return ShellMode.edgeRail;
  }
  if (isFoldable) {
    if (w > h && h >= 600) return ShellMode.edgeRail;
    return ShellMode.bottomBar;
  }
  if (min(w, h) >= 700) return ShellMode.sideRail;
  if (w >= h) return h >= 600 ? ShellMode.edgeRail : ShellMode.bottomBar;
  if (w >= 600) return ShellMode.bottomBar;
  if (w >= 440 && h / w <= 1.5) return ShellMode.edgeRail;
  return ShellMode.bottomBar;
}
