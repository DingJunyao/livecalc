# 弹键盘后正文只剩 ~80pt（iPhone 13 Pro 输入不可用）

## 现象

iPhone Duo 适配完成后，在 iPhone 13 Pro（普通 iPhone）上打开任意「新增/编辑表单」
（用户示例：添加商家）弹键盘，正文被压成约 80pt 高（只露出商家名称和地址框的上边框），
键盘上方出现一大片空白，输入几乎无法使用。

截图实测（947×2048、约 0.809 缩放的 390×844 截图）：

- AppBar 底边 ≈103pt；
- 名称输入框 ≈108.7~161.4pt；地址框上边框 ≈176.3pt；
- 正文可视区在 ≈186pt 处被截断，其下全是页面背景色直到键盘顶（≈505pt）。

## 根因（壳层把键盘内边距带回了页面子树）

`ScaffoldWithNavBar` 的页面子树经过 [`_wrapPageMediaQuery`](../mobile/lib/core/router/app_router.dart)：
为了按 Duo 姿态改写 padding，它用**壳层 build context（在 Scaffold 之上）**取
`MediaQuery.of(context)` 再包一层 `MediaQuery` 给页面。此时取到的是**未经 Scaffold
消费**的原始 MediaQuery，`viewInsets.bottom` 还是键盘高度。

而外层壳层 `Scaffold` 默认 `resizeToAvoidBottomInset: true`：

1. 先把 body 收缩到键盘之上（844 − 329 = 515）；
2. 给 body 的 MediaQuery 里**去掉** `viewInsets.bottom`（Flutter `Scaffold._addIfNonNull`
   的 `removeBottomInset`）。

壳层这一层重新包 `MediaQuery` 时又把 `viewInsets.bottom` 原样带了回去，于是内层页面
自己的 `Scaffold` **再扣一次键盘高度**：

```
正文 = 844 − 329(键盘) − 103(页面 AppBar，含状态栏) − 329(又扣一次) ≈ 83pt
```

与截图实测的「正文约 83pt」完全吻合。Duo 改造前没有这层 wrapper，body 直接拿到
Scaffold 消费过的 MediaQuery，所以不会双扣——这是 Duo 适配引入的回归。

## 修复

`_wrapPageMediaQuery` 返回时保持 Flutter 的口径（body 收到的是「已消费掉键盘」的
MediaQuery）：

```dart
return MediaQuery(
  data: mq
      .copyWith(padding: padding)
      .removeViewInsets(removeBottom: true),
  child: child,
);
```

- 非 Duo / Duo 各姿态统一生效（壳层 Scaffold 无论哪种模式都会先收缩 body）。
- 底部弹层（`showModalBottomSheet`）挂在壳层 Navigator 的 Overlay 上，Overlay 本身已在
  收缩后的 body 内，因此不再需要 `viewInsets` 也仍在键盘之上；弹层内手动加的
  `EdgeInsets.only(bottom: MediaQuery.viewInsets.bottom)` 变为 0，与 Duo 改造前行为一致。

## 回归测试

`mobile/test/core/router/scaffold_with_nav_bar_test.dart`：

- 新增全屏表单探针路由 `/products/1/edit`（`_KeyboardProbePage` 记录正文高度）；
- `pump` 支持注入 `tester.view.viewInsets`；
- 「弹键盘时页面正文只扣一次键盘高度」：390×844 + 键盘 329，断言正文
  ≈ 844 − 329 − 56 = 459；修复前为 130。

## 验证

- `flutter test test/core/router`：72 例全过（含新增用例；去掉 `.removeViewInsets`
  时该用例失败，值为 130）。
- `flutter analyze`：0 error / 0 warning（251 info 均为存量）。
- iPhone 13 Pro 模拟器 + 真实壳层临时入口实测：键盘弹出后正文扩展到键盘顶（可滚动），
  不再出现大片空白。
