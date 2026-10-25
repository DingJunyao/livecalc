# 后台币种/汇率管理页补齐统一顶部导航栏

## 背景

用户反馈：Web 后台管理「币种管理」「汇率管理」两个页面没有汉堡图标（侧栏开关）和后退按钮，与其他后台子页面不一致。

## 根因

`CurrencyAdminView.vue` / `ExchangeRateAdminView.vue` 是后加的页面，直接以 `<v-container fluid>` 开头，页面标题和主操作按钮放在第一个 `v-card` 的 `v-card-title` 里；而其他所有后台子页面（UnitsView / InviteCodesView / UserManagementView / ProposalsView / DataMaintenanceView 等）的标准结构是：

```vue
<v-app-bar elevation="0" color="background" density="comfortable" fixed>
  <v-app-bar-nav-icon @click="toggleSidebar(isDesktop)" />
  <v-btn icon="mdi-arrow-left" variant="text" @click="goBack" />
  <v-app-bar-title class="text-h6">…</v-app-bar-title>
  <template #append>…主操作按钮…</template>
</v-app-bar>

<v-container class="pa-4">
```

script 侧配套：`useMobileDrawerControl()` 取 `isDesktop/toggleSidebar`，`useRouter()` 实现 `goBack = () => router.back()`。

## 修改

- `CurrencyAdminView.vue`：加标准 `v-app-bar`；「新增币种」按钮从卡片标题移入 `#append`（primary tonal + `mdi-plus`）；内容卡片改 `class="rounded-lg"`（去掉 `elevation="0"`），与 UnitsView 列表卡片一致。
- `ExchangeRateAdminView.vue`：加标准 `v-app-bar`；「手动补汇率」移入 `#append`；「立即刷新」从卡片内文字按钮改为 `#append` 里的 `mdi-refresh` 图标按钮（带 `:loading` 与原生 `:title` 提示，参照 ProposalsView 的刷新图标）；卡片只保留最新快照 `v-alert`。
- 两页 script 各补 `useRouter` / `useMobileDrawerControl` 导入与 `goBack`。

无 i18n 新键（全部复用现有 `admin.currency.*` / `admin.exchange.*`），无后端改动，无路由改动。

## 验证

- `npm run build` 通过（49.85s，PWA precache 187 entries）。
- 浏览器人工检查由用户侧自动重载服务完成。

## 分支

master `ec681538`（修复）→ 合并 feat/mobile-app `f64ae040`；要点记录提交在 feat/mobile-app。
