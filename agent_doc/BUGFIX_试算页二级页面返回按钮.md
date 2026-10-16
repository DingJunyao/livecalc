# 试算页二级页面缺返回按钮

## 现象

`/plans` 的二级页面（编辑已有方案、新增方案）没有返回按钮，只能翻侧栏或点「取消」回到列表；
移动端同一个编辑页在**加载失败的错误态**也没有返回（正常态有）。

## 修复

- `frontend/src/views/plans/PlansView.vue`
  - AppBar 补 `<v-btn v-if="editing" icon="mdi-arrow-left" variant="text" @click="closeEditor" />`，
    与 `views/recipes/RecipeDetail.vue:5` 完全同写法（侧栏汉堡 + 返回箭头并存）。
  - 标题由固定的「试算」改为 `editing ? (editor.name || t('plans.newPlan')) : t('plans.title')`
    —— 与菜谱详情「标题显示实体名」一致。
  - 编辑态隐藏 AppBar 右侧的「+ 新建」：在编辑态点它等于静默丢弃草稿。
- `mobile/lib/features/planner/screens/planner_screens.dart`
  - `_PlannerEditScreen` 的错误态 `Scaffold` 补 `leading: const AppBackButton()`（正常态本来就有）。

## 为什么返回走 `closeEditor()` 而不是 `router.back()`

编辑器不是独立路由，而是 `/plans` 路由内的一个模式（`editing` 开关）。`router.back()` 会直接离开试算页
（从「拿去试算」进来的话会回到今日推荐），而「返回」的语义是回到方案列表 —— 与「取消」一致。

## 验证

- `npm run build` ✓ / `npm run check:i18n` ✓ / `check:i18n:sources` 2166 ✓ / `npm run test:utils` 66 ✓
- `npx tsc --noEmit` 135 条（与基线一致，无新增）
- 移动端 `flutter analyze` → No issues found
- 未实机验证：`/plans` 需登录，浏览器会话 token 已失效（见 [BUGFIX_试算页添加条目报错.md](BUGFIX_试算页添加条目报错.md)）
