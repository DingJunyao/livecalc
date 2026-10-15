# BUGFIX: 移动端扫码无反应（命中本库条码被吞）

- **日期**：2026-10-15
- **分支**：`feat/mobile-app`（纯移动端问题）
- **提交**：`c40445fe`（移动端）

## 现象

用户实机反馈：移动端「添加价格 → 扫码」，扫**一部分**商品条码毫无反应（包括但不限于几个枕装奶、火腿肠——都是已经录进本库的商品）。

## 根因（已用真实开发库证实）

后端 `resolve_barcode`（`backend/app/services/barcode_lookup.py`）在**本库命中**（`products.barcode` 或 `product_barcodes`）与**条码缓存命中**两条路径上**提前 return**，此时 `has_enabled_providers` 恒为 `false`：

```
6907992500942: found=True source=local has_enabled_providers=False name=伊利枕装纯牛奶 240mL id=1030
6910442121192: found=True source=local has_enabled_providers=False name=夏进枕装纯牛奶 227g  id=1031
6902890022558: found=True source=local has_enabled_providers=False name=双汇王中王优级火腿肠    id=1012
6902890258940: found=True source=local has_enabled_providers=False name=鸡肉火腿肠58g        id=1026
```

而移动端两个扫码入口把它当成「有没有结果」的闸门，**先于 `found` 判断**就早退：

```dart
// 旧实现（price_record_form_screen.dart / product_form_screen.dart）
if (!result.hasEnabledProviders) {
  return;   // ← 本库命中全被吞掉：扫码后毫无反应
}
if (result.found && result.product.id != null) { ... }
```

于是：**已建档商品（枕装奶/火腿肠等）扫码无反应；未建档商品的条码走外部服务返回 `has_enabled_providers=true`，反而正常弹「新建商品」对话框** —— 与用户「扫一些条码没反应」的描述完全吻合。

web 端早就没这个问题：`PricesView.vue` / `ProductsView.vue` 都是**先判 `found`**，只用 `has_enabled_providers` 区分「未命中」时的提示文案。

## 修复

`hasEnabledProviders` 只用于「未命中」时的文案分支，不再当闸门：

- **价格记录页**（`lib/features/prices/screens/price_record_form_screen.dart`）：判定改成只看 `found`；本库命中 → 直接选中商品（回填名称、切默认单位）；外部命中但无本地 id / 完全未命中 → 仍走既有的「未找到本地商品 → 新建商品」对话框（带外部服务返回的名称/品牌预填）。
- **商品表单**（`lib/features/products/screens/product_form_screen.dart`）：区分三种情况并给用户反馈（此前未命中和本库命中都是静默 return）：
  - 本库命中 → 提示「该条码已属于商品『X』，无需重复创建」，**不回填名称**（回填后保存会撞后端「条码已存在」校验）；
  - 外部命中 → 回填名称/品牌（原行为）；
  - 未命中 → 提示可手动填写。
- 新增 ARB 三语键 `productBarcodeNotFound` / `productBarcodeExists`。

## 验证

- `mobile/test/features/prices/screens/price_record_form_screen_test.dart` 新增「扫码命中本地已建档商品：hasEnabledProviders=false 也要选中商品」（用真机同款条码 `6907992500942` + 真实响应形状）。
- `mobile/test/features/products/screens/product_form_screen_test.dart` 新增「扫码命中已建档商品：提示已存在且不回填名称/品牌」。
- `flutter analyze` 0 error（仅存量 `onReorder` deprecation info）；两个测试文件全绿。

## 经验

1. **服务端「能力开关」字段不能当「结果开关」用**：`has_enabled_providers` 描述的是「配没配外部服务」，本地命中时服务端提前返回、该字段必然是 false —— 客户端把它当「有没有查到」的判据，就会把最常用的一条路径（本库命中）整片吞掉，而且**静默无日志**，只能靠用户报障发现。
2. **两端同一功能的行为要逐字对齐**：web 的判定顺序（先 `found` 再文案分支）是活文档，移动端照抄就不会错；这类「web 正常、移动端不正常」的问题，先 diff 两端的判定顺序。
3. **早退要留反馈**：任何 `return` 前没给用户可见反馈的分支，都会变成「点了没反应」类缺陷；本轮把商品表单的两处静默 return 都换成了提示。
