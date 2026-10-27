# Flutter SDK 升级后 Android 构建失败（Kotlin 2.2.10 < 2.2.20）

## 现象

项目从自编译的 Flutter 3.41.10（ohos fork）换到官方 stable **3.47.8** 后：

```
flutter build apk
...
> Failed to apply plugin 'dev.flutter.flutter-gradle-plugin'.
   > Error: Your project's Kotlin version (2.2.10) is lower than Flutter's
     minimum supported version of 2.2.20. Please upgrade your Kotlin version.
...
┌─ Flutter Fix ─┐
│ [!] Starting AGP 9+, only the new DSL interface will be read. ...
```

## 根因

项目此前是按**旧 SDK 的 AGP 9 Built-in Kotlin** 配置的：

- `android/settings.gradle.kts` 没有声明 Kotlin Gradle Plugin（KGP）；
- `android/gradle.properties` 里 `android.builtInKotlin=false`、`android.newDsl=false`（旧 SDK migrator 自动加的，用来退回旧 DSL / 显式 KGP 路径）。

Flutter 3.47.8 的 Android 模板是：

| 项 | 3.47.8 模板值 |
|---|---|
| AGP | 9.1.0 |
| KGP（`org.jetbrains.kotlin.android`） | **2.4.0**（在 settings 的 plugins 块 `apply false`） |
| `android.builtInKotlin` | **false**（模板 gradle.properties） |
| `android.newDsl` | **false** |
| 构建最低 KGP | 2.2.20（`DependencyVersionChecker.errorKGPVersion`） |

由于项目没有声明 KGP，而 Flutter 的 Gradle 插件在 `android.builtInKotlin=false` 时只能尝试 `pluginManager.apply("kotlin-android")`；KGP 不在 classpath，apply 失败（仅 quiet 日志），随后版本检查读到 AGP 9.0.1 自带的 Kotlin **2.2.10**，低于最低 2.2.20 → 直接失败。

> 「Starting AGP 9+ new DSL」那条 Flutter Fix 是错误匹配后的附带提示；`android.newDsl=false` 已设置，不是本次失败的直接原因。

## 修复

`mobile/android/settings.gradle.kts` 的 plugins 块补上 KGP 声明（版本对齐 3.47.8 模板）：

```kotlin
id("org.jetbrains.kotlin.android") version "2.4.0" apply false
```

- 只声明版本（`apply false`）：Flutter Gradle 插件在 `builtInKotlin=false` 时会自动 apply 到各 Android 子工程；
- 保留 `android.builtInKotlin=false` / `android.newDsl=false`（与 3.47.8 模板一致）；
- `pubspec.lock` 由新 SDK 的 `pub get` 刷新（SDK 自带 pin：intl 0.20.3、matcher 0.12.20、meta 1.19.0、test_api 0.7.12、vector_math 2.4.4），随本次一起提交。

### 顺带：新 SDK 的 `onReorder` 弃用

新 SDK 把 `ReorderableListView.onReorder` 标记为弃用（改为 `onReorderItem`，其 newIndex 已按「移除旧项后」调整）。菜谱表单的图片重排从 `onReorder` 迁移到 `onReorderItem`，并去掉手动 `if (newIndex > oldIndex) newIndex--`。否则 `flutter analyze` 会多一条 info。

## 验证

- `C:/opt/flutter/bin/flutter build apk --release`：✓（88.6MB；Flutter 3.47.8 / Dart 3.13.7 / AGP 9.0.1 / Gradle 9.1.0 / KGP 2.4.0）
- `flutter analyze`：No issues found
- `flutter test test/core/shortcuts test/app_localizations_test.dart test/l10n test/core/router test/features/recipes/screens/recipe_form_screen_test.dart`：50 passed

## 遗留

构建时 Flutter 会警告 `image_picker_android`、`shared_preferences_android` 两个插件仍自行 apply KGP：

```
WARNING: Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP):
image_picker_android, shared_preferences_android
Future versions of Flutter will fail to build if your app uses plugins that apply KGP.
```

当前版本仍可构建；等这两个插件发布支持 Built-in Kotlin 的版本后升级即可（不阻塞本次）。

## 升级 SDK 时的注意

旧 SDK（3.41.10 ohos fork）与本次配置不兼容：它没有「显式 KGP」这条路径，声明 KGP 会触发弃用提示/警告。如要切回旧 SDK，需去掉 settings 里的 KGP 行并恢复旧配置。当前项目以官方 stable 3.47.8 为准。
