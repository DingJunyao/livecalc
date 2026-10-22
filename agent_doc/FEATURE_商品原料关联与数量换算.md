# FEATURE：商品/原料「关联与换算」（两两等式）

日期：2026-10-22
范围：后端 + Web + 本地模式；移动端随后同步。

## 需求与结论

用户的两类场景：

1. 方便面单包 / 五连包 / 整箱：条码不同、当前是多个商品；希望关联并做 `1 提 = 5 包` 这类换算。
2. 干香菇 / 鲜香菇：不能合并成一个原料；缺价时可按比例折算，但菜谱仍可区分。

上一版「包装组（基准商品 + 成员 + 整组编辑）」被用户重置，原因是入口/交互太绕、只能同原料、结果看不懂。
本次改为 **两两关联，一条关联 = 一句可读等式**：

```
1 提 五连包 = 5 包 单包
3 kg 鲜香菇 = 1 kg 干香菇
```

不引入基准/成员/组；不合并实体；有直接价时永远用直接价，关联只用于：

- 单位折克（让「提」能通过「1 提 = 5 包、1 包 = 85 g」算出 425 g）；
- 缺价时的每克价补位（菜谱成本 / 原料折算价 / 各商家折算价）。

## 数据模型

`entity_quantity_links`：

```
id
from_type / from_id / from_quantity / from_unit
to_type   / to_id   / to_quantity   / to_unit
note
is_active
AuditMixin（created_at/updated_at/created_by/updated_by）
```

语义：`from_quantity [from_unit] from = to_quantity [to_unit] to`。
多态端点（product / ingredient）不建 DB 外键，应用层校验；同一对实体不分方向只允许一条活跃关联。

## 后端

- `services/entity_link_service.py`：校验、当前视角归一化、`resolve_unit_grams()`（沿关联递归折克，visited 防环）、`link_price_factor()`、最新价与序列化。
- `unit_conversion_service.convert(..., allow_links=True)`：只在未知/计数单位且目标为质量时尝试关联折克；`allow_links=False` 防递归。
- 成本链：`direct → entity_link → legacy fallback → recipe → contains`。
  - `recipe_service._linked_cost_range_ppg()`：原料自身关联 + 原料下商品关联；对方无直接价时可沿关联递归（多层包装）。
  - `_direct_cost_range_ppg` / `_get_child_price_per_gram[_range]` / `_relation_cost_range_ppg` 均接入。
  - `source="entity_link"`，chain 带完整等式。
- 各商家：`latest-price-by-merchant` 在 fallback 前补原料关联行，价格 ÷ factor，`is_derived=true`。
- 关联写操作走提议框架（`entity_quantity_link`，manual + mid）；create/update/delete/revert 后沿关联 BFS 重算受影响商品/原料的价格记录折克。
- 删除/合并保护：有关联的商品/原料先要求解除；不自动迁移，避免关系端点悬空。
- 导出 `entity_quantity_links.json`；导入按 mapping/名字重映射，缺失端点跳过并 warning。
- 迁移：`alembic/versions/20261022_0001_entity_quantity_links.py` + 三引擎 SQL。

## Web

- `components/entities/EntityQuantityLinksSection.vue`：
  - 放在商品/原料详情「单位与密度」卡内；
  - 行内显示完整等式、`1 提 ≈ 425 g` 自检、对方最新价折合；
  - 商品页额外只读展示「所属原料的关联」；
  - 添加/编辑对话框：当前实体只读、目标类型（商品/原料）、搜索、两边数量/单位（combobox，可手输）、实时预览；
  - 无「基准/成员/组/方向」。
- `utils/entityLinks.ts`：等式格式化、单件等价价、单位合并；单测 4 例。
- 价格表单（QuickPriceRecordDialog / PriceRecordForm）合并关联单位，并在价格/数量/单位下显示对方折合价。
- `charts.sourceEntityLink` 三语；i18n 新键在 ingredients 命名空间。

## 本地模式

- IndexedDB v6 `entity_quantity_links`；`handlers/links.ts` CRUD；proxy 路由。
- `business/entityLinks.ts`：折克/因子/序列化。
- `costCalculator`：`CostInput.links`，direct → link → fallback → contains。
- 导出/导入纳入 store；云端导入按名字重映射端点。

## 验证

- 后端新增 `tests/test_entity_quantity_links.py` 4 passed：折克（提→包→箱 1700 g）、因子、成本链（干/鲜 0.02 元/g）、API CRUD / 待审。
- 相关回归：`test_ingredient_price_series` 5 passed、`test_ingredient_price_service`、`test_nested_unit_override`、`test_recipe_service`、`test_export_*`、`test_price_aggregator_recompute` 共 70 passed。
- Web：`npm run build` ✓、`npm run test:utils` 70 passed、`check:i18n` / `check:i18n:sources` ✓。
- 正式库 SQL（不使用 Alembic）：[SQLite](backend/scripts/sql/20261022_entity_quantity_links_sqlite.sql) / [MySQL](backend/scripts/sql/20261022_entity_quantity_links_mysql.sql) / [PostgreSQL](backend/scripts/sql/20261022_entity_quantity_links_postgresql.sql)；脚本含备份提示、执行后验证 SQL 与回滚语句。
- 已知限制：本次链接不参与营养折算；本地模式暂未做 link-aware 的记录 standard_quantity 重算（成本链的原料关联可用）。

## 经验

1. 「关联」必须是一句用户能读出来的等式；行内直接给克重自检和对方价格折合，比任何术语都有效。
2. 直接价优先 + 关联只做缺价补位，避免把推算价混进真实记录，也不会重演「组权重」争议。
3. 单位折克是包装场景的核心；只做展示不折克，价格仍然是错的。
4. 旧的 `ingredient_hierarchies` 完全不动；新关联是独立概念，避免和层级图谱/旧替代语义缠在一起。
