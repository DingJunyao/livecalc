# BUGFIX：VS Code 里打不开 Flutter 运行调试（Windows 桌面构建失败）

## 现象

- VS Code 里选中 `.vscode/launch.json` 的 `Flutter` 配置（`type: dart`、`deviceId: windows`）按 F5，调试会话起不来（没有 app 窗口、没有报错对话框，只有构建输出一闪而过）。
- 终端里直接 `flutter run -d windows` 同样起不来。

## 复现（用 VS Code 实际使用的 SDK：`C:\opt\flutter_ori` = Flutter 3.44.8）

```powershell
cd mobile
C:\opt\flutter_ori\bin\flutter.bat build windows --debug
```

1. 第一次：**107ms 就失败**

```
CMake Error: Error: generator : Visual Studio 17 2022
Does not match the generator used previously: Visual Studio 18 2026
Either remove the CMakeCache.txt file and CMakeFiles directory or choose a different binary directory.
Building Windows application...                                    107ms
Unable to generate build files
```

2. 删掉 `mobile/build/windows` 后重跑：推进到 C++ 编译再报

```
...flutter_secure_storage_windows_plugin.cpp(6,10): error C1083: 无法打开包括文件: "atlstr.h" [...]
Building Windows application...                                   122.7s
Build process failed.
```

3. 带 `VCToolsVersion=14.44.35207` 重跑：**通过**

```
Building Windows application...                                    94.7s
√ Built build\windows\x64\runner\Debug\livecalc_mobile.exe
```

## 根因（两个问题叠加）

1. **CMake 生成器不匹配（旧缓存被写死）**
   `mobile/build/windows/x64/CMakeCache.txt`（2026-08-10）记录的是
   `CMAKE_GENERATOR=Visual Studio 18 2026` +
   `CMAKE_GENERATOR_INSTANCE=C:/Program Files (x86)/Microsoft Visual Studio/18/BuildTools`（MSVC 14.51）。
   而现在 Flutter（3.44.8）`vswhere` 检测到的是 `Visual Studio 17 2022`
   （`C:\Program Files\Microsoft Visual Studio\2022\Community`，见 `flutter doctor -v` 输出里的「Visual Studio Community 2022 17.14.41」）。
   → CMake 拒绝在同一 build 目录里换生成器，直接 "Unable to generate build files"，调试会话连编译阶段都进不去。

2. **ATL 缺失（v143 工具集版本口径）**
   `flutter_secure_storage_windows` 硬依赖 ATL（`atlstr.h`）。CMake 生成的工程里是
   `<PlatformToolset>v143</PlatformToolset>`，MSBuild 按
   `VC\Auxiliary\Build\Microsoft.VCToolsVersion.v143.default.txt` 解析实际工具集 →
   **14.38.33130**，而该目录没有 `atlmfc`（`VC\Tools\MSVC\14.38.33130\atlmfc` 不存在）。
   同一个 VS 安装里的 **14.44.35207** 有 ATL（`atlmfc\include\atlstr.h`），它也是
   `Microsoft.VCToolsVersion.default.txt` 的默认值。
   8 月那次修的是 VS 18 BuildTools 的 ATL（14.51），所以当时有效，换到 VS 17 Community 后用不上。

## 修复

1. 删掉失效的 CMake 缓存目录 `mobile/build/windows`（或 `flutter clean`），让 CMake 用当前 VS（17 2022）重新生成。
2. 让 Windows 构建使用带 ATL 的工具集：
   - 已在 [.vscode/settings.json](.vscode/settings.json) 的 `dart.env` 里加
     `"VCToolsVersion": "14.44.35207"`：VS Code 里 F5 起的 flutter 进程会带上它（`dart.env` 会注入 Dart/Flutter 扩展启动的所有进程）。
   - 终端 / 其他 shell 里的 `flutter run -d windows` 也需要同一个变量：加到用户级环境变量或 shell 配置；或给 VS 2022 Community 的 v143 工具集装上 ATL 组件（VS Installer → 修改 → 单个组件 →「适用于最新 v143 生成工具的 C++ ATL」）。
3. 验证：`VCToolsVersion=14.44.35207 flutter build windows --debug` → 94.7s 产出 debug exe。

## 顺带记录（同一环境里的隐患）

- 本机有两个 Flutter SDK：VS Code 走 `dart.flutterSdkPath = C:/opt/flutter_ori/bin`（3.44.8，Dart 3.12.2），PATH 前端是 `C:\opt\flutter_flutter`（3.41.10-ohos，Dart 3.11.5）→ `flutter doctor -v` 会报两条 "not inside your current Flutter SDK checkout" 警告，`.dart_tool/version` 也在两个版本间来回跳。
- `.vscode/settings.json` 里 `dart.offline: true`：仓库里提交的 `pubspec.lock` 要求 Dart ≥ 3.13（含 hooks 2.2.0 / code_assets 2.1.0 / record_use 1.1.1 等本地 pub 缓存里没有的版本），离线解析只能静默降级 —— 实测 VS Code 每次启动的 pub get 都 `Changed 186 dependencies!` 并改写 `pubspec.lock`。建议按用途只保留一个默认 SDK，并考虑关掉 `dart.offline`。

## 经验

- 「VSCode 打不开 Flutter 调试」先看构建日志：Flutter 的调试会话依赖同一次构建，构建秒挂就是起不来。
- CMake 缓存会把「用哪个 VS 生成器」写死；切换 VS / 工具链后必须删 `build/windows`，否则报的是一句与真实问题无关的 generator mismatch。
- `PlatformToolset=v143` 的实际工具集版本由 `Microsoft.VCToolsVersion.v143.default.txt` 决定，**不等于** `Microsoft.VCToolsVersion.default.txt`；版本对不上就会出现「同一个 VS 里一个工具集有 ATL、另一个没有」。
