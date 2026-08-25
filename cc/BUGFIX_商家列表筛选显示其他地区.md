# BUGFIX_商家列表筛选增加显示其他地区.md

## 用户反馈

- app 的商家列表筛选没有「显示其他地区的商家」，需要加上（web 端已有）

## 现状

- Web [MerchantsView.vue](frontend/src/views/data/MerchantsView.vue) 筛选栏有
  `include_other_regions` toggle（显示其他地区的商家），列表与坐标请求均透传
- 后端 `/merchants` 与 `/merchants/coordinates` 均已支持
  `include_other_regions`（默认按用户计算范围过滤，勾选后含全部地区）
- App 商家列表筛选底栏只有：显示已关闭商家 / 仅看我的收藏 / 未维护过价格

## 修复（feat/mobile-app，提交 3820046）

- [merchant_list_screen.dart](mobile/lib/features/merchants/screens/merchant_list_screen.dart)：
  筛选底栏新增「显示其他地区的商家」SwitchListTile（含副标题
  「含全部地区，不受计算范围限制」）；列表与地图坐标请求均透传新参数
- [merchant_provider.dart](mobile/lib/features/merchants/providers/merchant_provider.dart)：
  `MerchantListState` 增加 `includeOtherRegions` + copyWith；`applyFilters` /
  `activeFilterCount` / `load()` 透传
- [merchant_repository.dart](mobile/lib/features/merchants/repositories/merchant_repository.dart)：
  `search` 与 `getAllCoordinates` 增加 `includeOtherRegions` 参数 →
  `include_other_regions` 查询参数
- 底栏控件增多后矮屏溢出：`showModalBottomSheet` 加 `isScrollControlled: true`，
  内容包 `SingleChildScrollView`，超高可滚动（真实小屏 UX 修复）
- 收藏模式（favoritesOnly）走客户端过滤路径，region 过滤依赖后端子树计算
  无法客户端实现，与 web 行为一致（该组合不额外处理）

## 验证

- `flutter analyze` 0 issue；全量 `flutter test` 419/419
- 新增：筛选弹窗用例覆盖新开关（含开关状态保持）、
  「include_other_regions=true 透传」verify 用例

## 经验

- mocktail 的 `when` 闭包未显式注册的具名参数会用**方法签名默认值**（如
  `false`）作为精确匹配——代码新增可选参数后，老 stub 只匹配默认值，必须补
  `any(named: ...)`（本次 `includeOtherRegions: true` 调用因此返回 null 暴露）
- `showModalBottomSheet` 内容超高时：`isScrollControlled: true` +
  `SingleChildScrollView`，否则矮屏溢出
