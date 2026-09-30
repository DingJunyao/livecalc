# BUGFIX_移动端单位密度层级图连接池

> 日期：2026-08-17
> 分支：feat/mobile-app（后端修复先落在 master，再合并回当前分支）
> 背景：用户反馈单位密度页右下角加号无意义、层级关系图显示异常，且进入原料详情时后端报 QueuePool 连接池超时。

## 修复

### 单位与密度页

- [entity_units_screen.dart](../mobile/lib/shared/screens/entity_units_screen.dart) 删除右下角 FAB。
- 添加单位仍使用页面内的“添加单位”表单；密度页签不再出现加号清空这种无提示、无意义的操作。

### 层级关系图

- [hierarchy_graph.dart](../mobile/lib/features/ingredients/widgets/hierarchy_graph.dart) 按 Web 端语义修正箭头方向：
  - `contains`：父级指向子级。
  - `fallback`：子级指向父级。
  - `substitutable`：当前原料指向关联原料。
- 节点改为受力布局，按节点数量扩展虚拟画布，支持缩放和拖拽，节点不再挤出或叠在画布边缘。
- 保留一级/二级节点颜色、线型与 Web 端一致的语义。

### 原料详情 QueuePool 超时

根因是移动端原料列表为 20 个原料并发请求单原料最新价；进入详情页又并发 9 个详情接口。SQLite 等锁时，请求级 Session 叠加后容易把 `pool_size=15 + max_overflow=30` 打满，最终在 `/ingredients/{id}/latest-price` 上报 30 秒超时。

- `master` 新增 `GET /nutrition/ingredients/latest-price/batch?ingredient_ids=1,2,3`：
  - 一次请求、一个业务 Session 批量返回最多 50 个原料的最新价。
  - 单原料接口保持兼容。
  - 提交：`dc9b7ba fix: add batch ingredient latest price API`。
- `feat/mobile-app` 已合并该提交，[ingredient_repository.dart](../mobile/lib/features/ingredients/repositories/ingredient_repository.dart) 新增批量解析，[ingredient_provider.dart](../mobile/lib/features/ingredients/providers/ingredient_provider.dart) 原料列表改用一个批量请求。

## 测试

- 单位密度页确认没有 FAB。
- 层级图新增：
  - `fallback/substitutable` 方向与 Web 语义一致的回归测试。
  - 多节点仍在虚拟画布内的布局测试。
- 原料仓库层验证批量接口路径、ID 拼接和响应解析，并确认不再调用单原料接口。
- 后端批量接口覆盖多原料、去重和非法 ID。

## 验证

- 后端：`pytest tests/test_ingredient_latest_price_batch.py -q`，2/2 通过；`py_compile` 通过。
- 移动端：`flutter analyze --no-pub` 0 issues；全量 `flutter test` 373/373 通过。
- `git diff --check` 通过。
