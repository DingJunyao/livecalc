# 移动端菜谱分区维护与成本提示修复

## 问题

1. 菜谱详情只有一个全局“编辑菜谱”入口，进入后仍是完整表单，和 Web 端各卡片独立维护的体验不一致。
2. 原料成本的回退链提示只依赖 `Tooltip` 悬停/长按，实机上点击信息图标没有反馈。

## 修复

- `RecipeFormScreen` 新增 `RecipeFormSection`，支持 `basic`、`ingredients`、`steps`、`tips` 四种分区维护页；分区页只渲染当前分区，底部“保存修改”只提交该分区 payload。
- 新增路由 `/recipes/:id/edit/:section`；菜谱详情移除全局编辑按钮，基本信息、原料、做法步骤、小贴士四个卡片各带独立编辑入口。保存成功或进入待审核后返回详情、刷新数据，并展示后端审核反馈。
- 成本回退链信息图标改为可点击按钮，点击弹出“根据以下食材计算成本”说明；保留 `Tooltip`，桌面端悬停体验不变。
- 成本列中图标保持在金额左侧：按钮压缩为 24px 稳定点击区，列宽调整为 92px，金额超宽时按内容缩放，避免横向溢出。
- 待审横幅的字段摘要不再直接显示 API key：`RecipePendingProposal.changeSummary` 为菜谱全部可更新字段提供中文名称（如 `cooking_steps -> 做法步骤`），未知字段保留原文兜底。

## 验证

- `flutter analyze --no-pub` 0 issue。
- 聚焦测试 `recipe_form_screen_test.dart`、`recipe_detail_typography_test.dart` 全部通过，覆盖完整创建、独立 payload、分区页返回、四个详情编辑入口、移动端点击回退链弹窗，以及信息按钮位于成本文本左侧。
- `recipe_detail_test.dart` 覆盖待审字段中文化与未知字段兜底。
