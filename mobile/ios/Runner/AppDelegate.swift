import CoreLocation
import Flutter
import MapKit
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
    // Apple Maps（MapKit）地理编码桥接，见文件末尾 AppleMapsPlugin。
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AppleMapsPlugin") {
      AppleMapsPlugin.register(with: registrar)
    }
    // iPhone Duo 竖条侧别（分屏时左窗在左缘），见文件末尾 DuoLayoutPlugin。
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DuoLayoutPlugin") {
      DuoLayoutPlugin.register(with: registrar)
    }
    // 「关于」页打开项目/作者链接，见文件末尾 ExternalUrlPlugin。
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ExternalUrlPlugin") {
      ExternalUrlPlugin.register(with: registrar)
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

/// iOS Apple Maps（MapKit）地理编码桥接：商家名称搜索 + 坐标逆编码。
///
/// 用系统自带能力给商家表单提供两类查询（无需任何地图服务 API key）：
/// - `searchPlaces`：MKLocalSearch 按名称/地址搜地点（POI + 地址），
///   返回坐标与行政区划组件，Dart 侧据此回填表单并匹配行政区划。
/// - `reverseGeocode`：CLGeocoder 坐标 → 行政区划组件（地图选点后回填）。
///
/// Dart 侧封装：`lib/core/services/apple_maps_service.dart`。
/// 注意：MapKit 在中国大陆返回 GCJ-02 坐标，折算统一由 Dart 侧处理。
final class AppleMapsPlugin: NSObject, FlutterPlugin {
  /// 与 Dart 侧 AppleMapsService 使用同一个通道名。
  private static let channelName = "com.a4ding.livecalc/apple_maps"

  private let channel: FlutterMethodChannel
  /// 进行中的查询，替换时取消旧查询（降低 MKLocalSearch/CLGeocoder 限流概率）。
  private var pendingSearch: MKLocalSearch?
  private var pendingGeocoder: CLGeocoder?

  private init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    let instance = AppleMapsPlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "searchPlaces":
      searchPlaces(call.arguments as? [String: Any] ?? [:], result: result)
    case "reverseGeocode":
      reverseGeocode(call.arguments as? [String: Any] ?? [:], result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - searchPlaces（MKLocalSearch：名称/地址 → 坐标 + 行政区划）

  private func searchPlaces(_ args: [String: Any], result: @escaping FlutterResult) {
    guard let query = args["query"] as? String,
          !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      result([])
      return
    }
    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = query
    if let lat = args["centerLat"] as? Double, let lng = args["centerLng"] as? Double {
      let radius = (args["radiusMeters"] as? Double) ?? 50_000
      request.region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
        latitudinalMeters: radius,
        longitudinalMeters: radius
      )
    }
    pendingSearch?.cancel()
    let search = MKLocalSearch(request: request)
    pendingSearch = search
    search.start { [weak self] response, error in
      if self?.pendingSearch === search { self?.pendingSearch = nil }
      if let error = error {
        let nsError = error as NSError
        // 取消（新查询替换旧查询）在 MapKit 没有稳定的公开枚举 case，且
        // Dart 侧对失败与空结果处理相同，MKErrorDomain 的错误一律静默返回
        // 空；非该域的错误上抛由 Dart 侧捕获降级。
        if nsError.domain == MKErrorDomain {
          result([])
        } else {
          result(FlutterError(
            code: "searchFailed",
            message: error.localizedDescription,
            details: nil
          ))
        }
        return
      }
      // 先落成独立语句再链式操作：`(response?.mapItems ?? []).prefix(...)`
      // 与后续 .map 连写时，Swift 会把 `?? []` 推断成双重可选导致
      // "[MKMapItem]?? has no member 'prefix'"（CI 四轮实证）。
      let mapItems = response?.mapItems ?? []
      let items = mapItems.prefix(10).map { item in
        self?.placeDict(item.name, placemark: item.placemark) ?? [:]
      }
      result(items)
    }
  }

  // MARK: - reverseGeocode（CLGeocoder：坐标 → 行政区划）

  private func reverseGeocode(_ args: [String: Any], result: @escaping FlutterResult) {
    guard let lat = args["latitude"] as? Double,
          let lng = args["longitude"] as? Double else {
      result(nil)
      return
    }
    // CLGeocoder 无公开 locale API，结果语言跟随设备语言；区划匹配的国家
    // 走 isoCountryCode 不受影响，division 名称失配由 Dart 侧 best-effort 降级。
    pendingGeocoder?.cancelGeocode()
    let geocoder = CLGeocoder()
    pendingGeocoder = geocoder
    geocoder.reverseGeocodeLocation(CLLocation(latitude: lat, longitude: lng)) { [weak self] placemarks, error in
      if self?.pendingGeocoder === geocoder { self?.pendingGeocoder = nil }
      if let error = error {
        let nsError = error as NSError
        // 取消（含 cancelGeocode 与服务端限流）同走静默降级：Dart 侧收到
        // null 后回退后端 geocode。
        if nsError.domain == kCLErrorDomain {
          result(nil)
        } else {
          result(FlutterError(
            code: "reverseFailed",
            message: error.localizedDescription,
            details: nil
          ))
        }
        return
      }
      guard let placemark = placemarks?.first else {
        result(nil)
        return
      }
      // escaping 闭包里 weak self 必须显式解包。
      result(self?.placeDict(placemark.name, placemark: placemark) ?? [:])
    }
  }

  // MARK: - Helpers

  /// MKMapItem / CLPlacemark → Flutter dict（与 Dart 侧 ApplePlace 同构）。
  /// MKMapItem 没有 subtitle/address 属性（CI 五轮实证），地址统一由
  /// CLPlacemark 行政区划组件按中文习惯（省→市→区→街道门牌）无缝拼接；
  /// 坐标缺失时省略键，Dart 侧按 null 处理。
  private func placeDict(
    _ name: String?,
    placemark: CLPlacemark
  ) -> [String: Any] {
    let coordinate = placemark.location?.coordinate
    var dict: [String: Any] = [
      "name": name ?? "",
      "address": [placemark.administrativeArea, placemark.locality,
                  placemark.subLocality, placemark.thoroughfare,
                  placemark.subThoroughfare]
          .compactMap { $0 }.joined(),
      "country": placemark.country ?? "",
      "countryCode": placemark.isoCountryCode ?? "",
      "administrativeArea": placemark.administrativeArea ?? "",
      "locality": placemark.locality ?? "",
      "subLocality": placemark.subLocality ?? "",
      "thoroughfare": placemark.thoroughfare ?? "",
    ]
    if let coordinate = coordinate {
      dict["latitude"] = coordinate.latitude
      dict["longitude"] = coordinate.longitude
    }
    return dict
  }
}

/// iPhone Duo 竖条侧别桥接：`UITraitCollection.verticalBarEdge`（iOS 27.1+）。
///
/// 分屏多任务时系统保留条只出现在本窗口靠外的一侧——左窗 leading、右窗
/// trailing；HIG 要求 app 控件跟随该侧。Flutter 的 `viewPadding` 在分屏场景
/// 不一定反映该信息，故直接读 UIKit trait。
///
/// 返回：0 = 无竖条/未知，1 = leading（左缘），2 = trailing（右缘）。
/// Dart 侧封装：`lib/core/layout/vertical_bar_edge.dart`。
final class DuoLayoutPlugin: NSObject, FlutterPlugin {
  /// 与 Dart 侧 DuoLayoutChannel 使用同一个通道名。
  private static let channelName = "com.a4ding.livecalc/duo_layout"

  private let channel: FlutterMethodChannel
  private weak var registrar: FlutterPluginRegistrar?

  private init(channel: FlutterMethodChannel, registrar: FlutterPluginRegistrar) {
    self.channel = channel
    self.registrar = registrar
    super.init()
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    let instance = DuoLayoutPlugin(channel: channel, registrar: registrar)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "verticalBarEdge":
      result(currentEdge())
    case "layoutInfo":
      result(layoutInfo())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// 竖条侧别 + 遮挡区（摄像头/状态簇）矩形，坐标为本视图 points。
  ///
  /// 折叠态下摄像头可能在左下/右下角（随持握方向翻转），遮挡区可能落在竖条
  /// 底部——Dart 侧据 `occlusions` 把导航项放到相反一端，避免压住系统元素。
  private func layoutInfo() -> [String: Any] {
    var info: [String: Any] = [:]
    guard let view = registrar?.viewController?.view else { return info }
    info["width"] = Double(view.bounds.width)
    info["height"] = Double(view.bounds.height)
    guard #available(iOS 27.1, *) else {
      info["edge"] = 0
      info["occlusions"] = []
      info["divisions"] = []
      return info
    }
    switch registrar?.viewController?.traitCollection.verticalBarEdge {
    case .leading:
      info["edge"] = 1
    case .trailing:
      info["edge"] = 2
    default:
      info["edge"] = 0
    }
    func rects(_ regions: [UIView.ReservedRegion]) -> [[String: Any]] {
      regions.map { region in
        let frame = region.frame
        return [
          "x": Double(frame.origin.x),
          "y": Double(frame.origin.y),
          "width": Double(frame.size.width),
          "height": Double(frame.size.height),
        ]
      }
    }
    info["occlusions"] = rects(view.reservedRegions(kind: .occlusion))
    // 折叠区（半开时系统把显示分成多块）：横屏半展开时用于避免跨铰链布局。
    // 折叠区：默认查询即可；再并上 includeInactive，避免半开过渡期返回空。
    var divisions = view.reservedRegions(kind: .division)
    divisions += view.reservedRegions(kind: .division, options: [.includeInactive])
    info["divisions"] = rects(divisions)
    return info
  }

  /// 读取当前 trait 的竖条侧别；低版本系统一律 0（无竖条）。
  private func currentEdge() -> Int {
    if #available(iOS 27.1, *) {
      let traitCollection = registrar?.viewController?.traitCollection
        ?? registrar?.viewController?.view.traitCollection
      guard let traits = traitCollection else { return 0 }
      switch traits.verticalBarEdge {
      case .leading:
        return 1
      case .trailing:
        return 2
      default:
        return 0
      }
    }
    return 0
  }
}

/// 打开外部链接（项目主页/作者主页）。
///
/// 与 Android MainActivity 的 `com.a4ding.livecalc/external_url` 通道同协议；
/// 不引入 url_launcher 插件，避免新增 SPM 依赖导致 iOS 构建需要访问 GitHub。
final class ExternalUrlPlugin: NSObject, FlutterPlugin {
  private static let channelName = "com.a4ding.livecalc/external_url"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(ExternalUrlPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "openUrl",
          let args = call.arguments as? [String: Any],
          let raw = args["url"] as? String,
          let url = URL(string: raw) else {
      result(FlutterMethodNotImplemented)
      return
    }
    UIApplication.shared.open(url, options: [:]) { opened in
      result(opened)
    }
  }
}
