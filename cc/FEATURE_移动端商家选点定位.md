# 移动端商家选点定位

## 需求

移动端新增、编辑商家时，在地图图层按钮右侧增加定位按钮。点击后获取当前位置，把地图移动到该位置，并立即将其作为商家坐标选中。

## 实现

- 新增 [map_locate_button.dart](../mobile/lib/features/merchants/widgets/map_locate_button.dart)：统一处理定位服务检查、权限申请/拒绝提示、高精度定位、10 秒超时、loading 与错误反馈，成功回调 WGS84 坐标。
- Android/瓦片地图 [map_point_picker.dart](../mobile/lib/features/merchants/widgets/map_point_picker.dart)：图层按钮和定位按钮合并在同一右上控件行；定位成功后设置 `_wgs`、触发 `onChanged`，并经 `_toDisplay` 转换后移动到 15 级视角。
- iOS/MapKit [apple_map_picker.dart](../mobile/lib/features/merchants/widgets/apple_map_picker.dart)：复用同一按钮；定位成功后设置 WGS84、更新标注、触发 `onChanged`，并动画移动到转换后的 MapKit 显示坐标。
- `MapPointPicker` 新增可选外部 `MapController`。不传时保持原来的内部创建与释放逻辑，传入时由调用方持有；这是为了让测试能断言镜头移动，也与商家地图组件的控制器模式一致。

## 测试

- `map_locate_button_test.dart`：成功回调坐标；权限永久拒绝时提示且不回调。
- `map_point_picker_test.dart`：按钮位于图层右侧；点击后回调 WGS84、显示选中标记与坐标文本，并把高德底图视角移动到对应 GCJ02 坐标。
- `apple_map_picker_test.dart`：按钮位于图层右侧；点击后回调 WGS84，并把标注更新到 GCJ02 显示坐标。

## 验证

- `flutter test test/features/merchants`：52/52 通过。
- `flutter test`：329/329 通过。
- `flutter analyze`：无新增问题；剩余 3 条为仓库既有 info（`avoid_print`、常量命名、测试多余 `const`）。
- `flutter build windows --debug`：通过，产物 `build/windows/x64/runner/Debug/livecalc_mobile.exe`。
