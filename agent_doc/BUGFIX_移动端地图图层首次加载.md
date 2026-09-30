# BUGFIX：移动端地图图层首次加载不完整

## 现象

移动端首次新增商家并打开选点地图时，图层菜单只有 OSM；先进入商家地图或第二次打开选点后，高德/腾讯/OSM 才全部出现。商家详情地图与“我的地点”选点也依赖这份异步配置，存在同类首屏兜底泄漏。

## 根因

`MapConfigState` 初始值是保守兜底“仅 OSM”，但图层配置由商家列表页异步加载；`MapPointPicker` 在 `initState` 固定读取这次瞬时状态，后续配置到达也不会更新当前底图。首次打开弹窗时，用户能在请求完成前看到并操作这个不完整菜单，误以为只有 OSM 可用。

## 修复

- `MapConfigNotifier.load()` 增加并发合并与完成缓存，多个地图入口共享一次请求，不再重复暴露初始兜底。
- Android `MapPointPicker` 自行触发配置加载；配置完成前显示同尺寸加载占位，不渲染图层菜单。
- 商家列表地图与商家详情地图等待配置完成后再渲染，避免首帧 OSM-only。
- “我的地点”选点复用同一个 `MapPointPicker`，随之修复。
- iOS 保持原有 MapKit 分支，不加载该瓦片配置，也未修改 Apple 地图实现文件。

## 验证

- 新增失败测试先行：选点弹窗、商家列表地图、商家详情地图在配置未完成时不渲染 `FlutterMap`；配置请求并发合并且完成后缓存。
- `flutter test` 全量 325/325 通过。
- `flutter analyze` 无新增问题（仅 3 条预先存在的 info）。
- `flutter build apk --debug` 因本机缺少 Android SDK（`ANDROID_HOME` 未配置）无法执行。
- `flutter build windows --debug` 通过；首次构建被正在运行的调试 EXE 占用，释放后重跑成功。
