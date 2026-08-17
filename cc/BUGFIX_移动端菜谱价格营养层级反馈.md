# BUGFIX_移动端菜谱价格营养层级反馈

> 日期：2026-08-17
> 分支：feat/mobile-app（仅移动端）
> 背景：用户反馈菜谱创建按钮样式、编辑流程、价格记录入口、原料层级图和营养编辑渲染与 Web 端体验不一致，且营养编辑页在移动端出现右侧溢出。

## 修复

### 菜谱创建按钮

- [recipe_list_screen.dart](../mobile/lib/features/recipes/screens/recipe_list_screen.dart) 使用与其他列表一致的 `FloatingActionButton`，按钮内仅显示 `Icons.add`。
- 保留“创建菜谱”tooltip，不显示按钮文字。

### 菜谱分段编辑

- [recipe_form_screen.dart](../mobile/lib/features/recipes/screens/recipe_form_screen.dart) 创建模式仍一次提交完整菜谱。
- 编辑模式拆为基本信息、原料、步骤、小贴士四块独立保存：
  - 基本信息只提交发生变化的字段，对齐 Web 端 `RecipeBasicCard.vue`。
  - 原料提交 `{ "ingredients": ... }`。
  - 步骤提交 `{ "cooking_steps": ... }`。
  - 小贴士提交 `{ "tips": ... }`。
- 每块保存后留在编辑页，可继续处理其他区块。
- 返回详情或列表时携带 `RecipeFormResult`，来源页据此刷新；pending 只表示已提交待审核，不当作修改已生效。

### 价格记录入口统一

- [price_record_form_screen.dart](../mobile/lib/features/prices/screens/price_record_form_screen.dart) 新增 `PriceRecordFormPrefill`，支持商品、原料 ID 和商品锁定状态。
- 原料详情、原料列表、商品详情、商品列表的“记录价格”入口统一跳转 `/prices/record`，复用通用价格记录表单。
- 原料入口自动预填同名或第一个关联商品，商品搜索限制在该原料范围内；商品入口锁定当前商品。
- 表单包含商品、价格、数量、单位、商家、计入支出、记录时间和备注，与一般价格维护页字段保持一致。
- 编辑既有价格记录仍使用原 `PriceRecordEditScreen`。

### 原料层级关系图

- [ingredient_detail_screen.dart](../mobile/lib/features/ingredients/screens/ingredient_detail_screen.dart) 的层级卡片直接嵌入 [hierarchy_graph.dart](../mobile/lib/features/ingredients/widgets/hierarchy_graph.dart)。
- 有关系时详情页同时展示可缩放关系图和关系列表，图中心为当前原料名。

### 营养编辑溢出

- [nutrition_edit_screen.dart](../mobile/lib/shared/screens/nutrition_edit_screen.dart) 的营养编辑行改为移动端两行布局：
  - 第一行：营养素下拉。
  - 第二行：数量、单位和删除按钮。
- 下拉使用 `isExpanded: true`，避免长营养素名称在窄屏挤压右侧控件导致渲染溢出。

## 测试

- 菜谱列表测试确认创建按钮只有加号图标、没有文字标签。
- 菜谱表单测试验证编辑模式四个分段 payload 相互独立，创建模式仍整页提交。
- 价格表单测试覆盖原料预填、原料限定商品搜索、商品锁定和完整字段。
- 原料详情测试确认层级卡片包含关系图。
- 营养编辑测试新增 320px 窄屏场景，确认无渲染异常。

## 验证

- `flutter analyze --no-pub`：0 issues。
- `flutter test`：370/370 通过。
- `git diff --check`：通过。
