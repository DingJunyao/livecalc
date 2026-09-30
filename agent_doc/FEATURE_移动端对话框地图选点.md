# 移动端对话框地图选点（我的地点/商家）

## 需求

用户反馈：常用地点新增编辑、商家新增编辑，不是填写经纬度，而是让用户在地图上选点。
参照 web [MapPicker.vue](frontend/src/components/map/MapPicker.vue)（点图/拖 marker → convertToWGS84 → WGS84 存储）。

## 实现

### 新建 [map_point_picker.dart](mobile/lib/features/merchants/widgets/map_point_picker.dart)

FlutterMap 点击选点组件，回调返回 **WGS84**（数据库存储坐标系）：

- GCJ02 底图（高德/腾讯）：显示坐标 `_toDisplay`（wgs84ToGcj02）、存储 `_toWgs84`（gcj02ToWgs84 逆转换，单步近似逆固有误差 ~1e-5 度）；OSM 原样
- 底图由 `mapConfigProvider` 决定，右上角 PopupMenuButton 切换（key `picker-layer-switch`）
- `width` 参数：AlertDialog 会做 intrinsic 宽度查询，`double.infinity` 会穿透到 FlutterMap 内部 LayoutBuilder 抛 `LayoutBuilder does not support returning intrinsic dimensions` → 对话框传 300 固定宽短路
- `tileProvider` 参数：测试注入内存瓦片
- **自动滚动**：initState postFrame `Scrollable.ensureVisible(context, 300ms)` —— 对话框内容超高时地图在滚动视口外，打开即滚到地图可见（选点是核心操作）；无 Scrollable 祖先（非对话框场景）时 `Scrollable.maybeOf` 返回 null 直接跳过，不影响 picker 独立测试

### 对话框改造

- [my_places_screen.dart](mobile/lib/features/profile/screens/my_places_screen.dart) `_PlaceFormDialog`：删 `_lat`/`_lng` 控制器 + 坐标范围校验；地图选点**必选**（未选保存 → SnackBar「请在地图上选择位置」不发请求）
- [merchant_list_screen.dart](mobile/lib/features/merchants/screens/merchant_list_screen.dart) `_showMerchantDialog`：删 lat/lng 控制器；选点**可选**（未选 = 无坐标，地图上不显示，保留原语义）
- 测试注入通道：`MyPlacesScreen.mapTileProvider` / `MerchantListScreen.mapTileProvider` 透传到对话框（避免测试里真实 OSM 网络请求噪音）

## 关键坑（调试记录）

1. **对话框地图 tap 不生效（最隐蔽）**：对话框内容超高（4 字段 + 下拉 + 240px 地图 ≈ 700px）被压缩，SingleChildScrollView 视口仅 ~384px。地图布局 rect (250,396)-(550,636)，中心 y=516 **在视口 (96-480) 之外** → hit test miss 穿透到 Overlay（warnIfMissed 警告 hit 到 `_RenderTheater`）。**教训**：`getRect` 返回**未裁剪的布局 rect**，视口裁剪只影响 paint/hitTest 不影响布局 rect，测试取点前必须确认点在视口内；真机上用户也得先滚动对话框才看得到地图中心，是产品级 UX 缺陷 → 修法见「自动滚动」
2. **两个 FlutterMap 共存**：列表页 `initialShowMap: true` 时 MerchantMapView + 对话框 MapPointPicker 同时在树 → `find.byType(FlutterMap)` 匹配 2 个报 Too many elements → 须 `find.descendant(of: find.byType(AlertDialog), matching: find.byType(FlutterMap))`
3. **商家编辑 updateMerchant 直连真 repo**：`_showMerchantDialog` 保存走 `MerchantRepository().updateMerchant`（不走 provider）→ 测试 mock 不到（真请求 400）→ `MerchantListScreen` 加 `merchantRepository` 注入参数（对齐既有 `profileRepository` 模式），`_loadCoordinates` 顺带注入
4. tap 后 onChanged 需 pump 两帧（`pump(); pump(400ms)`）消化 flutter_map 双击判定链（PositionedTapDetector2 sink → stream.timeout(Duration.zero) → _onTapConfirmed → 250ms doubleTapDelay 超时 → onTap）

## 验证

TDD 全量 **193/193 全绿**（+11：MapPointPicker 6 + my_places 3 用例改造「新增流/403 流/未选点校验」+ 商家对话框 2 新增「添加选点 createMerchant 参数/编辑已有坐标换点 updateMerchant」）+ analyze 0 新增（剩 5 个预先存在）+ build windows 通过（55.2s，先杀占用进程）。
