# Task 14 Report: Arabic RTL Audit

## Status

DONE

## Implementation

- Ran the required physical-direction inventory under `frontend/src`.
- Preserved and completed the prior implementer's uncommitted logical-property work instead of reverting it.
- Converted remaining user-layout directional CSS to logical properties:
  - `inset-inline-start` / `inset-inline-end`
  - `margin-inline-start` / `margin-inline-end`
  - `padding-inline-start` / `padding-inline-end`
  - `border-inline-start` / `border-inline-end`
  - `text-align: start` / `text-align: end`
- Converted Vuetify directional helper classes from `mr/ml/pr/pl` to `me/ms/pe/ps`, and `text-left/right` to `text-start/end`.
- Converted Vuetify drawers with `location="left"` to `location="start"`.
- Kept chart canvases, map containers, coordinate editors, numeric/date inputs, and map marker geometry in explicit LTR contexts.
- Fixed the Task 7 locale activation path so Arabic RTL is actually applied: `vuetify.rtl.current` does not exist in Vuetify 3.12; Vuetify derives RTL from the active `vuetify.locale.current` value.

## Inventory Results

- The exact brief inventory still reports only preserved LTR cases:
  - `PriceTrendChart` ECharts `grid.left/right`
  - `CostTrendAnalysis` ECharts `grid.left/right`
  - `NutritionSourceGrid` / `CostProportionChart` ECharts `left: center`
  - map marker arrow geometry in `MerchantDiff.vue` and `MerchantMapView.vue`
  - centering `left: 50%` in `ImageManager.vue` and `RecipeDetail.vue`
- After conversion, no Vuetify `mr/ml/pr/pl` classes, `text-left/right`, or `location="left/right"` remain under `frontend/src`.

## Browser Review

- Started a temporary Vite dev server at `http://127.0.0.1:5173`.
- Used headless Chromium with DevTools protocol to load `/login` at desktop (`1280x900`) and mobile (`390x844`) for `zh-CN`, `en-US`, and `ar`.
- Confirmed:
  - `zh-CN`: `lang=zh-CN`, `dir=ltr`, no horizontal overflow.
  - `en-US`: `lang=en-US`, `dir=ltr`, no horizontal overflow.
  - `ar`: `lang=ar`, `dir=rtl`, body direction `rtl`, no horizontal overflow.
- Screenshots were captured to:
  - `/tmp/task14-final-zh-CN-desktop.png`
  - `/tmp/task14-final-zh-CN-mobile.png`
  - `/tmp/task14-final-en-US-desktop.png`
  - `/tmp/task14-final-en-US-mobile.png`
  - `/tmp/task14-final-ar-desktop.png`
  - `/tmp/task14-final-ar-mobile.png`
- Limitation: the smoke review used the unauthenticated cloud login route because no authenticated browser account was available. The full authenticated shell, navigation drawer, tables, profile settings, price list, recipe detail, chart tooltip, and map flows were not visually exercised. They were covered by the source inventory and the production build.

## Verification

```bash
cd frontend
npm run check:i18n
npm run check:i18n:sources
npm run test:format
npm run build
git diff --check
```

All commands exited 0. The production build completed successfully; existing Vite dynamic-import/chunk-size warnings were non-fatal.

## Files Changed

- `frontend/src/stores/locale.ts`
- `frontend/src/App.vue`
- `frontend/src/components/layout/AppLayout.vue`
- directional Vuetify/logical CSS files found by the audit, including layout, meals, recipes, prices, products, ingredients, merchants, proposals, admin, auth, data, and profile views.
- `frontend/src/components/charts/SparklineBackground.vue`
- `frontend/src/components/recipes/CostProportionChart.vue`
- `frontend/src/components/recipes/CostTrendAnalysis.vue`
- `frontend/src/components/recipes/NutritionSourceGrid.vue`
- `frontend/src/components/map/MerchantMapView.vue`
- `frontend/src/views/admin/AgentTaskConsole.vue`
- `frontend/src/components/meals/MealCard.vue`
- `frontend/src/components/meals/MealTimeline.vue`
- `frontend/src/components/recipes/RecipeStepCard.vue`
- plus the remaining Vuetify class-only conversion files under `frontend/src`.

No locale JSON catalogs changed because no new UI labels were needed.

## Self-Review

- The full diff was reviewed; changes are limited to directional layout and the one RTL activation fix.
- Chart and map coordinate contexts remain explicit LTR.
- Numeric/date inputs remain explicit LTR via `App.vue`.
- No mobile, backend, database, or API contract changes were made.
- `git diff --check` passed.

## Concerns

- The browser review is limited to the login route because no authenticated account was available.
- The locale-store fix is a necessary correction to Task 7's Vuetify RTL wiring, not an unrelated refactor.
- Vite still reports the existing large-chunk warning; it does not fail the build.
