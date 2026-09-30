# iOS 本地未签名构建与 CocoaPods 环境（2026-09-18）

## 现象

本机（Intel macOS VM，Xcode 26.2）执行与 CI 相同的 `xcodebuild`（未签名）构建失败：

```
GeneratedPluginRegistrant.m:12:9: error: Module 'apple_maps_flutter' not found (in target 'Runner')
```

GitHub Actions 上同样的命令能成功。

## 根因（完整链路）

1. 本项目 iOS 端为 **SwiftPM + CocoaPods 混合模式**：仓库未提交 `ios/Podfile`（工程已迁移 SwiftPM），9 个支持 SPM 的插件走 `FlutterGeneratedPluginSwiftPackage`；但 `apple_maps_flutter 1.4.0`、`flutter_secure_storage 9.2.4` **不支持 SPM**（pub-cache 内无 `Package.swift`、pubspec 未声明 `swift-package-manager`），Flutter 工具对它们回退 CocoaPods——本地未提交的 `ios/Podfile`、xcconfig `#include? "Pods/..."` 改动即 Flutter 自动生成。
2. CI 的 workflow（[build-ios.yml](../.github/workflows/build-ios.yml)）里 `flutter build ios --config-only --no-codesign` 一步会执行 `pod install`，且 macOS runner 预装 CocoaPods；本机直接跑了 `xcodebuild`，且**本机根本没有 `pod`**，`ios/Pods/` 不存在 → `@import apple_maps_flutter;` 两个分支都失败。

## 本机环境限制（重要，别踩坑）

- 本机为 Intel VM，Homebrew `/usr/local` 上很多 formula **没有 x86_64 bottle**，`brew install cocoapods` 会触发 llvm/rust/ruby 源码编译链（数小时），不可行（本次已中断，残留锁已清理；llvm@22/python@3.14 等 bottle 部分已装完，无害）。
- 系统 Ruby 2.6 + Xcode 26.2 SDK **缺少 Ruby 2.6 头文件**（`ruby/config.h`），`gem install` 含原生扩展的 gem 必失败。
- 可行解：用 **Homebrew 自带的 portable-ruby 4.0.7**（`/usr/local/Homebrew/Library/Homebrew/vendor/portable-ruby/current`，含完整头文件）把 CocoaPods 1.17.0 装到用户目录 `~/.gem/pod-ruby`，并通过 wrapper `~/.local/bin/pod` 暴露（`.zshrc` 已有 `~/.local/bin` 优先 PATH，无需再改）。wrapper 内设置 `GEM_HOME/GEM_PATH=$HOME/.gem/pod-ruby`，不污染全局 Ruby。

## 本地未签名构建步骤（与 CI 等价）

```bash
cd mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build ios --config-only --no-codesign   # 生成配置 + pod install（需要 pod 在 PATH，wrapper 已覆盖）
xcodebuild \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner -configuration Release -sdk iphoneos -arch arm64 \
  -derivedDataPath build/ios/derived \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" DEVELOPMENT_TEAM=""
# 打包未签名 IPA（AltServer 侧载用）
cd build/ios/derived/Build/Products/Release-iphoneos
mkdir Payload && cp -r Runner.app Payload/ && zip -qry Runner.ipa Payload
```

产物：`mobile/build/ios/derived/Build/Products/Release-iphoneos/Runner.ipa`（未签名，AltServer 重签）。

## 注意

- `flutter build ios` 输出已警告：上述两插件不支持 SPM「将在未来 Flutter 版本变成错误」，后续需升级 `flutter_secure_storage`（≥10 支持 SPM）并关注 `apple_maps_flutter` 的 SPM 支持，届时可彻底去掉 CocoaPods。
- macOS 桌面端同样存在未提交的 `macos/Podfile`（同机制生成），构建 macOS 版同样需要 pod。
- `~/.gem/ruby/2.6.0` 下有一次失败的 cocoapods 1.15.2 用户级安装残留，无影响，可删。
