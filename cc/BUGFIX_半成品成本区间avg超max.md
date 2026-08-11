# 菜谱成本区间 avg 超 max 修复（半成品成本区间递归）

## 现象

菜谱「蛋炒饭」(recipe_id=280) 成本趋势图出现不可能结果：avg=15.80，区间 6.14~13.24（avg 超出 max）。

## 根因（口径撕裂）

提交 `cc55a18`（重构菜谱成本区间趋势）引入 **双轨口径撕裂**——`calculate_recipe_cost_range_trend` 里 avg 和 min/max 走两条独立路径：

- **avg_cost**：调 `calculate_recipe_cost_as_of`，含完整 5 层降级链（direct 加权 → fallback/substitutable → name_match → 半成品菜谱推导 → CONTAINS 子食材聚合）
- **min/max_cost**：函数内手写，只覆盖「direct + fallback + substitutable + CONTAINS」，**缺 name_match 与半成品推导**

后果：只在「半成品推导」或「name_match」下才有价的食材，min/max 路径贡献 0、avg 路径算出正成本，把 avg 顶到 max 之上。元凶是**米饭**(ing 179，半成品：`serving_weight=400`，由菜谱 185 产出)，avg 经 `_get_cost_from_recipe` 推导 3.66 元，min/max 完全漏算。

## 方案（双轨收敛单轨）

新增递归 [calculate_recipe_cost_range_as_of](backend/app/services/recipe_service.py#L1443) `-> {min_cost,max_cost,avg_cost,cost_breakdown}`。每食材按价格来源产出 `(min,max,avg)`，菜谱总成本三档各自求和。**凸组合数学保证**：每层 `min_i≤avg_i≤max_i` → 求和/加权后总体 `min≤avg≤max` 恒成立。trend 逐天循环删双轨改单轨（只调一次新函数）。

5 层降级链 1:1 映射（[recipe_service.py](backend/app/services/recipe_service.py)）：
- direct 直接商品 → [_direct_cost_range_ppg](backend/app/services/recipe_service.py#L1250)
- fallback/substitutable → [_fallback_cost_range_ppg](backend/app/services/recipe_service.py)
- name_match → [_name_match_cost_range_ppg](backend/app/services/recipe_service.py)
- 半成品菜谱推导 → [_get_cost_from_recipe_range](backend/app/services/recipe_service.py)（递归 range ÷ 产量）
- CONTAINS 聚合 → [_contains_cost_range_ppg](backend/app/services/recipe_service.py#L510)（子食材按 strength 加权，凸组合）

关键工具纯函数 [_ppgs_to_range](backend/app/services/recipe_service.py)（Task 7 抽出）：一组每克单价 → `(min,max,avg)`，过滤 None 与 ≤0 脏数据，空池返 None。脏数据过滤 [_is_dirty_record](backend/app/services/recipe_service.py)（price≤0 或 standard_quantity≤0）。

## Task 7b：意外挖出的 standard_quantity 数据脏问题

Task 7（DRY 抽 _ppgs_to_range）规范审查深查发现：r280/90 天 24 个违规。根因不在 Task 7，而是 `_direct_cost_range_ppg` 的 **avg override**——三档里 avg 用 `resolve_direct_weighted_for_cost` 的 `av_ppg`（加权路径，经 `_product_unit_price` 依赖记录的 `standard_quantity`），min/max 用逐条 `_convert_record_to_price_per_gram`（走 original 口径）。

对 ingredient 2 product 2 差 50 倍：`standard_quantity` 数据脏（original=30 斤，standard_quantity=30 未转 g，应 15000g），`_product_unit_price` = 13.90/30 = 0.4633 元/g（545 元/kg 离谱）；逐条走 original 口径 = 0.00842 元/g（8.42 元/kg 合理）。av_ppg=0.278 > max(ppgs)=0.012 → avg 超 max 23 倍。

**修复**（[recipe_service.py _direct_cost_range_ppg](backend/app/services/recipe_service.py#L1250)）：放弃 av_ppg 覆盖，三档全部来自 `_ppgs_to_range(ppgs)`（逐条 `_convert_record_to_price_per_gram` 走 original 口径，对数据质量鲁棒）。24 违规全消除，365 天 0 违规。

## 收尾（最终整体审查后）

无 Critical/High。处理 3 项：
- **contains 层 avg 对齐**：[_get_child_price_per_gram_range](backend/app/services/recipe_service.py#L461) direct 命中时 avg 原用代表记录 avg_ppg（min/max 用 clean 极值），极端脏数据（代表记录 price≤0 但同日有 clean 记录）下可能 avg<min。改 `return rng`（三档同源，与 direct 层 Task 7b 范式一致），塌缩分支（极值集空）保留代表记录
- **删孤儿函数** [_std_unit_price_to_per_gram](backend/app/services/recipe_service.py)：全 backend 零调用（Task 7b 放弃其在 range 版唯一调用者），32 行死代码，零风险删
- **trend 异常日志**：[calculate_recipe_cost_range_trend](backend/app/services/recipe_service.py#L1508) `except Exception: continue` 加 `logger.debug`（文件顶部新增 `import logging` + `logger = logging.getLogger(__name__)`），便于调试逐天失败

未动：`_contains_cost_range_ppg` else 分支（strength 全 0 退化为简单平均）死代码——pre-existing 从 single 版复制，保持对称。

## 验证

- py_compile 通过、单测 5 passed（[_ppgs_to_range](backend/app/services/test_recipe_service.py) 4 例 + 空壳 1）
- 端到端（连主仓库 sqlite 库）：r280/r5/r10/r50/r100 各 90 天 + r280 365 天，**TOTAL violations=0**
- subagent-driven 7 任务（每任务执行者 + 两阶段审查：规范合规后代码质量）+ Task 7b 修复 + 最终整体审查，全 subagent 成功（此前会话模型配置损坏已恢复）

## 边界遗留（不影响本次正确性）

- **single 版 resolve standard_quantity 问题**：`calculate_recipe_cost_as_of`（单点）的 direct 层仍走 resolve 加权路径，standard_quantity 脏数据会放大单点成本。range 版不受影响（已改逐条）。single 版修复需另案
- **fallback drift**（如火腿242→火腿肠240，RANGE 聚合 vs SINGLE 首商品最新，drift 2.437）：合理设计差异，不影响 min≤avg≤max，非 bug
- 性能：365 天约 43 秒（逐天递归），可接受；批量预加载优化留作后续（YAGNI）

## 教训

- **口径撕裂是区间计算的隐形杀手**：min/max/avg 必须同源同链，任何「avg 走 A 链、min/max 走 B 链」的捷径都会在 B 链覆盖不全时翻车（尤其兜底层 name_match/半成品）
- **验证窗口要够大**：Task 6、Task 7 执行者都只测 30 天就放过，靠规范审查员深查 90 天才炸出 24 违规。端到端验证必须覆盖 90/365 天
- **数据质量脏字段是潜伏放大器**：standard_quantity 转换未落地让 resolve 路径放大 50 倍，量小无感、靠 Task 7 DRY 抽函数才暴露。对数据质量鲁棒的 original 口径优于依赖脏字段的 standard 口径
- **subagent-driven 两阶段审查有效**：规范审查炸出执行者测试盲区（avg override 数学），代码质量审查兜底死代码/孤儿函数

设计 [2026-08-11-半成品成本区间递归-design.md](../docs/plans/2026-08-11-半成品成本区间递归-design.md) + 计划 [2026-08-11-半成品成本区间递归.md](../docs/plans/2026-08-11-半成品成本区间递归.md)。
