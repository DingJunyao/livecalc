// router/index.ts
import { createRouter, createWebHistory } from 'vue-router'
import { useUserStore } from '@/stores/user'
import { useMapConfig } from '@/composables/useMapConfig'
import { t } from '@/plugins/i18n'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/login',
      name: 'login',
      component: () => import('@/views/auth/Login.vue'),
      meta: { requiresAuth: false, titleKey: 'routes.login' },
    },
    {
      path: '/register',
      name: 'register',
      component: () => import('@/views/auth/Register.vue'),
      meta: { requiresAuth: false, titleKey: 'routes.register' },
    },
    {
      path: '/setup',
      name: 'local-setup',
      component: () => import('@/views/setup/LocalInitWizard.vue'),
      meta: { requiresAuth: false, titleKey: 'routes.setup' },
    },
    {
      path: '/',
      component: () => import('@/components/layout/AppLayout.vue'),
      meta: { requiresAuth: true },
      children: [
        {
          path: '',
          name: 'daily-meals',
          component: () => import('@/views/meals/DailyMealsView.vue'),
          meta: { titleKey: 'routes.today' },
        },
        {
          path: 'prices',
          name: 'prices',
          component: () => import('@/views/prices/PricesView.vue'),
          meta: { titleKey: 'routes.prices' },
        },
        {
          path: 'prices/quick-fill',
          name: 'quick-fill',
          component: () => import('@/views/prices/QuickFillView.vue'),
          meta: { titleKey: 'routes.quickFill' },
        },
        {
          path: 'recipes',
          name: 'recipes',
          component: () => import('@/views/recipes/RecipesView.vue'),
          meta: { titleKey: 'routes.recipes' },
        },
        {
          path: 'recipes/:id',
          name: 'recipe-detail',
          component: () => import('@/views/recipes/RecipeDetail.vue'),
          meta: { detailTypeKey: 'detailTypes.recipe' },
        },
        {
          path: 'recipes/:id/analysis',
          name: 'recipe-analysis',
          component: () => import('@/views/recipes/RecipeAnalysisView.vue'),
          meta: { detailTypeKey: 'detailTypes.recipe', titleKey: 'routes.recipeAnalysis' },
        },
        {
          path: 'data',
          name: 'data',
          redirect: '/data/products',
        },
        {
          path: 'data/products',
          name: 'products',
          component: () => import('@/views/data/ProductsView.vue'),
          meta: { titleKey: 'routes.products' },
        },
        {
          path: 'data/products/:id',
          name: 'product-detail',
          component: () => import('@/views/products/ProductDetail.vue'),
          meta: { detailTypeKey: 'detailTypes.product' },
        },
        {
          path: 'data/ingredients',
          name: 'ingredients',
          component: () => import('@/views/data/IngredientsView.vue'),
          meta: { titleKey: 'routes.ingredients' },
        },
        {
          path: 'data/ingredients/:id',
          name: 'ingredient-detail',
          component: () => import('@/views/ingredients/IngredientDetail.vue'),
          meta: { detailTypeKey: 'detailTypes.ingredient' },
        },
        {
          path: 'data/merchants',
          name: 'merchants',
          component: () => import('@/views/data/MerchantsView.vue'),
          meta: { titleKey: 'routes.merchants' },
        },
        {
          path: 'data/merchants/:id',
          name: 'merchant-detail',
          component: () => import('@/views/merchants/MerchantDetail.vue'),
          meta: { detailTypeKey: 'detailTypes.merchant' },
        },
        {
          path: 'profile',
          name: 'profile',
          component: () => import('@/views/profile/ProfileView.vue'),
          meta: { titleKey: 'routes.profile' },
        },
        {
          path: 'profile/places',
          name: 'profile-places',
          component: () => import('@/views/profile/UserPlacesView.vue'),
          meta: { titleKey: 'routes.profilePlaces' },
        },
        {
          path: 'profile/proposals',
          name: 'profile-proposals',
          component: () => import('@/views/profile/MyProposalsView.vue'),
          meta: { titleKey: 'routes.profileProposals' },
        },
        {
          path: 'admin',
          name: 'admin',
          meta: { adminOnly: true, titleKey: 'routes.admin' },
          component: () => import('@/views/admin/AdminDashboard.vue'),
        },
        {
          path: 'admin/invite-codes',
          name: 'admin-invite-codes',
          meta: { adminOnly: true, titleKey: 'routes.adminInviteCodes' },
          component: () => import('@/views/admin/InviteCodesView.vue'),
        },
        {
          path: 'admin/units',
          name: 'admin-units',
          meta: { adminOnly: true, titleKey: 'routes.adminUnits' },
          component: () => import('@/views/admin/UnitsView.vue'),
        },
        {
          path: 'admin/currencies',
          name: 'admin-currencies',
          meta: { adminOnly: true, titleKey: 'routes.adminCurrencies' },
          component: () => import('@/views/admin/CurrencyAdminView.vue'),
        },
        {
          path: 'admin/exchange-rates',
          name: 'admin-exchange-rates',
          meta: { adminOnly: true, titleKey: 'routes.adminExchangeRates' },
          component: () => import('@/views/admin/ExchangeRateAdminView.vue'),
        },
        {
          path: 'admin/barcode-services',
          name: 'admin-barcode-services',
          meta: { adminOnly: true, titleKey: 'routes.adminBarcodeServices' },
          component: () => import('@/views/admin/BarcodeServicesView.vue'),
        },
        {
          path: 'admin/map-settings',
          name: 'admin-map-settings',
          meta: { adminOnly: true, titleKey: 'routes.adminMapSettings' },
          component: () => import('@/views/admin/MapSettingsView.vue'),
        },
        {
          path: 'admin/ai-config',
          name: 'admin-ai-config',
          meta: { adminOnly: true, titleKey: 'routes.adminAiConfig' },
          component: () => import('@/views/admin/AiConfigView.vue'),
        },
        {
          path: 'admin/mt-config',
          redirect: '/admin/ai-config',
        },
        {
          path: 'admin/users',
          name: 'admin-users',
          meta: { adminOnly: true, titleKey: 'routes.adminUsers' },
          component: () => import('@/views/admin/UserManagementView.vue'),
        },
        {
          path: 'admin/recipe-import',
          redirect: '/admin/data-maintenance',
        },
        {
          path: 'admin/data-maintenance',
          name: 'admin-data-maintenance',
          meta: { adminOnly: true, titleKey: 'routes.adminDataMaintenance' },
          component: () => import('@/views/admin/DataMaintenanceView.vue'),
        },
        {
          path: 'admin/agent-console',
          name: 'admin-agent-console',
          meta: { adminOnly: true, titleKey: 'routes.adminAgentConsole' },
          component: () => import('@/views/admin/AgentTaskConsole.vue'),
        },
        {
          path: 'admin/blacklist-groups',
          name: 'admin-blacklist-groups',
          meta: { adminOnly: true, titleKey: 'routes.adminBlacklistGroups' },
          component: () => import('@/views/admin/BlacklistGroupsView.vue'),
        },
        {
          path: 'admin/proposals',
          name: 'admin-proposals',
          meta: { adminOnly: true, titleKey: 'routes.adminProposals' },
          component: () => import('@/views/admin/ProposalsView.vue'),
        },
        {
          path: 'admin/email-config',
          name: 'admin-email-config',
          meta: { adminOnly: true, titleKey: 'routes.adminEmailConfig' },
          component: () => import('@/views/admin/EmailConfigView.vue'),
        },
        {
          path: 'admin/images-unused',
          name: 'admin-images-unused',
          meta: { adminOnly: true, titleKey: 'routes.adminImagesUnused' },
          component: () => import('@/views/admin/UnusedImagesView.vue'),
        },
        {
          path: 'admin/storage',
          name: 'admin-storage',
          meta: { adminOnly: true, titleKey: 'routes.adminStorage' },
          component: () => import('@/views/admin/StorageConfigView.vue'),
        },
      ],
    },
  ],
})

// 路由守卫
router.beforeEach(async (to, from, next) => {
  const userStore = useUserStore()

  // ---- Local mode: simplified auth ----
  if (import.meta.env.VITE_STORAGE_MODE === 'local') {
    // Make sure synchronous image URL resolution sees the active S3 config.
    const { preloadStorageConfig } = await import('@/utils/image')
    await preloadStorageConfig()

    // Redirect logged-in users away from login/register
    if ((to.name === 'login' || to.name === 'register') && userStore.isLoggedIn) {
      next('/')
      return
    }
    // Block admin pages not relevant in single-user local mode
    const blockedInLocal: string[] = [
      'admin',
      'admin-proposals',
      'admin-users',
    'admin-invite-codes',
    'admin-email-config',
    'profile-proposals',
    ]
    if (blockedInLocal.includes(to.name as string)) {
      next('/profile')
      return
    }
    next()
    return
  }

  // ---- Cloud/normal mode ----
  const requiresAuth = to.matched.some((record) => record.meta.requiresAuth !== false)
  const adminOnly = to.matched.some((record) => record.meta.adminOnly === true)

  // 刷新场景：token 在但 user 信息未加载 → 先 await 加载完再判断权限
  // 否则 user?.is_admin 为 undefined，管理员页会被误判跳首页
  if (userStore.isLoggedIn && !userStore.user) {
    await userStore.fetchUser()
    // 加载后仍无 user（token 失效）→ 登出，让后续 requiresAuth 判断跳 login
    if (!userStore.user) {
      userStore.logout()
    }
  }

  if (requiresAuth && !userStore.isLoggedIn) {
    next('/login')
  } else if (adminOnly && !userStore.user?.is_admin) {
    // 非管理员访问管理页面，重定向到首页
    next('/')
  } else if ((to.name === 'login' || to.name === 'register') && userStore.isLoggedIn) {
    next('/')
  } else if (to.name === 'profile-places') {
    // 地图关闭时拦截常用地点页（数据保留，仅禁用访问）
    const { mapEnabled, ensureLoaded } = useMapConfig()
    await ensureLoaded()
    if (!mapEnabled.value) {
      next('/profile')
    } else {
      next()
    }
  } else {
    next()
  }
})

// 路由切换后自动设置页面标题
router.afterEach((to) => {
  const titleKey = to.meta.titleKey as string | undefined
  if (titleKey) {
    let title = t(titleKey)
    // 本地模式下「个人中心」改称「设置」
    if (import.meta.env.VITE_STORAGE_MODE === 'local' && titleKey === 'routes.profile') {
      title = t('routes.settings')
    }
    document.title = `${title} - ${t('app.name')}`
  }
})

export default router
