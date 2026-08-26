# BUGFIX_币种地区表述统一与用户信息编辑补齐

## 用户反馈

- 移动端商家维护：国家/地区、省份、城市、区县四个下拉之间无竖向间距，不美观
- 移动端用户信息编辑不完整（web 有地区、密码），需参考网页补完
- app 与网页都有：币种在下拉/选择列表中的显示应为「名称+空格+三字母标识」（如
  「美元 USD」），选中后下拉框内可简化为三字母标识；需排查全系统所有币种展示处
- app 与网页都有：商家维护页地区表述「国家/地区、省份、城市、区县」与默认计算
  范围「国家/地区、省级、地级、县级」不一致，需统一；需排查全系统所有地区处

## 修复

### 移动端（feat/mobile-app，提交 b5137e7）

- [region_select_field.dart](mobile/lib/shared/widgets/region_select_field.dart)：
  四个级联下拉之间补 `SizedBox(height: 12)` 竖向间距
- [edit_account_screen.dart](mobile/lib/features/auth/screens/edit_account_screen.dart)
  补齐 web 用户信息编辑能力：新增「所在地区」四级级联（复用 `RegionSelectField`，
  支持注入 `MerchantRepository` 便于测试）与「修改密码（可选）」三字段（当前密码/
  新密码/确认新密码，sha256 后随 `PUT /auth/me/account` 提交，改密后沿用响应新
  token）；新增 `regionRepository` 构造参数
- [user.dart](mobile/lib/features/auth/models/user.dart)：`User` 增加 `regionId`
  （解析 `region_id`）
- [merchant_form_screen.dart](mobile/lib/features/merchants/screens/merchant_form_screen.dart)：
  默认币种下拉展开项改「名称 代码」（原为「符号 名称」），`selectedItemBuilder`
  收起时只显示三字母代码（未选显示「跟随地区」）
- [profile_screen.dart](mobile/lib/features/profile/screens/profile_screen.dart)：
  默认币种选择列表改「名称 代码」；默认计算范围选项与副标题统一为
  省份/城市/区县（原省级/地级/县级）

### 网页端（master，提交 3f20bc9，已合入 feat/mobile-app）

- [MerchantsView.vue](frontend/src/views/data/MerchantsView.vue) 与
  [MerchantDetail.vue](frontend/src/views/merchants/MerchantDetail.vue) 商家表单
  币种 `v-select`：`#item` 插槽显示「名称 代码」，`#selection` 插槽收起只显示
  三字母代码
- [ProfileView.vue](frontend/src/views/profile/ProfileView.vue)：默认币种
  `v-autocomplete` 同样双显示；「所在地区编辑」副标题改「国家/地区、省份、城市、
  区县」；账号/地区两处级联标签「省/州→省份、区/县→区县」；`scopeOptions`
  省级/地级/县级 → 省份/城市/区县
- [DataMaintenanceView.vue](frontend/src/views/admin/DataMaintenanceView.vue)：
  行政区划统计 chips「省/州→省份、区/县→区县」

## 排查结论

- 币种：六处价格表单（PriceRecordForm/QuickPriceRecordDialog/PricesView/
  ProductDetail/IngredientDetail/QuickFillView）此前已用「名称 代码」菜单 + 三字母
  按钮，App 价格新增/编辑页与快速填写页已用 `selectedItemBuilder`/PopupMenu 双显示，
  均符合规范；本次补齐商家表单、个人中心默认币种两处
- 地区：统一为「国家/地区、省份、城市、区县」；`RegionSelect`（web）/`RegionSelectField`
  （app）组件本身已是标准表述

## 验证

- `flutter analyze` 0 issue；全量 `flutter test` 426/426（新增：编辑页地区选择携带
  `region_id`、改密携带 sha256 哈希、密码组校验拦截、默认计算范围表述、默认币种
  列表「名称 代码」）
- 前端 `npm run build` 通过

## 经验

- `testWidgets` 里 Dio 请求不会失败而是**挂起**：`AuthInterceptor.onRequest` 的
  `FlutterSecureStorage.read` 在无 mock 平台通道时永不完成。测带网络请求的页面需
  先 mock 通道
  `MethodChannel('plugins.it_nomads.com/flutter_secure_storage')` 返回 null，
  再用自定义 `HttpClientAdapter`（抛错）让请求快速失败走兜底路径
- git 仓库用 worktree：master 在 `D:\code\live_calc.worktrees\master`，web 改动需
  在 master worktree 提交后再 `git merge master` 合入 feat/mobile-app
