# 移动端分析/详情页四反馈修复

日期：2026-08-08
分支：feat/mobile-app
状态：完成，TDD 82/82 全绿

## 反馈列表

| # | 位置 | 反馈 |
|---|------|------|
| ① | 菜谱分析·成本趋势 | 默认应显示「月」（当前默认「季」） |
| ② | 菜谱分析·成本趋势 | 没做成面积图（所有折线的填充都叠到 x 轴底部，层间颜色难以分辨） |
| ③ | 菜谱分析·按商家预估成本 / 商家比价推荐 | 鼠标无法左右滑动 |
| ④ | 菜谱详情·成本趋势 | 范围选择无效（选什么图表都不变）；下拉缺失「年」 |

## 根因与修复

### ① 默认「月」

分析页 initState 显式 `reloadHistory(90)`（对齐 web 默认「季」）→ 改为 `load(initialDays: 30)`，注释标明「用户要求，非 web 的『季』」。

### ② 真堆叠面积图

**根因**：fl_chart 1.2.0 的 `belowBarData` 只能从**自身曲线**填充到 x 轴（`cutOffY=0`，无逐点下边界）。原实现每条线独立填充，色带全叠在 x 轴底部，层间色被下一条线覆盖 → 看不出层。

**修复**：**倒序绘制**——顶层先画、底层最后画，底层色带覆盖顶层色带下半部分，露出层间色带：

```dart
final lineBars = <LineChartBarData>[];
for (var i = series.length - 1; i >= 0; i--) {
  final s = series[i];
  final highlight = _highlightIndex == i;
  final dimmed = isHighlighted && !highlight;
  lineBars.add(LineChartBarData(
    spots: s.spots, color: s.color,
    barWidth: highlight ? 2.5 : 1.5, isCurved: true, curveSmoothness: 0.35,
    dotData: const FlDotData(show: false),
    belowBarData: BarAreaData(show: true,
      color: s.color.withValues(alpha: dimmed ? 0.05 : 0.30)),
  ));
}
```

**连带影响**：`barIndex` 与 lineBarsData 数组下标绑定，倒序后：
- tooltip 映射 `seriesIndex = series.length - 1 - spot.barIndex`
- `touchedSpots` 改为**降序**排序（底部→顶部逐层累计）
- `dayIndex` 锚点（距离升序 first）必须在排序**前**取，否则锚点被 barIndex=0 的底部线污染

### ③ 鼠标无法横向滚动

**根因**：Scrollable 水平轴滚轮逻辑取 `scrollDelta.dx`；鼠标滚轮 dy → delta=0 → 不注册 `PointerSignalResolver` 也不滚动，事件落到外层垂直 Scrollable。

**修复**：新建共享组件 `mobile/lib/shared/widgets/mouse_wheel_horizontal_scroll.dart`：

```dart
class MouseWheelHorizontalScroll extends StatelessWidget {
  final ScrollController controller;
  final Widget child;

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || event.kind != PointerDeviceKind.mouse) return;
    if (!controller.hasClients || controller.position.maxScrollExtent <= 0) return; // 未溢出交还页面
    GestureBinding.instance.pointerSignalResolver.register(event, (e) => _handleScroll(e));
  }
  void _handleScroll(PointerSignalEvent e) {
    if (e is! PointerScrollEvent || !controller.hasClients) return;
    final next = (controller.offset + e.scrollDelta.dy)
        .clamp(0.0, controller.position.maxScrollExtent).toDouble();
    if (next != controller.offset) controller.jumpTo(next);
  }

  @override
  Widget build(BuildContext context) =>
      Listener(onPointerSignal: _handlePointerSignal, child: child);
}
```

接入：`merchant_cost_cards.dart`、`merchant_price_matrix.dart` 改 StatefulWidget 持 `ScrollController`（dispose 释放）+ 外包该组件。

### ④ 详情页范围选择无效

三个真因，逐一修复：

1. **切换时无任何加载反馈**：慢查询时旧数据一直显示到新数据到达，用户误以为「选什么都没反应」。→ 200 高 Stack，`widget.loading && points.isNotEmpty` 时顶部 `LinearProgressIndicator(minHeight: 2)`。
2. **后端上限 422**：`days: Query(90, ge=7, le=365)`，「全部」3650 天直接 422 → 放宽 `le=3650`（recipes.py 两处 replace_all，加注释）。
3. **缺失「年」**：`enum _Range { week, month, quarter, year }` + labels 加 `'year': '年'` + switch 加 `_Range.year => 365`。

数据封顶现象（历史 <30 天时月/季返回相同数据）为数据本身少，无法修；加载反馈让用户明白在等。

## 测试

TDD 先红后绿，新增 6 个测试（共 82/82 全绿）：

| 测试 | 断言 |
|------|------|
| 默认「月」 | 初始筛选为 month、回调 30 |
| 堆叠面积倒序绘制 | `lineBarsData` first.y==5 番茄顶层、last.y==2 鸡蛋底层、全部 belowBarData.show |
| 选年回调 365 | 切换「年」触发 onRangeChange(365) |
| loading 有旧数据 | LinearProgressIndicator 出现、旧图保留 |
| 商家卡片滚轮 | 5 卡溢出 + hover ListView + scroll(0,100) → pixels > 0 |
| 比价矩阵滚轮 | 8 商家溢出 + hover SingleChildScrollView + scroll → pixels > 0 |

## 续：追加 2 项反馈（⑤⑥）

日期：2026-08-09

### ⑤ 比价矩阵：用量显示 + 食材/用量列冻结

**根因**：Flutter Table 无 CSS `position: sticky` 能力；且食材单元格只渲染了 `row.name`，漏了 `row.quantityDisplay`（web `.qty-badge`）。

**修复**：拆表方案——

```
Row
├── 冻结列 Container（surface 背景盖住滚动内容 + 右 1px 分隔线）
│   └── Table(columnWidths: {0: FixedColumnWidth(150)})
│       ├── 表头「食材 / 用量」
│       └── 每行：名称 + 用量 badge（灰色 12px）+ fallback 图标
└── Expanded(MouseWheelHorizontalScroll + SingleChildScrollView + 商家列 Table)
```

**关键**：两 Table 必须统一行高 `_rowHeight = 44`（每个单元格外包 `SizedBox(height: _rowHeight)`），否则冻结列与滚动列逐行错位。

### ⑥ 堆叠面积图色带不透明

**根因**：正常态色带 0.30 alpha 太淡，各食材层间颜色体现不出。

**修复**：

```dart
belowBarData: BarAreaData(
  show: true,
  // 色带不透明（用户要求）：正常态纯色，层间颜色可辨；仅点食材标签
  // 高亮时非焦点淡出（alpha 0.2）凸显焦点项
  color: dimmed ? s.color.withValues(alpha: 0.2) : s.color,
),
```

## 续 2：⑦ 比价矩阵表头上对齐

日期：2026-08-09

**根因**：拆表后表头单元格是 `SizedBox(height: 44, child: _headerCell(...))`。SizedBox 带 child 时 width/height 是 **tight 约束**，Padding+Text 被顶对齐（数据行是 Row 撑满 + crossAxisAlignment.center 自动居中，表头 Padding 没有对齐机制）。

**修复**：`_headerCell` 用 `Align` 包 Padding（`centerRight` / `centerLeft`），撑满外层 SizedBox 后垂直居中。

```dart
Widget _headerCell(ThemeData theme, String text, {bool right = false}) {
  return Align(
    alignment: right ? Alignment.centerRight : Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
    ),
  );
}
```

**验证**：TDD 85/85 全绿（新增「表头垂直居中」测试）+ analyze 0 新增 + build windows 31.4s。

**经验**：
- 断言「视觉垂直居中」**不能用 `getCenter`**：tight 约束把 Text 的 box 撑满整行高（44），box 中心恒等于行中心，顶对齐时 getCenter 假绿（实测坑：首版测试误以为绿）。须 `renderObject<RenderParagraph>().getBoxesForSelection(const TextSelection(baseOffset: 0, extentOffset: 1))` 取第一个字符 paint box，`getTopLeft(f).dy + box.top + (box.bottom - box.top)/2` 换算全局视觉中心。本 SDK RenderParagraph.textPainter 是私有字段、TextBox 无 height/center getter（用 top/bottom 手算）。
- 首版断言实测值：顶对齐时表头与数据行视觉中心间距 58.2，居中时 44——区分度 ~14px，可靠。

## 验证

- `flutter test`：85/85 全绿（84 + ⑦表头居中；⑤⑥ 的 2 个新测试 + 2 个既有测试追加断言）
- `flutter analyze`：6 个 issue 全为预先存在（avoid_print、_fmtNum unused、色板命名、3 个 const），改动文件 0 新增
- `flutter build windows --debug`：23.2s 通过（先杀占用 PID 13812 的调试进程，MSB3073）
- 后端未改动

## 经验（续）

- **tap Text 不触发 chip**：M3 InkWell 的命中区域拦截了 label Text 的 hit test（`tap(find.text('鸡蛋'))` 有 warnIfMissed 警告且 onPressed 不触发）→ 须 tap `find.ancestor(of: find.text('鸡蛋'), matching: find.byType(ActionChip))`。
- fl_chart 150ms 数据动画：色带/折线等 data 属性须 `pump(200ms)` 走完动画才读到目标值（pump 一帧是动画起点旧值）。
- 新版 Flutter `Color.alpha`（int）弃用 → 用 `.a`（double 0-1）。
- 冻结列测试里 `find.text('¥11.00')` 验证最右商家滚入（jumpTo(maxScrollExtent) 后）。

## 经验（上一轮）

- `PointerSignalResolver`（`GestureBinding.instance.pointerSignalResolver`）只保留**第一个**注册的回调，且回调类型为 void。
- `TestPointer.scroll(Offset)` 只收一个位置参数，位置靠先 `hover` 设置；hover 必须落在滚动区域内（Scaffold 会把组件拉满全屏，组件中心可能在列表下方空白处，hit 不到 Listener）。
- 测试里的局部 helper 函数名不能带下划线前缀（`no_leading_underscores_for_local_identifiers` lint）。
- fl_chart 倒序绘制堆叠面积图后，tooltip 的 seriesIndex 与排序逻辑必须同步改，锚点计算须先于排序。
