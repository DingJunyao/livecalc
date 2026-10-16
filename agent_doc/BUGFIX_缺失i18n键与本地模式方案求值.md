# 缺失的 i18n 键（运行时报 "Not found … key"）+ 本地模式方案条目求值 ReferenceError

## 现象

用户在浏览器控制台看到：

```
[intlify] Not found 'plans.takeToPlanner' key in 'zh' locale messages.
  at MealCard.vue:131
```

## 根因

`plans.takeToPlanner`（试算页「拿去试算」按钮，`components/meals/MealCard.vue:128/131`）
**三个语料文件里都没有** —— 功能开发时只写了 `t('plans.takeToPlanner')` 没补键。

为什么仓库自带的 `check:i18n` 没拦住：

- `npm run check:i18n`（`keys` 模式）只比对**三份语料之间的键树是否一致**，
  三份都缺同一个键时它认为「一致」，照样通过；
- `npm run check:i18n:sources` 才是查「源码里用到但语料里没有」的，
  但它当时**本身就是红的**（见下），失败的输出里淹没了这条真正的缺失键。

把 `sources` 模式的输出完整看一遍，一共 4 处真缺失（另外还有 `src/api/local/business/mealComposer.ts`
的中文硬编码误报）：

| 键 | 使用处 | 影响 |
| --- | --- | --- |
| `plans.takeToPlanner` | `components/meals/MealCard.vue` | 控制台警告，按钮显示键名 |
| `common.save` | `views/plans/PlansView.vue`、`views/profile/ProfileView.vue` | 同上（个人中心保存按钮一直显示 `common.save`） |
| `common.cancel` | `views/plans/PlansView.vue` | 同上 |
| `localErrors.planNotFound` | `api/local/handlers/mealPlans.ts`（`localError('planNotFound', 404, …)`） | 本地模式方案不存在时取不到文案 |

## 修复

1. **补键**（三语齐补，插在各自区块的语义位置）：
   `plans.takeToPlanner`（拿去试算 / Use in planner / استخدم في الحاسبة）、
   `common.save`（保存 / Save / حفظ）、`common.cancel`（取消 / Cancel / إلغاء）、
   `localErrors.planNotFound`（方案不存在 / Plan not found / الخطة غير موجودة）。
2. **让 `sources` 门禁重新变绿**（否则下一个缺键还是会被淹没）：
   - `frontend/scripts/check-i18n.mjs` 的 `sourceIgnorePaths` 增加
     `src/api/local/business/mealComposer.ts`：该文件里全是**发给模型的提示词与内部校验反馈**
     （`validateComposition` 的 errors 只用于重试判定/回退规则，不进 UI），不属于用户可见文案；
   - `handlers/meals.ts` 里那句中文重试后缀（`上一次输出未通过校验…`）挪进
     `mealComposer.ts` 并导出为 `RETRY_SUFFIX` —— 「发给模型的文本」集中在一个（已忽略扫描的）模块里。
3. **顺手修本地模式真 bug**：`handlers/meals.ts:382` 调用了 `evaluateItem(it)`，
   而它是 `mealPlans.ts` 里的**私有函数**（未导出未导入）—— 本地模式打开「方案来源」的推荐餐卡
   必定抛 `ReferenceError: evaluateItem is not defined`（`npx tsc --noEmit` 一直在报
   `Cannot find name 'evaluateItem'`）。改为从 `./mealPlans` 导出 + 导入，并删掉同一循环里
   未被使用的 `store` 变量。

## 验证

- `npm run check:i18n` → 三语键树一致 ✓
- `npm run check:i18n:sources` → **由红转绿**：`Checked 2163 source translation keys …` ✓
  （修前报 3 个 missing source key + 1 个 missing localErrors + 一堆 Han 误报）
- `npm run build` ✓；`npm run test:utils` 66/66 ✓
- `npx tsc --noEmit` 137 → **135 条**（少的正是 `evaluateItem` 未定义与 `store` 未使用这两条）

## 经验

1. **`check:i18n`（keys）通过 ≠ 没有缺键**：它只保证三份语料一致，不保证源码用到的键存在。
   加新文案时至少跑一次 `check:i18n:sources`。
2. **门禁长期红着等于没有门禁**：`sources` 红着的那段时间，真正的缺键（`plans.takeToPlanner`）
   就躺在失败输出里没人看。要么修红、要么把「本来就是内部文案」的路径显式写进忽略清单。
3. `localErrors.*` 这类**动态拼出来的键**（`localError('planNotFound')` → `localErrors.planNotFound`）
   只在 `sources` 模式的 `localErrorPattern` 里被检查，普通 `t()` 扫描看不到。
4. 模板里的 `t('…')` 拼错只在运行时警告，`vite build` 与 `tsc` 都不报 —— `.vue` 仍是工具盲区
   （本仓 `vue-tsc` 1.8 与 TS 5.x 不兼容，跑起来直接抛
   `Search string not found: "/supportedTSExtensions = .*(?=;)/"`）。
