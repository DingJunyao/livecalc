# iOS 构建链路（Mac 虚拟机）与无签名 IPA

> 环境：VMware 虚拟机中的 macOS 15.7.7（Intel/AMD 宿主，4 vCPU / 8 GB），
> Xcode 26.3（iOS 26.2 SDK），Flutter 3.47.8 stable，CocoaPods 1.17.0（conda ruby 3.3.6）。
> 仓库：`~/code/livecalc`（分支 `feat/mobile-app`）。

## 0. 结论速览

| 问题 | 结论 |
| --- | --- |
| 能不能在 VM 里构建 iOS 包 | **能**，已验证 `flutter build ios --release --no-codesign` 成功，产物 26.7 MB |
| 能不能在 VM 里跑模拟器 | **只能跑一半**：iPhone 17（iOS 26.3）模拟器能启动、能装 App、SpringBoard 正常，但 **Flutter 画面全黑**——VMware 虚拟 GPU 不支持 Metal，日志明确 `Software rendering is incompatible with Impeller` |
| 能不能验证 iPhone Duo 适配 | **不能**。Duo 需要 Xcode 27.1（且需要 macOS 26+），当前 Xcode 26.3 打出来的包装到 Duo 上会"居中显示 + 四周留白" |
| 能不能真机调试 | 需要 USB 透传 + Xcode 登录 Apple ID（免费账号 7 天签名）。更省事：VM 只负责出包，Windows 用 Sideloadly 重签安装 |
| 无签名 IPA | 已提供脚本 `scripts/build-unsigned-ipa.sh`，产物可直接用于重签工具 |

## 1. 一次性环境（已在这台 VM 装好）

由于 macOS 15 的系统 Ruby 2.6 不再带头文件（`ruby.h` 缺失），`gem install cocoapods`
会在编译 `nkf` 原生扩展时失败，因此改用 conda 提供的 Ruby 3.3：

```bash
# 1) Flutter 3.47.8（用国内镜像，约 2.2 GB）
curl -L -o ~/Downloads/flutter_3.47.8.zip \
  https://storage.flutter-io.cn/flutter_infra_release/releases/stable/macos/flutter_macos_3.47.8-stable.zip
cd ~ && unzip -q ~/Downloads/flutter_3.47.8.zip        # 得到 ~/flutter

# 2) Miniforge + Ruby 3.3
bash ~/Downloads/miniforge.sh -b -p ~/miniforge
~/miniforge/bin/conda create -y -n ios -c conda-forge ruby=3.3

# 3) CocoaPods
export PATH="$HOME/miniforge/envs/ios/bin:$PATH"
gem install cocoapods --no-document

# 4) 写入 ~/.zshrc（已执行，勿重复）
cat >> ~/.zshrc <<'EOF'

# iOS build toolchain: Flutter 3.47.8 + CocoaPods (conda ruby 3.3)
export PATH="$HOME/flutter/bin:$HOME/miniforge/envs/ios/bin:$HOME/miniforge/envs/ios/share/rubygems/bin:$PATH"
export GEM_HOME="$HOME/miniforge/envs/ios/share/rubygems"
export GEM_PATH="$GEM_HOME:$HOME/miniforge/envs/ios/lib/ruby/gems/3.3.0"
EOF
```

校验：`flutter doctor` → Xcode ✓、CocoaPods ✓（Android/Chrome 缺失不影响 iOS）。

> 注意：conda 安装的 gem 可执行文件在 `envs/ios/share/rubygems/bin`，而 `pod` 启动时
> 需要 `GEM_HOME` 指向 `envs/ios/share/rubygems`，否则报
> `can't find gem cocoapods (>= 0.a) with executable pod`。上面的 `.zshrc` 已处理。

## 2. 日常构建：无签名 IPA

```bash
cd ~/code/livecalc
./scripts/build-unsigned-ipa.sh            # release，增量构建约 30-60s
./scripts/build-unsigned-ipa.sh --clean    # 全量（VM 上约 4 分钟）
./scripts/build-unsigned-ipa.sh --output /tmp/ipa   # 指定输出目录
```

产物：`mobile/build/ios/ipa/livecalc-<CFBundleShortVersionString>+<CFBundleVersion>-unsigned.ipa`
（脚本用 `ditto` 打包 `Payload/Runner.app`，保留符号链接与权限，并打印大小与 SHA256。）

脚本做的检查/兜底：
- 非 macOS 直接退出；找不到 Xcode / Flutter / CocoaPods 时给出明确提示；
- `mobile/.gitignore` 忽略了 `*.g.dart`，全新克隆时自动跑
  `dart run build_runner build --delete-conflicting-outputs` 生成 Drift 代码
  （否则 xcodebuild 会报 `The getter 'offlineQueue' isn't defined for the type 'AppDatabase'`）；
- Xcode < 27 时打印"非 Duo 优化版"的提醒；
- 兼容 Flutter 新旧产物目录（`build/ios/iphoneos` 与 `build/ios/Release-iphoneos`）。

## 3. 模拟器：能跑，但 Flutter 画面黑屏（**重要限制**）

```bash
xcrun simctl boot "iPhone 17"          # 已启动过可跳过
cd ~/code/livecalc/mobile
flutter build ios --simulator --debug  # 首次约 3 分钟
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
xcrun simctl launch booted com.livecalc.livecalcMobile
xcrun simctl io booted screenshot /tmp/shot.png
```

实测结果（2026-10-26）：
- SpringBoard、设置等 **UIKit 界面正常渲染**，App 图标（生计）能看到；
- 打开本 App 后 **整屏黑**，进程存活、Flutter 引擎在跑，日志里是：

  ```
  Runner: (Flutter) Software rendering is incompatible with Impeller.
  Software rendering may have been automatically selected when running on a simulator in an
  environment that does not support Metal. Enabling GPU passthrough in your environment may fix this.
  ```

  这是 **VMware 虚拟 GPU（VMware SVGA，128 MB）不支持 Metal** 导致的，属于宿主/虚拟化层限制，
  不是项目配置问题。试过在 Info.plist 写 `FLTEnableImpeller=false` 也不生效（Skia 后端同样要求 GPU）。

**结论：这台 VM 可以用来"编译、出包、验证签名/打包流程"，但不能用来"看 Flutter 界面"。**

替代方案（按推荐度）：
1. **Windows 桌面版**（`cd mobile && flutter run -d windows`）+ 拖窗口到 890×626 / 626×890，
   验证布局与宽屏表现（同一套 Flutter 代码，最接近 Duo 的宽高比）；
2. **Android 模拟器/真机** 验证交互与表单；
3. 真机 iPhone：用 VM 出的无签名 IPA，在 Windows 上 Sideloadly 重签后安装（唯一能验证 iOS 真机行为的方式）；
4. 想在这台 VM 里看 iOS 界面，需要给虚拟 GPU 做 Metal 直通（VMware 一般不支持），
   或换成 Apple Silicon Mac / 云 Mac。

## 4. 装到 iPhone 上（无签名包怎么用）

未签名 IPA 不能直接安装，必须用 Apple ID 重签：

- **Sideloadly / AltStore / eSign**：免费 Apple ID 重签，**7 天有效**、最多 3 个 App；
  装完到 设置 → 通用 → VPN 与设备管理 里信任证书。
- **付费开发者账号（$99/年）**：1 年有效，可用 Xcode 直接 Run，或
  `xcrun devicectl device install app --device <UDID> <app>`。
- 免费账号也可以直接在 Xcode 里 Run（VM 需要把 iPhone USB 透传给虚拟机，
  并在 Xcode → Settings → Accounts 登录 Apple ID）；这条路受 VM USB 透传限制，不如
  "VM 出包 + Windows 重签" 稳。

## 5. 本轮一并补的 iOS 上架硬伤

| 项 | 改动 |
| --- | --- |
| 自建 http 服务器连不上 | `Info.plist` 增加 `NSAppTransportSecurity`（`NSAllowsArbitraryLoads`+`NSAllowsLocalNetworking`）与 `NSLocalNetworkUsageDescription` |
| 相册权限崩溃/审核质询 | 增加 `NSPhotoLibraryUsageDescription` |
| 阿拉伯语未登记 | `CFBundleLocalizations` 增加 `ar` |
| 出口合规每次手答 | `ITSAppUsesNonExemptEncryption=false` |
| 缺 App 隐私清单 | 新增 `ios/Runner/PrivacyInfo.xcprivacy`（UserDefaults CA92.1 / FileTimestamp C617.1 / DiskSpace E174.1）并加入 Xcode Resources |
| 部署目标与 Flutter 不一致 | `project.pbxproj` 三处 13.0 → **15.0**（Flutter 3.47.8 最低要求） |

> ATS 放开任意 http 是为了让用户填写的自建服务器可用；若 App Store 审核质询，
> 可收窄为"仅局域网 + 指定域名例外"。隐私清单里的 Required Reason API 依据
> 依赖实际使用的库（shared_preferences / drift+sqlite3），插件自带的清单会合并。

## 6. 常见坑

1. `pod install` 报 `can't find gem cocoapods` → 缺 `GEM_HOME`（见第 1 节）。
2. 系统 Ruby 编译 `nkf` 失败 → macOS 15 起系统 Ruby 无头文件，用 conda ruby。
3. `flutter build ios` 报 "requires a Development Team" 但其实失败在 Dart 编译：
   先看 xcodebuild 的真实报错（本次是缺 `app_database.g.dart`）。
4. `apple_maps_flutter` 只支持 CocoaPods（Flutter 提示将来会变成错误），
   因此 iOS 构建必须装 CocoaPods，且首次构建会自动生成 `ios/Podfile`。
5. `mobile/pubspec.lock` 在不同 Flutter 版本下会被 `pub get` 改写，提交前注意 diff。
6. Intel Mac 已被 Flutter 标记为弃用（3.47.8 起 `flutter doctor` 有警告），
   后续大版本可能无法再在 VM 上构建。

## 7. 与 iPhone Duo 的关系

- 这套链路只能验证"App 能跑、布局别崩"，**不能验证 Duo 的竖排系统栏、内屏填充、折缝避让**。
- Duo 适配需要：Xcode 27.1 + macOS 26（当前 VM 不满足），或用 Apple Silicon Mac / 真机。
- 作为过渡，可先用 890×626 的模拟器窗口（iPad 或自定义尺寸）检查宽屏布局，
  但系统竖排栏行为只能靠 Xcode 27.1 的 Duo 模拟器确认。
