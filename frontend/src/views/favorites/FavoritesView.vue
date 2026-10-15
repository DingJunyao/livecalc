<template>
  <!-- 顶部导航栏 - 与其他页面统一的固定导航 -->
  <v-app-bar elevation="0" color="background" density="comfortable" fixed>
    <v-app-bar-nav-icon @click="toggleSidebar(isDesktop)" />
    <v-app-bar-title class="text-h6">{{ t('favorites.title') }}</v-app-bar-title>
    <template #append>
      <CalcContextMenu />
      <v-btn icon="mdi-refresh" variant="text" :loading="loading" @click="load" />
    </template>
  </v-app-bar>

  <v-container>
    <v-tabs v-model="activeTab" density="comfortable" class="mb-2">
      <v-tab value="ingredients">
        {{ t('favorites.tabIngredients') }}
        <span class="text-caption text-medium-emphasis ms-1">{{ counts.ingredients }}</span>
      </v-tab>
      <v-tab value="products">
        {{ t('favorites.tabProducts') }}
        <span class="text-caption text-medium-emphasis ms-1">{{ counts.products }}</span>
      </v-tab>
      <v-tab value="recipes">
        {{ t('favorites.tabRecipes') }}
        <span class="text-caption text-medium-emphasis ms-1">{{ counts.recipes }}</span>
      </v-tab>
      <v-tab value="merchants">
        {{ t('favorites.tabMerchants') }}
        <span class="text-caption text-medium-emphasis ms-1">{{ counts.merchants }}</span>
      </v-tab>
    </v-tabs>

    <v-window v-model="activeTab">
      <!-- 原料 -->
      <v-window-item value="ingredients">
        <template v-if="ingredients.length">
          <v-row v-if="!smAndDown">
            <v-col v-for="item in ingredients" :key="item.id" cols="12" sm="6" md="4" lg="3" xl="2">
              <FavoriteIngredientCard :item="item" @unfavorite="unfavorite('ingredient', item.id)" />
            </v-col>
          </v-row>
          <v-card v-else elevation="0">
            <v-list lines="two">
              <FavoriteIngredientCard
                v-for="item in ingredients"
                :key="item.id"
                :item="item"
                mobile
                @unfavorite="unfavorite('ingredient', item.id)"
              />
            </v-list>
          </v-card>
        </template>
        <div v-else class="text-center py-16 text-medium-emphasis">
          <v-icon size="80" color="medium-emphasis">mdi-heart-outline</v-icon>
          <div class="text-h6 mt-4">{{ t('favorites.empty') }}</div>
        </div>
      </v-window-item>

      <!-- 商品 -->
      <v-window-item value="products">
        <template v-if="products.length">
          <v-row v-if="!smAndDown">
            <v-col v-for="item in products" :key="item.id" cols="12" sm="6" md="4" lg="3" xl="2">
              <FavoriteProductCard :item="item" @unfavorite="unfavorite('product', item.id)" />
            </v-col>
          </v-row>
          <v-card v-else elevation="0">
            <v-list lines="two">
              <FavoriteProductCard
                v-for="item in products"
                :key="item.id"
                :item="item"
                mobile
                @unfavorite="unfavorite('product', item.id)"
              />
            </v-list>
          </v-card>
        </template>
        <div v-else class="text-center py-16 text-medium-emphasis">
          <v-icon size="80" color="medium-emphasis">mdi-heart-outline</v-icon>
          <div class="text-h6 mt-4">{{ t('favorites.empty') }}</div>
        </div>
      </v-window-item>

      <!-- 菜谱 -->
      <v-window-item value="recipes">
        <template v-if="recipes.length">
          <v-row>
            <v-col v-for="item in recipes" :key="item.id" cols="6" sm="6" md="4" lg="3" xl="2">
              <FavoriteRecipeCard
                :item="item"
                :cost="costOf(item)"
                :calories="caloriesOf(item)"
                @unfavorite="unfavorite('recipe', item.id)"
              />
            </v-col>
          </v-row>
        </template>
        <div v-else class="text-center py-16 text-medium-emphasis">
          <v-icon size="80" color="medium-emphasis">mdi-heart-outline</v-icon>
          <div class="text-h6 mt-4">{{ t('favorites.empty') }}</div>
        </div>
      </v-window-item>

      <!-- 商家 -->
      <v-window-item value="merchants">
        <template v-if="merchants.length">
          <v-row v-if="!smAndDown">
            <v-col v-for="item in merchants" :key="item.id" cols="12" sm="6" md="4" lg="3" xl="2">
              <FavoriteMerchantCard :item="item" @unfavorite="unfavorite('merchant', item.id)" />
            </v-col>
          </v-row>
          <v-card v-else elevation="0">
            <v-list lines="two">
              <FavoriteMerchantCard
                v-for="item in merchants"
                :key="item.id"
                :item="item"
                mobile
                @unfavorite="unfavorite('merchant', item.id)"
              />
            </v-list>
          </v-card>
        </template>
        <div v-else class="text-center py-16 text-medium-emphasis">
          <v-icon size="80" color="medium-emphasis">mdi-heart-outline</v-icon>
          <div class="text-h6 mt-4">{{ t('favorites.empty') }}</div>
        </div>
      </v-window-item>
    </v-window>
  </v-container>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, type Ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useDisplay } from 'vuetify'
import { api } from '@/api'
import { useGlobalSnackbar } from '@/composables/useGlobalSnackbar'
import { useLatestPrices } from '@/composables/useLatestPrices'
import { getErrorMessage } from '@/utils/errorHandler'
import { useMobileDrawerControl } from '@/composables/useMobileDrawer'
import CalcContextMenu from '@/components/layout/CalcContextMenu.vue'
import FavoriteIngredientCard from '@/components/favorites/FavoriteIngredientCard.vue'
import FavoriteProductCard from '@/components/favorites/FavoriteProductCard.vue'
import FavoriteRecipeCard from '@/components/favorites/FavoriteRecipeCard.vue'
import FavoriteMerchantCard from '@/components/favorites/FavoriteMerchantCard.vue'

const { t } = useI18n()
const { smAndDown, isDesktop } = useDisplay()
const { toggleSidebar } = useMobileDrawerControl()
const { notify } = useGlobalSnackbar()

const tabs = ['ingredients', 'products', 'recipes', 'merchants'] as const
type TabKey = (typeof tabs)[number]

const activeTab = ref<TabKey>('ingredients')
const loading = ref(false)

const ingredients = ref<any[]>([])
const products = ref<any[]>([])
const recipes = ref<any[]>([])
const merchants = ref<any[]>([])
const costMap = ref<Record<number, any>>({})

const counts = computed(() => ({
  ingredients: ingredients.value.length,
  products: products.value.length,
  recipes: recipes.value.length,
  merchants: merchants.value.length,
}))

// 收藏列表的「当天平均单价」（与商品/原料列表页同源）
const { load: loadIngredientPrices } = useLatestPrices(
  ingredients,
  (item) => `/nutrition/ingredients/${item.id}/latest-price`
)
const { load: loadProductPrices } = useLatestPrices(
  products,
  (item) => `/products/entity/${item.id}/latest-price`
)

async function loadSparklines(kind: 'products' | 'ingredients', list: Ref<any[]>) {
  const ids = list.value.map((i) => i.id).join(',')
  if (!ids) return
  try {
    const sparklines: any = await api.get(`/sparklines/${kind}`, { params: { ids } })
    if (sparklines) {
      list.value = list.value.map((item) => ({
        ...item,
        sparkline_data: sparklines[String(item.id)] || undefined,
      }))
    }
  } catch (e) {
    console.error('Failed to load sparklines', e)
  }
}

async function loadRecipeCosts() {
  const ids = recipes.value.map((r) => r.id)
  if (!ids.length) return
  try {
    costMap.value = (await api.post('/recipes/batch-cost', { ids, region_id: null })) || {}
  } catch (e) {
    console.error('Failed to load costs', e)
  }
}

const costOf = (recipe: any): number | null =>
  costMap.value[recipe.id]?.estimated_cost ?? recipe.estimated_cost ?? null
const caloriesOf = (recipe: any): number | null =>
  costMap.value[recipe.id]?.calories ?? recipe.calories ?? null

async function load() {
  loading.value = true
  try {
    // 复用各列表端点（favorites_only），payload 与列表页一致，保证观感对齐
    const [ingResp, prodResp, recipeResp, merchantResp]: any[] = await Promise.all([
      api.get('/ingredients', {
        params: { favorites_only: 'true', favorites_first: 'true', limit: 500 },
      }),
      api.get('/products/entity', {
        params: { favorites_only: 'true', favorites_first: 'true', limit: 500 },
      }),
      api.get('/recipes', {
        params: { favorites_only: 'true', favorites_first: 'true', include_cost: false, limit: 500 },
      }),
      api.get('/merchants/favorites'),
    ])
    ingredients.value = ingResp.items || []
    products.value = prodResp.items || []
    recipes.value = recipeResp.items || []
    merchants.value = Array.isArray(merchantResp) ? merchantResp : []

    // 富化（不阻塞渲染）：价格、迷你图、菜谱成本
    loadIngredientPrices()
    loadProductPrices()
    loadSparklines('ingredients', ingredients)
    loadSparklines('products', products)
    loadRecipeCosts()
  } catch (e: any) {
    notify(getErrorMessage(e, t('favorites.loadFailed')), 'error')
  } finally {
    loading.value = false
  }
}

async function unfavorite(key: 'ingredient' | 'product' | 'recipe' | 'merchant', id: number) {
  try {
    const path = key === 'merchant' ? `/merchants/${id}/favorite` : `/favorites/${key}/${id}`
    await api.delete(path)
    if (key === 'ingredient') ingredients.value = ingredients.value.filter((i) => i.id !== id)
    else if (key === 'product') products.value = products.value.filter((i) => i.id !== id)
    else if (key === 'recipe') recipes.value = recipes.value.filter((i) => i.id !== id)
    else merchants.value = merchants.value.filter((i) => i.id !== id)
    notify(t('favorites.unfavorited'), 'info')
  } catch (e: any) {
    notify(getErrorMessage(e, t('favorites.unfavoriteFailed')), 'error')
  }
}

onMounted(load)
</script>
