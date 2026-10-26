import 'dart:async';

import 'package:flutter/services.dart';

import '../shortcuts/app_shortcuts.dart';

/// 主屏快捷方式（长按应用图标）与原生之间的桥。
///
/// 原生侧（Android `MainActivity`、iOS `AppShortcutsPlugin`）实现同一套协议：
/// - `ready`：Dart 侧已装好回调，返回并清空「冷启动时被点击」的快捷方式 id；
/// - `setShortcutItems`：iOS 动态注册快捷方式（标题随界面语言）；Android 在
///   `res/xml/shortcuts.xml` 里静态声明，收到后直接返回 null；
/// - 原生 → Dart `shortcut`：App 已在运行时点击快捷方式（冷启动走 `ready` 返回值）。
///
/// 桌面端 / 单元测试环境没有原生实现，调用会抛 `MissingPluginException`，
/// 这里一律吞掉：快捷方式只是入口增强，不能影响 App 启动。
class AppShortcutsService {
  AppShortcutsService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'com.a4ding.livecalc/shortcuts';

  final MethodChannel _channel;
  final _actions = StreamController<AppShortcut>.broadcast();
  bool _disposed = false;

  /// App 运行期间点击快捷方式时发出的动作。
  Stream<AppShortcut> get actions => _actions.stream;

  /// 安装原生回调，并取回冷启动时被点击的快捷方式（没有则 null）。
  Future<AppShortcut?> initialize() async {
    _channel.setMethodCallHandler(_handleCall);
    try {
      final pending = await _channel.invokeMethod<String>('ready');
      return AppShortcut.fromId(pending);
    } catch (_) {
      return null;
    }
  }

  /// 同步 iOS 动态快捷方式（Android 为 no-op）。
  Future<void> setItems(List<Map<String, String>> items) async {
    try {
      await _channel.invokeMethod<void>('setShortcutItems', items);
    } catch (_) {
      return;
    }
  }

  Future<void> _handleCall(MethodCall call) async {
    if (call.method != 'shortcut') return;
    final shortcut = AppShortcut.fromId(call.arguments as String?);
    if (shortcut != null && !_disposed) {
      _actions.add(shortcut);
    }
  }

  void dispose() {
    _disposed = true;
    _channel.setMethodCallHandler(null);
    _actions.close();
  }
}
