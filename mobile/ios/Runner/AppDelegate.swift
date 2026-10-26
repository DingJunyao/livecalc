import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // 主屏快捷方式（长按应用图标）桥接，见文件末尾 AppShortcutsPlugin。
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AppShortcutsPlugin") {
      AppShortcutsPlugin.register(with: registrar)
    }
  }
}

/// 主屏快捷方式（iPhone/iPad 长按应用图标弹出，即 Home Screen Quick Actions）。
///
/// App 采用 UIScene 生命周期（Info.plist 的 UIApplicationSceneManifest），
/// 快捷方式回调不再走 AppDelegate，而是由 SceneDelegate 派发。Flutter 用
/// `FlutterSceneLifeCycleDelegate` 把它们转发给注册过 `addSceneDelegate` 的插件，
/// 因此这里注册一个应用内插件同时处理：
/// - 冷启动：`scene(_:willConnectTo:options:)` 的 `connectionOptions.shortcutItem`
/// - App 已在运行：`windowScene(_:performActionFor:completionHandler:)`
///
/// 与 Android 的静态声明不同，iOS 快捷方式由 Dart 在启动/切语言时通过
/// `setShortcutItems` 动态注册，标题取当前界面语言（zh/en/ar）。
/// 副作用是：安装后需先启动一次 App 才会出现快捷方式，这是 iOS 动态
/// 快捷方式的固有限制。
final class AppShortcutsPlugin: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  /// 与 Android MainActivity、Dart AppShortcutsService 使用同一个通道名。
  private static let channelName = "com.a4ding.livecalc/shortcuts"

  /// 原生侧只弱引用场景代理，这里保留一份强引用避免插件被释放。
  private static var shared: AppShortcutsPlugin?

  private let channel: FlutterMethodChannel

  /// Dart 是否已装好回调（`ready`）。未就绪时点击记录到 pendingShortcut，
  /// 由下次 `ready` 返回，避免启动早期的事件丢失。
  private var dartReady = false
  private var pendingShortcut: String?

  private init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    let instance = AppShortcutsPlugin(channel: channel)
    shared = instance
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addSceneDelegate(instance)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "ready":
      dartReady = true
      result(pendingShortcut)
      pendingShortcut = nil
    case "setShortcutItems":
      applyShortcutItems(call.arguments as? [[String: Any]] ?? [])
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - FlutterSceneLifeCycleDelegate

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    // 冷启动时快捷方式随 UISceneConnectionOptions 下发；返回 true 表示已消费，
    // Flutter 不再处理这次连接事件（本 App 没有深度链接，不受影响）。
    guard let shortcutItem = connectionOptions?.shortcutItem else { return false }
    record(shortcutItem.type)
    return true
  }

  func windowScene(
    _ windowScene: UIWindowScene,
    performActionFor shortcutItem: UIApplicationShortcutItem,
    completionHandler: @escaping (Bool) -> Void
  ) -> Bool {
    record(shortcutItem.type)
    completionHandler(true)
    return true
  }

  // MARK: - Helpers

  private func record(_ shortcutType: String) {
    if dartReady {
      channel.invokeMethod("shortcut", arguments: shortcutType)
    } else {
      pendingShortcut = shortcutType
    }
  }

  private func applyShortcutItems(_ items: [[String: Any]]) {
    UIApplication.shared.shortcutItems = items.compactMap { item in
      guard let type = item["id"] as? String, !type.isEmpty else { return nil }
      let title = item["title"] as? String ?? ""
      let iconName = item["icon"] as? String ?? "add"
      return UIApplicationShortcutItem(
        type: type,
        localizedTitle: title,
        localizedSubtitle: nil,
        icon: Self.icon(for: iconName),
        userInfo: nil
      )
    }
  }

  /// Dart 侧 AppShortcut.iosIcon → iOS 内置快捷方式图标。
  private static func icon(for name: String) -> UIApplicationShortcutIcon {
    switch name {
    case "home":
      return UIApplicationShortcutIcon(type: .home)
    case "bookmark":
      return UIApplicationShortcutIcon(type: .bookmark)
    case "favorite":
      return UIApplicationShortcutIcon(type: .favorite)
    case "search":
      return UIApplicationShortcutIcon(type: .search)
    case "compose":
      return UIApplicationShortcutIcon(type: .compose)
    default:
      return UIApplicationShortcutIcon(type: .add)
    }
  }
}
