# BUGFIX：Mac 调试环境 iOS 构建通（Flutter 3.50 dot-shorthand × 旧 analyzer 断层 + objective_c hook 环境断层）

## 背景

用户换到 Mac（Apple Silicon，macOS 27.2，Xcode 27.2，Flutter 3.50.1 stable）后要调试 iOS 端（feat/mobile-app 分支）。此前开发环境是 Windows（Flutter 3.44.8 / Dart 3.12.2，见 [BUGFIX_VSCode_Flutter调试打不开.md](BUGFIX_VSCode_Flutter调试打不开.md)），launch.json 里的 Flutter 配置还是 `deviceId: "windows"`。

## 现象与排查链

1. **iOS 模拟器不可见**：`flutter devices` 只有 macOS 桌面。根因：`xcode-select -p` 指向 `/Library/Developer/CommandLineTools`（只装了 CLT），完整 Xcode.app 在 /Applications 里但没接通。无 sudo 时用 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` 按次绕过。
2. **CocoaPods 缺失**：`pod not found` → `brew install cocoapods`（1.17.0）。`mobile/ios` 里**没有 Podfile**（历史上 iOS 从未在 Mac 上构建过），首次 `flutter build ios` 自动生成 Podfile/Podfile.lock 并改写 xcconfig/pbxproj/xcworkspace（正常首次构建副作用，应随分支提交）。
3. **构建一败：Dart 编译错**——`app_database.dart` 报 `OfflineQueueCompanion`/`select`/`update` 未定义：`.g.dart` 全部 gitignored（mobile/.gitignore:22），新机器必须跑 build_runner。跑 build_runner **挂死**（0% CPU 十分钟）。
4. **build_runner 挂死根因**：`riverpod_generator 2.6.5` 封顶 `analyzer ^7.0.0`，解析到 **Flutter 3.50 框架源码里的 dot-shorthand 语法**（如 `animation_controller.dart:451` 的 `_AnimationDirection _direction = .forward;`）时 bundle writer 抛 `Missing implementation of visitDotShorthandPropertyAccess`，异常打断 AnalysisDriverScheduler 异步循环 → 永久等待。用 `sample <pid>` 看到主线程卡在 `Dart_RunLoop`。
5. **生态断层本质**：Flutter 3.50（2026-11-18 发布，Dart 3.14.0）框架源码启用 dot-shorthand；riverpod_generator 2.x / drift_dev 2.28 均封顶 analyzer 7.x；analyzer 14.x 才全支持。3.47.9（Dart 3.13.7）是最后一个框架不带 shorthand 的 stable。
6. **依赖升级**（用户明确要求以最新稳定版 Flutter 为准，不降级 SDK）：
   - 删 `riverpod_generator` + `riverpod_annotation`（**全项目 0 处 `@riverpod` 注解、0 处 import**，纯死重，flutter_riverpod 运行时 2.6.1 保留不受影响）
   - `drift ^2.19.0 → ^2.35.0`、`drift_dev ^2.19.0 → ^2.35.0`（2.35.3 允许 `analyzer >=13 <15`，且仍在 drift 2.x 内无 breaking 迁移）
   - `build_runner ^2.4.9 → ^2.17.1`（配 build 5.x；2.17 已移除 `--delete-conflicting-outputs` 参数，忽略告警）
   - 结果：analyzer 7.6.0 → **14.7.0**，build_runner 30s 生成全部 639 个输出（含 `app_database.g.dart`）
7. **构建二败：objective_c native-assets hook**——`flutter build ios` 在 `build_hooks` 阶段挂：`objective_c-9.6.4/hook/build.dart` 的 `sdkPath()` 跑 `xcrun --show-sdk-path --sdk iphonesimulator`，hook 进程环境里**没有 DEVELOPER_DIR**（flutter 工具不透传该变量给 hook 子进程；`Process.runSync` 默认不吃 assert——dill 运行无 asserts），xcrun 在 CLT-only 下报错到 stderr、stdout 为空 → `Iterable.first` 抛 `Bad state: No element`。复现证实：同一 hook 命令带 `DEVELOPER_DIR=...` 前缀即成功生成 dylib。
8. **hook 层绕过**：`xcrun` shim（`~/opt/devdir-shim/xcrun`，内部 `export DEVELOPER_DIR=... && exec /usr/bin/xcrun "$@"`）放进 PATH 后再跑构建 → hook 的 PATH 查找命中 shim，**构建成功** `✓ Built build/ios/iphonesimulator/Runner.app`（PATH 会被透传到 hook，DEVELOPER_DIR 不会）。

## 最终状态

- `flutter analyze`：0 error / 0 warning（181 条 info 均为 Flutter 3.50 把 `package:flutter/material.dart` 标记弃用建议 `material_ui` 的存量告警，后续统一迁移）
- `flutter build ios --debug --simulator`：✓
- `flutter devices`：iPhone 18 Pro / iPhone Duo 模拟器可见
- launch.json：原 `Flutter` 改名 `Flutter (Windows 桌面)` 保留；新增 `Flutter (iOS 模拟器)`（`deviceId: "iPhone 18 Pro"`，按名匹配）与 `Flutter (iOS 真机)`（无 deviceId，弹设备选择）
- settings.json：`dart.offline: false`（offline 静默降级锁文件的老坑，见下）；`dart.env` 加 `DEVELOPER_DIR`（供 VS Code 扩展进程用）

## 遗留事项（Mac 上必做一次）

**`xcode-select` 仍指向 CLT，hook 问题只被 shim 绕过；VS Code 里 F5 的 flutter 进程带不上 shim PATH，仍会踩 hook 坑。需要用户执行一次（要输密码）：**

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

切换后 `dart.env` 里的 `DEVELOPER_DIR` 变成无害冗余，shim 也不再必要（保留无害）。终端跑构建推荐带镜像变量：`export PUB_HOSTED_URL=https://pub.flutter-io.cn FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`（`dart.env` 只管 VS Code 起的进程）。

**另一个实测踩到的点**：改完 settings.json 后直接 F5 报 `Device "iPhone 18 Pro" was not found`——排查出三个独立因素：① 扩展的设备列表在启动时扫描、dart.env 在扩展进程启动时注入，**改完配置必须 Reload Window（Cmd+Shift+P → Reload Window）再 F5**；② **模拟器被关了**（退出 DeviceHub / 重启系统都会 Shutdown）——扩展设备列表只含「已连接」设备，关机模拟器不在其中，报的就是这个 Device not found；重启模拟器即可（`xcrun simctl boot "iPhone 18 Pro"` 或 DeviceHub 里启动）；③ Output 面板「flutter initialization」通道里的 `flutter --help` 全文输出是**扩展启动健康探针**（`flutter --suppress-analytics --help`，exit 0 = 正常），不是错误，别被它带偏。**2026-11-22 起用户已执行 `sudo xcode-select --switch` + `-runFirstLaunch`，本机遗留事项全部完成**：`DEVELOPER_DIR`（dart.env）与 `~/opt/devdir-shim` 均降级为无害冗余。

**iPhone Duo 入口**（用户要测新形态设备效果）：launch.json 增 `Flutter (iOS 模拟器 iPhone Duo)`（deviceId 按名匹配）。注意机器上有**两台同名 iPhone Duo**（`949B9C75…` / `E7C9A05B…`，都在 beta runtime `SimRuntime.iOS-27-2-iPhone19-4`、构建号 24B91016s 带 seed 后缀），`simctl boot "iPhone Duo"` 按名命中第一台；要精确指定用 UDID。已做冒烟测试：把 `build/ios/iphonesimulator/Runner.app`（bundle id `com.livecalc.livecalcMobile`）`simctl install` + `launch` 到 Duo，进程稳定存活——beta iPhone19-4 runtime 兼容本应用，F5 调试无运行时障碍。

切换后 `dart.env` 里的 `DEVELOPER_DIR` 变成无害冗余，shim 也不再必要（保留无害）。终端跑构建推荐带镜像变量：`export PUB_HOSTED_URL=https://pub.flutter-io.cn FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`（`dart.env` 只管 VS Code 起的进程）。

## 经验

- 「flutter devices 看不到 iOS 设备」先查 `xcode-select -p`；无 sudo 时所有命令前缀 `DEVELOPER_DIR=...`，Xcode 26+ 的模拟器 app 叫 **DeviceHub**（`/Applications/Xcode.app/Contents/Applications/DeviceHub.app`），不再有 Simulator.app。
- build_runner「0% CPU 挂死」别急着 kill 重试：`sample <pid>` 看栈 + 完整日志找 `E` 行——这次是 analyzer 解析不了 SDK 新语法后调度循环死等，重跑也一样挂。
- Flutter 大版本发布后，框架源码用新语言特性会让**所有**封顶旧 analyzer 的代码生成器（riverpod_generator/drift_dev/build 工具链）集体失效，报错点却是任意一个被分析的文件；解法是把「有 analyzer 上限的构建插件」升到允许新 analyzer 的版本，而不是降 Flutter。
- 排查前先 grep 使用量再决定升级范围：riverpod_generator 在本项目 0 使用，直接删除比跨 major 迁移 riverpod 3.x 便宜两个数量级。
- native-assets hook（objective_c 等包）拿不到 SDK path 且 stdout 为空报 `Bad state: No element`，是 hook 进程没有 DEVELOPER_DIR；flutter 工具只透传 PATH 不透传 DEVELOPER_DIR——shim xcrun 可验证全链路，永久解法只有 xcode-select 切到完整 Xcode。
- 镜像变量（PUB_HOSTED_URL/FLUTTER_STORAGE_BASE_URL）只写在 settings.json 的 dart.env 里，终端默认拿不到；直连 pub.dev 会长时间无响应（`flutter pub get` 还会把 `mobile/pubspec.lock` 里的 mirror URL 全改回 pub.dev，属于噪声改动，提交前用 `git checkout -- mobile/pubspec.lock` 还原）。

## GitHub Actions iOS 构建（CI 侧的同一断层）

工作流 `.github/workflows/build-ios.yml` 原固定 `flutter-version: 3.44.8`（Dart 3.12.2），在 `flutter pub get` 阶段就失败：

```
Because build_runner >=2.16.2 depends on analyzer ^14.3.0 and analyzer >=14.6.0 requires SDK version >=3.13.0 <4.0.0,
build_runner >=2.16.2 requires analyzer >=14.3.0 <14.6.0.
And because analyzer >=13.1.0 <14.6.0 depends on meta ^1.18.3 and every version of flutter from sdk depends on meta 1.18.0,
build_runner >=2.16.2 is incompatible with flutter from sdk.
```

即本机上「升 Flutter + 升 build_runner」的解法在 CI 上反过来了：CI 的 Flutter 太旧，凑不出 build_runner 2.17.1 需要的 analyzer（lock 里是 14.7.0，要求 Dart ≥3.13；`pubspec.lock` 的 sdks 也写了 `dart >=3.13.0` / `flutter >=3.47.0`）。**不能反过来把 build_runner 降到 2.15.1**——那样本机 Flutter 3.50 的 dot-shorthand 又会挂死 codegen。

修正：CI 的 `flutter-version` 升到 **3.50.1**（与本地开发环境一致），并在 workflow 里写了注释说明这条绑定关系。改完本地实测同口径通过：`flutter pub get`（输出 `Changed 176 dependencies!` 只是 mirror URL 被改写的假变更，版本号全部 `was == now`）+ `dart run build_runner build`（685 outputs，31s）+ `flutter analyze`（0 error / 255 info，info 均为存量）。`--delete-conflicting-outputs` 在 build_runner 2.17 已是「保留但忽略」的选项（源码 `removedOptions`），只会打一行 warning，可留可删。

规则：**升级 Flutter 时 workflow 的 `flutter-version` 与 `mobile/pubspec.lock` 必须一起改**，否则 CI 会在 pub get 阶段失败。
