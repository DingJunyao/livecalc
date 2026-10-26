package com.a4ding.livecalc

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 主屏快捷方式（长按应用图标）桥接。
 *
 * 快捷方式在 res/xml/shortcuts.xml 中静态声明，intent extra
 * [EXTRA_SHORTCUT_ACTION] 携带动作 id，与 Dart 侧 AppShortcut.id 对应
 * （见 lib/core/shortcuts/app_shortcuts.dart）。
 *
 * 协议（与 iOS AppDelegate.swift 中的 AppShortcutsPlugin 一致）：
 * - ready：Dart 已装好回调，返回并清空冷启动待处理的快捷方式 id；
 * - setShortcutItems：Android 使用静态声明，直接返回成功；
 * - 原生 → Dart shortcut：App 已在运行时点击快捷方式。
 */
class MainActivity : FlutterActivity() {
    private var shortcutChannel: MethodChannel? = null
    private var dartReady = false
    private var pendingShortcut: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pendingShortcut = intent?.getStringExtra(EXTRA_SHORTCUT_ACTION)
        shortcutChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
                setMethodCallHandler { call, result ->
                    when (call.method) {
                        "ready" -> {
                            dartReady = true
                            result.success(pendingShortcut)
                            pendingShortcut = null
                        }
                        "setShortcutItems" -> result.success(null)
                        else -> result.notImplemented()
                    }
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val shortcut = intent.getStringExtra(EXTRA_SHORTCUT_ACTION) ?: return
        setIntent(intent)
        if (dartReady) {
            shortcutChannel?.invokeMethod("shortcut", shortcut)
        } else {
            pendingShortcut = shortcut
        }
    }

    companion object {
        private const val CHANNEL = "com.a4ding.livecalc/shortcuts"
        private const val EXTRA_SHORTCUT_ACTION = "com.a4ding.livecalc.SHORTCUT_ACTION"
    }
}
