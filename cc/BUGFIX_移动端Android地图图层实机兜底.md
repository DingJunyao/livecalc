# BUGFIX：移动端 Android 实机地图图层只剩 OSM

## 现象

Windows 调试时商家/选点地图能看到高德、腾讯、OSM；Android 实机测试时图层菜单只剩 OSM。

## 根因

Android 与 Windows 共用同一条地图配置链路：`GET /merchants/map-config` 返回 `available_maps` 后过滤出移动端支持的三层瓦片。差异在异常兜底：移动端配置请求失败后回退为 OSM-only 并标记已加载，失败结果会保留整次会话；Web 端配置失败则保留完整图层列表。实机网络、服务器地址或启动时序更容易让第一次配置请求失败，于是 Android 被永久固定在 OSM-only。

## 修复

- `map_config_provider.dart` 的初始/异常/空配置兜底改为完整三层：高德、腾讯、OSM，默认高德。
- 配置接口成功时仍按后端 `available_maps` 与 `default_map` 过滤，管理员配置不被覆盖。
- 回归测试覆盖请求失败与 `available_maps` 为空两个场景，防止再次退回 OSM-only。

## 验证

- `flutter test test/features/merchants/providers/map_config_provider_test.dart`：7/7 通过。
- `flutter analyze`：0 issue。
- `flutter test --no-pub`：402/402 通过。
