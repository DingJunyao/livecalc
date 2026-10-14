# BUGFIX：自定义单位显示「1 个 = 200 g」变成 0.2 g（si_factor 口径用错）

> 2026-10-14。用户反馈：商品 665（贝贝南瓜）设置自定义单位「1 个 = 200 g」，
> 保存后页面显示「= 0.2 g」，编辑时又正常（说明**存的数据对，只有显示算错**）。

## 真因（一层就能定位，但语义必须先查清楚）

`units.si_factor` 的语义是「换算成 **SI 基本单位**」的因子，**不是**「每 1 个单位等于多少 g/mL」：

| 维度 | 基准 | 真实值（开发库 / 种子数据） |
|---|---|---|
| 质量 | **kg** | g = 0.001、两 = 0.05、100g = 0.1、斤 = 0.5、kg = 1、lb = 0.453592 |
| 体积 | **L**（不是 m³） | mL = 0.001、tsp = 0.005、tbsp = 0.015、fl oz = 0.03、cup = 0.24、L = 1 |

权威出处：`backend/app/main.py` 建表注释「si_factor 以 kg 为基准，100g = 0.1kg」、
`unit_conversion_service.py`「SI 质量单位是 kg」/「体积 si_factor 换算到 SI 基本单位 L（不是 m³）」。

而 web 两个详情页的列表显示函数直接 `数量 × si_factor`：

- 质量：200 × 0.001 = **0.2**（用户看到的就是这个）
- 体积：220 mL 会算成 0.22 → 再 `× 密度 / 1000` → **≈0.2 g**（同一个错，差 1000 倍）
- 编辑弹窗里的体积折算提示同样假设「一定是 mL」：选 L 会再差 1000 倍

**为什么之前没被发现**：两端的单测夹具都把 `siFactor` 写成 `1`（服务端不存在这种值），
错误公式乘 1 恰好得到"看起来对"的结果——`1 个 = 200 g`、`1 盒 = 220 mL（≈226.6 g）`
这些用例全部通过，真实数据一上就现形。**夹具用假值 = 测试白写**。

## 修复

### web（本次用户报的那一端）

- 新增纯函数模块 `frontend/src/utils/unitFactor.ts`，把口径与折算链集中到一处并写成注释：
  - `gramsPerGlobalUnit(unit, density)`：质量 `si×1000` g；体积 `si×密度` g
    （体积 L→m³ 的 ×0.001 与 kg→g 的 ×1000 恰好抵消）；计数/长度单位返回 null
  - `millilitersPerGlobalUnit(unit)`：体积 `si×1000` mL，质量返回 null
  - `overrideAmounts(row, rowsById, globalsById, density)`：一条覆盖行「1 个该单位」折算出
    `{grams, milliliters}`；递归支持嵌套引用（visited 防环 + 深度上限 8）、
    `weight_per_unit` 缺省按 1、未设重量单位按克——与后端 `resolve_override_amount` 同口径
- 单测 `frontend/src/utils/unitFactor.test.ts`（9 例，已并入 `npm run test:utils`），
  **夹具改用真实 si_factor**（g/mL = 0.001、kg/L = 1、斤 = 0.5）；含用户场景
  「200 g → 200 g」、kg/斤叶子、mL/L 叶子、嵌套 `1 箱 = 12 盒 → 2719.2 g`、
  环引用/引用断裂/缺 si_factor 不臆估
- 两个详情页改用 `overrideAmounts`：
  - 质量行：`1个 = 200 g`（不再乘 si_factor）
  - 体积行：显示折算后的 mL 与 g（`1瓶 = 5000 mL（≈5000 g）`），**不再把「个数」当 mL 打印**
  - 嵌套行：显示引用单位名（`1箱 = 12 盒`），体积叶子后补「（≈ N g）」（新增
    `unitChainVolumeDisplay` 三语），删除因此失效的 `unitVolumeOnlyDisplay`
  - 单位弹窗体积提示改用 `量 × si(L) × 密度`
- 交叉印证：本地（离线）模式的 `api/local/business/unitConverter.ts` 本来就是正确写法
  （`amount × si × 密度` / `amount × si × 1000`），本次显示层与它对齐。

### 移动端（同一口径，同一 bug）

`entity_units_card.dart` 的 `_resolveUnit`（`gramsOf`/`walk`）与 `_volumeHint` 是同一个错，
一并修正；卡片单测夹具同样改为真实 `siFactor`。

## 验证

- web：`npm run build` ✓、`check:i18n` ✓、`check:i18n:sources` ✓、`test:utils` **27/27** ✓
  （原 18 + 新增 9）
- 实机页面复核：`http://localhost:5173/data/products/665` 的自定义单位行显示
  「1个 = 200 g」（修复前为 0.2 g）
- 移动端：`flutter analyze` 0 issue、`flutter test` 全量 617 通过 + 6 项既有失败
  （apple_map×3、locale_preferences×2、my_proposals×1）

## 经验

1. **数值列的单位语义必须先查权威出处再写公式**：`si_factor` 这种"看起来像换算系数"的列，
   基准是 kg / L 还是 g / mL 会让结果差 1000 倍；后端注释与既有正确实现（本地模式
   `unitConverter.ts`）是现成的答案，照着对，不要凭直觉乘。
2. **测试夹具要用真实量级**：两端夹具都写 `siFactor: 1` 时，错误公式乘 1 也能通过——
   这类"假值夹具"会把系统性错误整片掩盖。夹具应该抄服务端种子数据（g=0.001、mL=0.001、
   kg=1、L=1、斤=0.5）。
3. **同一换算要在所有展示位统一**：本次同一公式在 web 两个详情页 + 移动端卡片 +
   两个编辑弹窗提示共 6 处重复实现，改一处不够；集中成有单测的纯函数（web `unitFactor.ts`）
   才能真正收敛。
4. **「编辑时正常、列表里不对」= 存储正确、展示层算错**，先看展示层的换算，不要动数据。
