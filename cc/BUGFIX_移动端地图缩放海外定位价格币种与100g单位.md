# BUGFIX：移动端地图缩放、海外定位、记忆商家币种与 100g 单位

## 用户反馈
- iOS 地图无法手动缩放。
- 印尼定位有偏移，Android 也需排查。
- 新增价格记录复用记忆商家时未自动带出商家默认币种。
- 需要新增 100 g 单位，且范围不限于移动端。

## 根因与修复

### 地图
- iOS `AppleMap` 是平台视图，嵌在 Flutter 滚动容器中时未配置 eager gesture recognizer，pinch 手势会被父级滚动手势竞技场消费；`AppleMapPicker` 与 `AppleMerchantMap` 均补充 `EagerGestureRecognizer`。
- GCJ02 加密只应作用于中国区域。原移动端对全球坐标无条件执行 WGS84↔GCJ02，导致印尼约数百米偏移；新增中国区域判断，境外坐标原样使用 WGS84。Android 高德/腾讯瓦片与 iOS MapKit 共用该转换逻辑。

### 价格记录
- `PriceRecordFormScreen` 只在用户重新点选商家时应用商家默认币种；会话记忆商家异步回填名称时没有应用币种。现在初始化与商家列表异步回填都会同步默认币种，且用户手动改过币种后不会被异步回填覆盖。

### 100g 单位
- 后端启动种子为既有库幂等补齐 `100克 / 100g / mass / si_factor=0.1`，新库默认数据同样包含该单位。
- `UnitMatcher` 支持忽略缩写内部空格，`100 g` 可匹配 `100g`，避免误建计数单位。
- Web 动态单位来自后端；本地模式 seed/backfill、价格表单 fallback，以及商品/原料详情硬编码单位列表均补齐 `100g`。
- 移动端记录价格单位 fallback 补齐 `100g`。

## 验证
- `flutter analyze`：0 issue。
- `flutter test`：432/432 通过。
- `npm run build`：通过。
- 后端 `pytest tests/test_default_unit_seed.py`：2/2 通过；`py_compile app/main.py app/services/unit_matcher.py` 通过。
- `git diff --check`：通过。
