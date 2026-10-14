# 移动端原料搜索下拉：IME 重复组合态导致下拉为空

## 现象

移动端新增商品，在「搜索并选择关键原料」输入「牛奶」，转圈结束后下拉为空；删掉「奶」只保留「牛」后，下拉又能显示「牛奶」。可稳定复现。

## 根因

`RawAutocomplete.optionsBuilder` 会在中文 IME 结束组合时，因 `TextEditingValue.composing` 变化而再次收到同文本回调。第二次回调文本未变，`RawAutocomplete._onChangedField` 的 `shouldUpdateOptions` 为 false，但仍会调用 `optionsBuilder`。

移动端原实现每次 `optionsBuilder` 调用都会重新启动一次 300ms 防抖请求，并 `cancel` 上一次请求。于是：

1. 第一次「牛奶」回调（composing 尚未清空）启动请求 A；
2. IME 提交后第二次「牛奶」回调（composing 为空）取消请求 A、启动请求 B；
3. 请求 A 的 `_onChangedField` 因 callId 变旧丢弃结果；请求 B 对应的 `_onChangedField` 因 `shouldUpdateOptions=false` 也丢弃结果。

结果就是转圈结束（请求 B 已完成）但没有任何下拉项。

## 修复

对三个使用远程搜索的 `Autocomplete<Ingredient>` 统一处理：当同 query 的请求仍在途时，直接复用同一个 Future，不再取消重开。这样第一次回调仍会应用结果，第二次回调按 RawAutocomplete 规则丢弃，不会丢选项。

- `mobile/lib/features/products/screens/product_form_screen.dart`
- `mobile/lib/features/ingredients/screens/ingredient_detail_screen.dart`
- `mobile/lib/features/profile/screens/blacklist_screen.dart`

另在 `product_form_autocomplete_repro_test.dart` 增加回归用例：同文本先带 composing、再清空 composing，断言下拉仍显示结果。

## 验证

- `dart analyze`（改动文件）无问题。
- `flutter test test/features/products/screens/product_form_autocomplete_repro_test.dart` 应通过。
