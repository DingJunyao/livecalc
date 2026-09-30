# FEATURE_移动端维护功能与审核体验

> 日期：2026-08-17
> 分支：feat/mobile-app（仅移动端）
> 背景：用户反馈移动端复杂维护表单不应放在对话框中，营养维护缺少 USDA 导入，原料关系图、菜谱维护、回车提交、邀请码配置和审核状态语义需要与 Web 端对齐。

## 需求

1. 原料、商品详情中的营养成分、自定义单位/密度、关联原料等复杂维护入口改为独立页面；返回和完成时回到正确来源页。
2. 检查其他维护入口：需要维护的参数不少于两项时，同样使用独立页面。
3. 营养维护支持搜索、预览并写入 USDA 数据，交互对齐 Web 端。
4. 原料详情除关联原料列表外，提供关系图。
5. 菜谱补齐创建、编辑、发布、删除等维护能力。
6. 服务器配置、登录、注册页按回车等价于点击确认按钮。
7. 注册页邀请码是否显示和必填由服务器配置决定，不由用户选择。
8. 涉及数据的增删改时，正确区分后端“已生效”和“待审核”结果。

## 实现

### 独立维护页面

| 路由 | 页面 | 用途 |
| --- | --- | --- |
| `/entities/:entityType/:entityId/nutrition` | `NutritionEditScreen` | 原料/商品营养维护 |
| `/entities/:entityType/:entityId/units` | `EntityUnitsScreen` | 自定义单位、未映射单位和密度维护 |
| `/ingredients/:id/hierarchy` | `IngredientHierarchyScreen` | 关联原料列表与关系维护 |
| `/merchants/new`、`/merchants/:id/edit` | `MerchantFormScreen` | 商家新增/编辑 |
| `/profile/places/new`、`/profile/places/:id/edit` | `UserPlaceFormScreen` | 常用地点新增/编辑 |
| `/prices/record/edit` | `PriceRecordEditScreen` | 价格记录编辑 |
| `/recipes/new`、`/recipes/:id/edit` | `RecipeFormScreen` | 菜谱新增/编辑 |

- 原料/商品详情把营养、单位密度、层级关系入口从对话框改为路由页面；页面完成后按 `Navigator.pop(result)` 返回，来源页根据结果刷新，避免停留在过期数据上。
- 商家、常用地点、价格记录编辑也改为整页表单。地图选点、商家搜索等原有能力保留。
- 菜谱列表新增入口和详情维护菜单进入整页表单，表单支持原料行维护、数量区间、单位、可选标记和备注。
- 剩余对话框仅用于删除/发布确认、信息展示、单项选择或筛选条件，不再承载两项以上参数的维护表单。

### USDA 营养导入

- 新增 [usda_repository.dart](../mobile/lib/features/nutrition/repositories/usda_repository.dart)：
  - `GET /usda/search?q=...&limit=...` 搜索食材。
  - `GET /usda/{fdc_id}` 获取营养详情。
  - `POST /usda/match/{entity_type}/{entity_id}` 提交匹配，`entity_type` 仅允许 `ingredient`、`product`。
- [NutritionEditScreen](../mobile/lib/shared/screens/nutrition_edit_screen.dart) 提供“手动 / USDA”分段模式：
  - 手动模式保留原有营养编辑和清空自定义数据入口。
  - USDA 模式支持关键词防抖搜索、中英文描述、数据类型、营养数量、详情预览和二次确认。
  - 确认后提交 FDC ID；后端返回 `MutationReviewResult` 时按 pending/applied 展示。
  - 打开编辑页时会回填现有营养数据，避免已有数据被误显示为空。

### 原料关系图

- 新增 [hierarchy_graph.dart](../mobile/lib/features/ingredients/widgets/hierarchy_graph.dart)：
  - 中心节点为当前原料，一级节点为直接父/子关联，二级节点来自展开关系。
  - `contains` 使用实线，`fallback` 使用虚线，`substitutable` 使用点线，并带方向箭头。
  - 支持 `InteractiveViewer` 缩放，图与列表同时展示。
- 关系维护继续使用后端 hierarchy API，新增、修改强度和删除均通过整页入口处理。

### 注册与提交体验

- 服务器配置、登录、注册页的输入框使用 `TextInputAction.done`，`onFieldSubmitted` 会复用确认按钮的提交函数；加载中不重复提交。
- 注册页监听 `authConfigProvider`，配置加载完成前禁用提交，避免用默认 false 误判“无需邀请码”。
- `AuthConfig` 优先读取后端实际字段 `registration_require_invite_code`，兼容旧字段 `require_invite_code`。
- 删除“是否填写邀请码”的用户开关；邀请码字段只在服务器要求时显示并校验必填。

### 审核语义

移动端不再把 HTTP 200 或后端返回的旧实体直接当作修改已生效：

- 原料、商品、商家更新：
  - 管理员按 applied 处理。
  - 普通用户即使后端返回更新前对象，也标记为 pending 并提示“已提交，待管理员审核”。
- 商品、商家删除：
  - 解析 `proposal_id`、`status`、`message`。
  - pending 时保留列表项/详情项，不执行本地删除。
- 单位、密度、营养手动保存、清空自定义营养、USDA 匹配：
  - 使用 `EntityWriteResult` 或 `MutationReviewResult` 区分 applied/pending。
  - pending 时提示审核状态，不把未落地的数据写回当前页面。
- 菜谱：
  - 私有创建、作者删除按直接生效处理。
  - 公开菜谱普通用户编辑、发布解析 proposal/status/message，pending 时返回列表或详情并提示审核中。
  - 详情解析 `pending_proposal` 并展示待审核提示。
- 原料、商品、商家详情模型解析 `pending_proposal`，详情页展示当前存在待审核变更。

## 后端契约备忘

- 普通用户更新原料/商品/商家时，后端可能返回 proposal 包装，也可能返回旧实体对象；移动端必须结合当前用户角色判定。
- 普通用户删除商品/商家时，响应可能包含 `proposal_id/status/message`；pending 表示未删除。
- 营养和 USDA 匹配响应可能只有 `message/status`，没有可落地的新营养对象。
- 注册配置实际字段为 `registration_require_invite_code`。
- 常用地点、价格记录、私有菜谱属于用户私有数据，正常直接生效。

## 测试

新增/更新覆盖：

- 营养编辑页已有数据回填、手动保存 pending、USDA 搜索/详情/匹配契约。
- 单位、密度整页维护和 pending 结果处理。
- 原料层级列表、关系图中心/一级/二级节点和层级维护 pending。
- 商家、常用地点、价格记录整页表单与返回刷新。
- 原料、商品、商家、菜谱增删改和发布的 applied/pending 分支。
- 登录/注册/服务器配置回车提交。
- 服务器要求邀请码时字段显示、必填和提交载荷；不要求时隐藏字段。

## 验证

- `flutter test`：361/361 通过。
- `flutter analyze --no-pub`：0 issues。
- `dart format .`：已执行。
- 未执行 Android/iOS/Windows 打包验证。
