# 试算页添加菜谱 / 原料 / 商品：五层连坑（未定义函数 → 未定义函数 → 把选项 id 当对象用 400 → formatNumber 参数位错 → 后端 async 未 await 导致合计恒 0）

## 现象（用户先后反馈四条，每条都是修完上一条才露出来的）

**① 一输入就报错**（`/plans` 编辑器，三个下拉任一个）：

```
PlansView.vue:128 Uncaught TypeError: _ctx.searchRecipes is not a function
[Vue warn]: Unhandled error during execution of component event handler
  at <VAutocomplete modelValue=null onUpdate:modelValue=fn items= [] ...>
```

表现：输入的字进不去、下拉永远是空列表、条目加不进来。

**② 搜索修好后，点选候选添加条目 → 400**：

```
POST /api/v1/meal-plans/evaluate → 400
{"kind": "meal", "meal_type": "lunch",
 "items": [{"group": "dinner", "item_type": "recipe", "ingredient_id": null,
            "product_id": null, "servings": 1, "quantity": null, "unit_id": null, "sort_order": 0}]}
detail: "条目类型 {item_type} 缺少对应实体 ID"
```

关键细节：payload 里 `ingredient_id` / `product_id` 是 `null`，而 **`recipe_id` 这个键根本不存在**
—— 「该有的键不存在」= 值是 `undefined`，被 `JSON.stringify` 丢掉。

**③ 选择菜谱后渲染报错**（求值成功、合计卡一出现就炸）：

```
PlansView.vue:157 [Vue warn]: Unhandled error during execution of render function
  at <VRow dense=""> at <VCard key=0 elevation="0" class="mb-4 pa-3"> ...
format.ts:46 Uncaught (in promise) TypeError: (locale || "").toLowerCase is not a function
    at resolveFormatLocale (format.ts:46:37)
    at formatNumber (format.ts:110:26)
    at ComputedRefImpl.fn (PlansView.vue:442:17)
    at PlansView.vue:227:32
```

后面那条 `runtime-core: Cannot read properties of null (reading 'emitsOptions')` 是渲染异常引发的级联，不是独立问题。

**④ 合计恒为 0**（前三层修完、条目能加进来、求值不再报错之后）：「合计 vs 目标」里
成本 / 热量 / 蛋白质 / 脂肪**一直都是 0**，改菜谱、改份量、换食材都不动，保存后的成本趋势倒是有数。

## 根因（五层，一层挡住一层）

### ① 模板调用了脚本里不存在的三个函数

三处 `v-autocomplete` 写的是：

```vue
:search="recipeSearch"
@update:search="v => searchRecipes(v)"
```

脚本里**只有** `recipeSearch` / `ingredientSearch` / `productSearch` 三个 ref，以及
`watch(ref, …) -> debounceSearch -> doSearch` 防抖搜索链路，
**从来没有定义 `searchRecipes` / `searchIngredients` / `searchProducts`**。

Vuetify 3 的 `VAutocomplete` 把 `search` 做成 proxied model：敲键 → `onUpdate:modelValue`
→ 内部写 `search` → emit `update:search`，于是模板里那三个不存在的函数被立即调用 → TypeError。

### ② 条目列表用的 `typeColor()` / `typeLabel()` 也没定义

`plans.typeRecipe` / `plans.typeIngredient` / `plans.typeProduct` 三个 i18n 键在语料里早就有，
但视图里没写这两个函数。被 ① 挡在后面。

### ③ 把 `v-autocomplete` 的选中值当「选项对象」用

```ts
const recipePick = ref<{ title: string; value: number } | null>(null)
...
watch(recipePick, (pick) => {
  if (pick) addItem('recipe', pick.value, pick.title)   // ← pick 其实是 id，不是对象
  recipePick.value = null
})
```

Vuetify 3 的 `VSelect` / `VAutocomplete` 默认 `return-object = false`，
`vuetify/lib/composables/list-items.js` 的 `transformOut` 对外给出的模型值就是 `item.value`：

```js
function transformOut(value) {
  return props.returnObject
    ? value.map(({ raw }) => raw)
    : value.map(({ value }) => value)      // ← 默认走这支：模型值 = item-value（本例是数字 id）
}
```

于是 `pick.value` / `pick.title` 全是 `undefined` → `addItem('recipe', undefined, undefined)`
→ 条目里 `recipe_id: undefined` → `JSON.stringify` 丢键 → 后端 `_validate_items()` 按
`item_type` 取 id 得到 `None` → 400。

对照：`frontend/src/components/blacklist/BlacklistDialog.vue:251` 的
`onSelectIngredient(ingredientId: number | null)` 就是正确写法。

### ④ `formatNumber` 的第二参是 locale，不是 options

`frontend/src/utils/format.ts:107`：

```ts
export function formatNumber(value: NumberInput, locale: string, options?: Intl.NumberFormatOptions): string
```

而 `totalsRows` 写成了：

```ts
value: `${formatNumber(n.protein_g, { maximumFractionDigits: 1 })} g`,   // ← options 传到了 locale 位
target: `${formatNumber(toDisplayCalorie(tg.calories))} ${energyUnit.value}`,  // ← 又漏了 locale
```

options 对象落到 `resolveFormatLocale(locale: string)` 里 → `(locale || '').toLowerCase()` 抛
TypeError；热量行则是 locale 缺省，回落 `zh-CN`，en / ar 用户看到中文数字格式。
触发时机：`evaluation` 一有值就渲染「合计 vs 目标」卡，于是第三步一成功就炸。

> `.vue` 是静态检查盲区：`vue-tsc` 1.8 与 TS 5.x 不兼容（直接抛
> `Search string not found: "/supportedTSExtensions = .*(?=;)/"`），`vite build` 与
> `npx tsc --noEmit` 都不解析模板与 `.vue` 脚本，四层错误全都只在运行时现形。

### ⑤ 后端：`async` 引擎未 `await`（叠一个 `Decimal / float`）——合计恒为 0

`backend/app/services/meal_plan_service.py` 的 `_item_cost_nutrition()`：

```python
cost = calculate_recipe_cost(recipe.id, user.id, db, tz=tz, servings_override=servings_override)
if cost and cost.get("cost_per_serving") is not None:
```

而 `app/services/recipe_service.py` 里 `calculate_recipe_cost` / `calculate_recipe_nutrition` **都是 `async def`**
（`meal_recommender` 与 `api/recipes.py` 都规规矩矩 `await`，只有试算这里漏了）。拿到的是 **coroutine 对象**
→ `.get(...)` 抛 `AttributeError` → 被外层 `try/except Exception: logger.debug(...)` 静默吞掉（debug 级别，
正常日志里看不到）→ `out["cost"]` / `out["nutrition"]` 保持 `None` → `_evaluate_stub_items` 只在非 None 时累加
→ **合计恒为 0**（条目明细里的成本也一直是 `--`）。

同一返回语句上还叠了第二处：`recipe_service.py:1215`

```python
"cost_per_serving": total_cost / (servings_override or recipe.servings or 1),
```

`total_cost` 是 `Decimal`，而试算传进来的 `servings_override = float(item.servings)` 是 `float`
（`meal_plan_service.py:64`）→ `Decimal / float` 直接 `TypeError`。这条只在传 float 覆盖时触发，
所以菜谱详情页（传 int 或 None）一直没暴露。

**实机证据**（把开发库拷到临时目录后只读跑 `evaluate_items`，HEAD 版本）：

```
== recipe 26 西红柿牛腩 | ingredient 1 | product 145
DEBUG meal_plan_service: 试算：菜谱 26 成本计算失败
AttributeError: 'coroutine' object has no attribute 'get'      # meal_plan_service.py:70
RuntimeWarning: coroutine 'calculate_recipe_cost' was never awaited
== RESULT totals: {'cost': 0.0, 'currency': None, 'calories': 0.0, 'protein_g': 0.0, 'carbs_g': 0.0, 'fat_g': 0.0}
```

同一脚本改完再跑：`cost 104.44 CNY / calories 736.73 / protein_g 20.54 / carbs_g 136.27 / fat_g 5.22`，
30 天成本趋势逐日非 0。

## 修复（`frontend/src/views/plans/PlansView.vue`）

- 三处下拉：`:search` + `@update:search="v => searchXxx(v)"` → `v-model:search="recipeSearch"`；
  搜索链路（watch → debounce 300ms → `doSearch`）与接口口径
  （`/recipes?search=&limit=`、`/ingredients?q=&limit=`、`/products/entity?search=&limit=`）本来就是对的。
- 三处下拉补 `:custom-filter="() => true"`：结果由服务端搜索给出，再让 Vuetify 默认过滤器
  按标题二次过滤，「别名 / 品牌命中」的候选会被滤掉。项目里其余 8 个服务端搜索下拉都这么写。
- 三个 pick 的类型改为 `number | null`，选中后统一走 `onPick()`：

```ts
function onPick(type: PlanItemType, id: number | null, options: { title: string; value: number }[]) {
  if (id == null) return
  addItem(type, id, options.find(o => o.value === id)?.title ?? '')
}
```

- `addItem()` 里三个 id 字段补 `?? null` 兜底，避免再次出现「键消失」。
- 补 `typeLabel(type)` / `typeColor(type)`（与移动端 `_planTypeLabel()` 同语义）。
- `totalsRows` 六处 `formatNumber` 全部改为 `formatNumber(value, localeStore.effectiveFormatLocale, options?)`
  （`useLocaleStore`，与全项目其余 40 余处调用同口径），并把硬编码的 `' g'` 换成 `t('nutrientUnits.g')`。

### 后端（同一 bug 的二连）

- `meal_plan_service`：`_item_cost_nutrition` / `_evaluate_stub_items` / `evaluate_items` / `evaluate_plan`
  全部改成 `async def`，两处引擎调用补 `await`；`api/meal_plans.py` 的 `/evaluate` 与
  `meal_recommender._build_response_from_records`（方案来源餐渲染 plan 视图）跟着 `await`。
- `recipe_service.py:1215`：改成 `total_cost / Decimal(str(servings_override or recipe.servings or 1))`。
- 前端：合计用的 `meal_type` 改为按条目分组推导（`evalMealType`，group=other 退回午餐），并把 `kind`
  加进取值 watch 的依赖 —— 否则切换「一顿 / 一日」不会重新求值，目标比例还是旧的。
- 新增回归测试：`tests/test_meal_plans_api.py::test_evaluate_awaits_async_recipe_engines`（假引擎锁「必须
  await」，退回同步调用时合计会变 0）与 `test_recipe_cost_per_serving_accepts_float_servings_override`
  （float 覆盖不再抛 TypeError）—— 两条在 HEAD 版本上都会失败（已实测）。

## 顺带修复（移动端同一处 UI）

`mobile/lib/features/planner/screens/planner_screens.dart` 的条目类型徽标写成：

```dart
item['item_type'] == 'recipe'
    ? l10n.mealsRoleStaple          // 餐卡里菜式角色的文案「主食」，抄过来忘了改
    : _planTypeLabel(item['item_type'] ?? '', l10n),
```

菜谱条目在试算页显示成「主食」，且与同文件里已经正确处理 `recipe` 的 `_planTypeLabel()` 自相矛盾。
改为统一走 `_planTypeLabel()`。

## 验证

- `npm run build` 通过
- `npm run check:i18n` 通过（3 份语料键树一致）/ `check:i18n:sources` 通过（2166 键）
- `npm run test:utils` 66 通过
- `npx tsc --noEmit` 135 条（与基线一致，无新增）
- 模板 → 脚本标识符交叉核对：模板里调用的函数改后全部有定义
- 全项目扫描 `formatNumber|formatQuantity|formatDate|formatTime|formatDateTime|formatCoordinate`
  第二参直接是对象字面量的写法：只有试算页这 4 处（改后为 0）
- 移动端 `flutter analyze` → No issues found（`pub get` 顺手改写了 `mobile/pubspec.lock`，已还原）
- **实机 UI 未验证**：从 devtools MCP 连到的 Edge 里 `localStorage.token` 已失效
  （`GET /api/v1/auth/me` → 401「无效的令牌」），登录页挡住 `/plans`，而我没有可用凭据、
  也不打算用注册接口往开发库写测试账号。

- 后端：`pytest tests` 全量 **910 passed**；失败 38 条与 HEAD 基线（39 条）逐条一致、**无新增**
  （含 1 条与本改动无关的顺序性 flaky 由 fail 转 pass；基线用「临时换回 HEAD 版本再跑一遍」取得，非同机 worktree 对比）
- 后端实机（开发库副本、只读）：合计由全 0 → `104.44 CNY / 736.73 kcal`；成本趋势 30 天逐日非 0
- 新回归测试在 HEAD 版本上确认失败：`assert None == 12.5` / `Decimal / float TypeError`

## 分支

web 侧属于主线功能，按项目规则应落在 `master` 再同步到 `feat/mobile-app`。
本轮先在当前工作区（`feat/mobile-app`）修改，待确认后再落 master。

## 经验

1. **一层错误挡一层**：修完搜索才暴露 `typeLabel`，修完 `typeLabel` 才暴露「pick 当对象用」，
   修完 400 才暴露 `formatNumber`。同一条链路（输入 → 选中 → 加进来 → 求值 → 保存 / 渲染合计）
   要连着走完，否则每轮只修掉最外面那层。
2. **payload 里「该有的键不存在」= `undefined` 被 JSON 丢掉**；「键在但为 null」= 显式赋了 null。
   这是区分「前端没算出值」和「前端明确传空」最快的抓手。
3. Vuetify 3 下拉默认 `return-object = false`，模型值是 `item-value`；要整个对象必须显式声明
   `return-object`（如 `PricesView` 的商品下拉）。`ref<{title,value}>` 这样的类型标注骗不了运行时。
4. **多参数工具函数的「位置」写错不会编译报错**，还会以「运行到那一刻才炸」的形式出现
   （`formatNumber(value, locale, options?)` 是典型）。新增调用点最好直接照抄项目里既有写法。
5. `.vue` 模板是 `build` / `tsc` 的双重盲区：模板里调用不存在的函数**编译期全绿、运行期一敲键就炸**。
   可以考虑加一个「模板标识符 ↔ 脚本定义」的静态校验脚本（本轮还没加）。
6. 服务端搜索下拉一律配 `:custom-filter="() => true"`，否则别名 / 品牌命中的候选会被前端二次过滤掉。
7. **`async def` 被当同步函数调用**：拿到 coroutine，直到 `.get()` / `[]` 才炸；外面套着
   `except Exception: logger.debug` 就等于静默丢失 —— 合计恒 0 却「没有任何错误」。
   `RuntimeWarning: coroutine ... was never awaited` 是最直接的抓手（需开 WARNING 级日志）。
8. `Decimal / float` 是硬报错（不像 int 会隐式转换）；金额链路里凡「可选覆盖参数」参与除法，都要显式
   `Decimal(str(x))`。
9. **测试只断言结构、不断言数值 = 没测到**：`assert "totals" in payload` 放过了「合计恒 0」。
   涉及计算的功能至少要断言一个非 0 结果 —— 本轮补的两条回归测试就是这么写的。
