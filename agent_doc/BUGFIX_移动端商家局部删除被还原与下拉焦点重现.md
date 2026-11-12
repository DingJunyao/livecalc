# 移动端商家局部删除被还原 + 其余下拉焦点重现排查

日期：2026-11-12　分支：feat/mobile-app（未提交）

## 用户报告

1. 输入并选取商家后想改商家：选中部分文本删除做不到，一旦按删除键都从末尾删除（其他下拉无此问题）。
2. 此前修过「商家在扫码后出现下拉」，请排查其他下拉是否有同类问题。

## 问题 1：选中商家后删改被整体还原（退格只从末尾删）

### 根因

`price_record_form_screen.dart` 与 `price_record_edit_screen.dart` 的商家 `Autocomplete.fieldViewBuilder` 里有一个**每次 rebuild 都注册的单向 postFrame 同步**：

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (_merchantController.text != controller.text) {
    controller.text = _merchantController.text; // ← 外部 controller 推回输入框
  }
});
```

而 `onChanged` 只清 `_merchantId`，不把用户编辑回写 `_merchantController`。于是：

- 选中商家后首次编辑必然触发 `setState(_merchantId = null)` → rebuild → postFrame 判定两 controller 不等 → **把旧商家名整体推回输入框**，光标跳到末尾 → 用户「选中部分文本删除」被还原，后续退格表现为只从末尾删；
- 纯手输（未选中）时 `_merchantId == null` 不触发 setState，侥幸不被还原；
- 全仓 `addPostFrameCallback` 排查：该模式仅这两处（quick_fill/黑名单/合并对话框/商品原料下拉均无外部 controller 同步），与「其他下拉没有」吻合。

### 修复

两个价格屏的 `onChanged` 回写镜像：`_merchantController.text = value`，两边恒等 → postFrame 比较相等不再回写。编辑屏异步加载/新增屏会话记忆的 prefill 推送路径不受影响。

## 问题 2：其余 Autocomplete 的「焦点恢复重现面板」排查

SDK 机制（`autocomplete.dart`）：

- `_canShowOptionsView = focusNode.hasFocus && _options.isNotEmpty`；`_select()` 选中后面板 hide，但**焦点保留**、`_options` 留存旧搜索结果；
- `_onFocusChange`：重新获得焦点且 options 非空时**直接 show 旧 options，不重跑 optionsBuilder** —— 扫码/选日期等路由进出后焦点恢复即重现面板（商家问题根源）；
- 异步 optionsBuilder（防抖搜索）另有竞态：点选后未完成的搜索 future 一完成就 `_updateOptionsViewVisibility`，焦点仍在则面板重现。

排查 6 处 Autocomplete：

| 位置 | 结论 |
| --- | --- |
| 新增/编辑价格屏商家 | 已有 unfocus（此前修复） |
| quick_fill 商家 | 已有 unfocus（`_selectMerchant`） |
| product_form 原料下拉 | **本次补 unfocus**（屏内有条码扫码，风险实锤） |
| ingredient_detail 合并对话框 | **本次补 unfocus**（异步防抖竞态） |
| blacklist 原料下拉 | **本次补 unfocus**（屏内虽无扫码/对话框，收起键盘让新 chip 可见 + 防患） |

其他下拉类控件（单位/币种 DropdownButtonFormField、商品搜索结果 Card）不依赖焦点，无此问题。

### 附带发现：unfocus 从源头掐断输入法回声

`FocusManager.unfocus()` → `TextInput._clearClient()` 同步置空 `_currentConnection`，之后 `TextInputClient.updateEditingState` 一律按失效 client 丢弃（text_input.dart:2241 id 校验）——点选后补发的组合态回声到不了输入框。product_form 的 300ms 保护窗口保留作纵深防御。

## 测试

- 新增回归：新增屏 + 编辑屏「选中商家后删改文本不被还原成旧商家名（局部删除生效）」（用 `testTextInput.updateEditingValue` 模拟真机局部删除；`enterText` 是整段替换模拟不了）；product_form「点选原料后释放焦点，避免扫码/选日期返回时下拉重现」。
- **echo 对照用例修正**：unfocus 后 `testTextInput.updateEditingValue` 无 client 变 no-op，「保护窗口结束后正常编辑仍会清空选择」需先 `tap` 重新聚焦再更新；echo 主用例补失焦断言。
- stash 对照：仅回退两个价格屏 lib 文件时，两个删改回归用例失败（证明抓得住旧 bug）。

## 验证

- `flutter analyze` 0 issue。
- 相关子集 77 例全过：price_record_form 24、edit_product_change 3、product_form_autocomplete_repro 10、ingredient_detail 3、quick_fill 4、product_form 4 文件 33。

## 坑

- pubspec.lock 会被隐式 pub get 改写（本次 analyze 触发），跑完要还原。
- `testTextInput.updateEditingValue` 在无 IME client（已失焦）时是静默 no-op：失焦后模拟输入必须先 `tap` 聚焦，否则用例假通过或断言反转。
- Autocomplete 的面板重现靠**旧 `_options` 缓存**而非重跑 optionsBuilder——给 optionsBuilder 加「已选则返回空」防护挡不住焦点恢复重现。
