# BUGFIX：移动端腾讯底图错位（中国显示印尼）

## 现象

手机 APP 商家地图/选点对话框选择腾讯底图时严重错位：中国中、东部地区显示的是印尼。

## 根因

**腾讯瓦片服务的 y 轴是 TMS 风格（从南到北），与标准 XYZ（从北到南）相反。**

- web 端用的 `leaflet.chinatmsproviders` 插件，腾讯瓦片 URL 是 `y={-y}`（Leaflet 的 `{-y}` = `2^z-1-y` 翻转）：[leaflet.ChineseTmsProviders.js:139](frontend/node_modules/leaflet.chinatmsproviders/src/leaflet.ChineseTmsProviders.js#L139)
- 移动端 [map_config_provider.dart](mobile/lib/features/merchants/providers/map_config_provider.dart) 的 `tencentLayer` 直接写 `y={y}`，未翻转 → 北半球（中国）请求的 y 被腾讯当作南半球 y 来取瓦片 → 显示印尼。症状（错位到另一个半球国家）与 y 轴翻转完全吻合，而非 GCJ02 偏移（那是几百米，不是换国家）。

## 修复

1. `MapLayerOption` 加 `tms` 字段（默认 false）
2. `tencentLayer` 设 `tms: true` —— flutter_map 的 TileLayer `tms: true` 内部翻转 y（等价 Leaflet `{-y}`），模板里 y 保持 `{y}`
3. 两处 `TileLayer` 传 `tms: layer.tms`：[merchant_map_view.dart](mobile/lib/features/merchants/widgets/merchant_map_view.dart) / [map_point_picker.dart](mobile/lib/features/merchants/widgets/map_point_picker.dart)
4. URL 对齐 web：`styleid=1&version=207` → `type=vector&styleid=3`（web 样式，去旧 version 缓存号）

## 附带发现（测试盲区）

`map_point_picker_test.dart` 的 `pumpPicker` 只 override 了 notifier 构造，**从不触发 `load()`** → provider 状态恒为初始兜底（仅 OSM）→ `_pickLayer(ref.read(mapConfigProvider))` 在 initState 恒得 OSM：

- 所有「高德底图」断言实际走 OSM 路径**巧合通过**（GCJ02 偏差 ~0.003° 远大于 1e-4 容差，真走转换反而失败）——GCJ02 转换路径从未被真实测试
- 修复：pumpPicker 改用 `ProviderContainer` + 先 `await container.read(mapConfigProvider.notifier).load()` + `UncontrolledProviderScope`（uncontrolled 容器不会随测试 dispose）
- 顺带真实化「切底图到 OSM 后点击」测试：切底图不移动视角，中心仍是高德时的 GCJ02 北京，OSM 下点击返回显示坐标原样（= 旧 GCJ02 中心），期望值改为 `wgs84ToGcj02(北京)`

## 验证

- TDD 先写失败测试（修复前 `tile.tms == false` 红）：map_view「腾讯 tms=true + 高德 false」+ picker「腾讯 tms=true」
- 全量 201/201 全绿（+3 用例）
- analyze：改动目录 0 新增（全量剩 5 个预先存在的 recipe_provider_test info）
- build windows 通过（27.1s，先杀占用 build 输出文件的调试进程 PID）

## 经验

- 症状「错位到另一个国家/半球」≈ 瓦片 y 轴规则不符（TMS vs XYZ）；症状「偏移几百米」≈ GCJ02 转换缺失。看偏移量级能直接分诊
- 腾讯/天地图等国产瓦片服务多用 TMS y 轴，接新瓦片源先查该源的 y 轴约定，别默认 XYZ
- provider 测试若组件 initState 读 provider 状态，必须先触发 load，否则恒测初始兜底态
