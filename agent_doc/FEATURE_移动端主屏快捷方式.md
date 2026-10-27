# 移动端主屏快捷方式（计价 / 每日推荐 / 菜谱）

## 需求

长按手机桌面上的「生计」图标时弹出快捷方式，直接进入三个常用入口：

- **计价** → 新增价格记录页（直接开表单，不是先到列表）
- **查看每日推荐** → 首页今日推荐
- **菜谱** → 菜谱列表

iOS、Android 两端都要支持，标题跟随界面语言（简体中文 / English / العربية）。

## 方案概览

不引入新依赖，用一条 MethodChannel 串起两端：

| 层 | 做法 |
|---|---|
| Dart | `core/shortcuts/app_shortcuts.dart`（动作 id → 路由 / 三语标题 / iOS 图标名）+ `core/services/app_shortcuts_service.dart`（通道 + 事件流）；`app.dart` 负责接线 |
| Android | `res/xml/shortcuts.xml` **静态**声明三条（安装后即可用）+ `MainActivity` 把 intent 转给 Dart；标题用 `values*/strings.xml` 三语 |
| iOS | `AppDelegate.swift` 内的应用内插件，Dart 通过 `setShortcutItems` **动态**注册 `UIApplicationShortcutItem`（标题取 Dart l10n） |

两端原生实现同一套通道协议：

| 方向 | 方法 | 说明 |
|---|---|---|
| Dart → 原生 | `ready` | Dart 已装好回调；返回并清空「冷启动时点击」的快捷方式 id（一次性） |
| Dart → 原生 | `setShortcutItems` | iOS 动态注册（id / title / icon）；Android 静态声明，直接返回成功 |
| 原生 → Dart | `shortcut` | App 已在运行时点击快捷方式（参数为动作 id） |

通道名：`com.a4ding.livecalc/shortcuts`。

## 路由与图标

| 动作 id | 根页 → 目标路由 | Android 图标 | iOS 内置图标 |
|---|---|---|---|
| `record_price` | `/prices` → push `/prices/record` | `ic_shortcut_record_price`（收据） | `.add` |
| `daily_recommendation` | `/home` | `ic_shortcut_daily`（房子） | `.home` |
| `recipes` | `/recipes` | `ic_shortcut_recipes`（刀叉） | `.bookmark` |

**打开方式**：`AppShortcut.baseRoute` 为空的直接 `go`；「计价」是表单类入口，
先 `go('/prices')` 落到价格列表，等这一帧生效后再 `push('/prices/record')`。
这样新增价格表单在栈顶，保存成功 `pop(true)` / 返回会回到价格记录列表；
若直接 `go` 表单，它就成了 shell 里的首屏页面，保存后无处可回。

其余两条落在 tab 根页面，与网页端 PWA shortcut 的行为对齐。

## 冷启动 / 运行中点击

### Android

`res/xml/shortcuts.xml` 的 `<intent>` 使用自定义 action + extra
`com.a4ding.livecalc.SHORTCUT_ACTION` 携带动作 id。

关键点：AOSP `ShortcutParser` 在解析静态快捷方式时会给 intent 追加
`FLAG_ACTIVITY_NEW_TASK | FLAG_ACTIVITY_CLEAR_TASK | FLAG_ACTIVITY_TASK_ON_HOME`
（与 TaskStackBuilder 相同），因此点击快捷方式**等同重建任务**：

- 冷启动 / App 在后台：新 Activity → `configureFlutterEngine` 读 `intent` 的 extra
  存为 pending → Dart 启动后 `ready` 取回 → 跳转；
- `onNewIntent` 仍保留兜底（例如 launcher 直接投递 intent 的场景），
  未就绪时同样存入 pending。

`<extra>` 的合法性由 `Intent.parseIntent()` 保证（`ShortcutParser` 即调用它）；
不用 `android:data` 深链，避免被 Flutter 的 deep link 路由抢走初始路由。

### iOS

App 使用 **UIScene 生命周期**（Info.plist 的 `UIApplicationSceneManifest`），
此时 `AppDelegate.application(_:performActionFor:)` 不会被调用，快捷方式回调走
SceneDelegate。Flutter 3.35+ 提供 `FlutterSceneLifeCycleDelegate`，插件通过
`registrar.addSceneDelegate` 注册后即可收到：

- `scene(_:willConnectTo:options:)`：冷启动，快捷方式在 `connectionOptions.shortcutItem`；
- `windowScene(_:performActionFor:completionHandler:)`：App 已在运行。

插件在 `AppDelegate.didInitializeImplicitFlutterEngine` 中用
`pluginRegistry.registrar(forPlugin: "AppShortcutsPlugin")` 手动注册。
注意 Flutter 引擎对场景代理是**弱引用**，插件用静态 `shared` 保留强引用，
否则注册后即被释放、回调丢失。

`ready` 之前收到点击时暂存 `pendingShortcut`，由 `ready` 返回，避免启动早期事件丢失。

### 登录态

`app.dart` 在认证完成前只记录 pending（router 的 redirect 会先落到登录页），
认证成功后（监听 `authProvider`）再 `go(route)`；因此未登录点快捷方式，
登录完成后仍会跳到目标页面。导航放在 post-frame 里，避开 splash → 落地页的 redirect。

## 关键坑

1. **iOS 静态 Info.plist 快捷方式无法多语言**：`InfoPlist.strings` 只能替换 plist 中的
   字符串键，寻址不到 `UIApplicationShortcutItems` 数组里的字典。故 iOS 改为运行时
   动态注册，标题直接用 Flutter l10n；代价是**首次启动 App 之后**才会出现（Android
   静态声明安装即用）。这是有意的取舍。
2. **iOS UIScene**：见上，不要往 AppDelegate 的 `performActionFor` 里写逻辑。
3. **Android 静态 intent 被系统加 flags**：见上，`onNewIntent` 不是主路径。
4. **通道握手**：`ready` 返回值只消费一次，避免下次普通启动误跳。
5. **桌面 / 测试环境无原生实现**：`AppShortcutsService` 吞掉 `MissingPluginException`，
   App 启动不受影响。

## 文件清单

Dart：

- `mobile/lib/core/shortcuts/app_shortcuts.dart`
- `mobile/lib/core/services/app_shortcuts_service.dart`
- `mobile/lib/app.dart`（初始化、标题同步、pending 跳转）
- `mobile/lib/l10n/app_{zh,en,ar}.arb`（`shortcutRecordPrice` / `shortcutDailyRecommendation` / `shortcutRecipes`）+ 生成的 `app_localizations*.dart`
- `mobile/test/core/shortcuts/app_shortcuts_test.dart`

Android：

- `mobile/android/app/src/main/res/xml/shortcuts.xml`
- `mobile/android/app/src/main/res/drawable/ic_shortcut_{record_price,daily,recipes}.xml`（主题绿圆底 + 白色 Material 字形）
- `mobile/android/app/src/main/res/values/colors.xml`（`shortcut_icon_background`）
- `mobile/android/app/src/main/res/values{,-en,-ar}/strings.xml`
- `mobile/android/app/src/main/AndroidManifest.xml`（`android.app.shortcuts` meta-data）
- `mobile/android/app/src/main/kotlin/com/a4ding/livecalc/MainActivity.kt`

iOS：

- `mobile/ios/Runner/AppDelegate.swift`（`AppShortcutsPlugin` + 注册）

文档：

- `docs/mobile.md`（用户手册「主屏快捷方式」）

## 验证

- `flutter analyze`：No issues found
- `flutter test test/core/shortcuts test/app_localizations_test.dart test/l10n test/core/router`：43 passed（含「计价」直达新增价格记录页且可返回列表的 widget 测试：push 后 `canPop` 为 true、当前页 `/prices/record`）
- `flutter build apk --release`：通过（验证 AndroidManifest / shortcuts.xml / 矢量图标 / Kotlin 编译）
- iOS：本机（Windows）无 Xcode，未编译；需在 macOS 上 `flutter build ios --no-codesign` 或 Xcode 真机验证长按菜单与点击跳转。

## 后续可选

若希望 iOS 安装后立刻出现快捷方式，可改为 Info.plist 静态声明；但标题只能写死一种语言
（或放弃多语言），与当前「标题跟随界面语言」冲突，暂不采用。
