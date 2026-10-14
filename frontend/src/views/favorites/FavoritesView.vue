<template>
  <v-container>
    <div class="d-flex align-center ga-2 mb-4">
      <h1 class="text-h6">{{ t('favorites.title') }}</h1>
      <v-spacer />
      <v-btn icon="mdi-refresh" variant="text" :loading="loading" @click="load" />
    </div>

    <v-tabs v-model="activeTab" density="comfortable" class="mb-2">
      <v-tab value="ingredients">{{ t('favorites.tabIngredients') }}</v-tab>
      <v-tab value="products">{{ t('favorites.tabProducts') }}</v-tab>
      <v-tab value="recipes">{{ t('favorites.tabRecipes') }}</v-tab>
      <v-tab value="merchants">{{ t('favorites.tabMerchants') }}</v-tab>
    </v-tabs>

    <v-window v-model="activeTab">
      <v-window-item v-for="key in tabs" :key="key" :value="key">
        <v-list v-if="currentItems(key).length" lines="two">
          <v-list-item
            v-for="item in currentItems(key)"
            :key="item.id"
            :title="item.name"
            :subtitle="item.subtitle || undefined"
            @click="goDetail(key, item.id)"
          >
            <template #append>
              <FavoriteButton :active="true" @toggle="unfavorite(key, item.id)" />
            </template>
          </v-list-item>
        </v-list>
        <div v-else-if="!loading" class="text-center py-10 text-medium-emphasis">
          <v-icon size="64" color="medium-emphasis">mdi-heart-outline</v-icon>
          <div class="mt-3">{{ t('favorites.empty') }}</div>
        </div>
      </v-window-item>
    </v-window>
  </v-container>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { api } from '@/api'
import { useGlobalSnackbar } from '@/composables/useGlobalSnackbar'
import { getErrorMessage } from '@/utils/errorHandler'
import FavoriteButton from '@/components/common/FavoriteButton.vue'

const { t } = useI18n()
const router = useRouter()
const { notify } = useGlobalSnackbar()

const tabs = ['ingredients', 'products', 'recipes', 'merchants'] as const
type TabKey = (typeof tabs)[number]

const activeTab = ref<TabKey>('ingredients')
const loading = ref(false)
const grouped = ref<Record<TabKey, any[]>>({
  ingredients: [],
  products: [],
  recipes: [],
  merchants: [],
})

function currentItems(key: TabKey): any[] {
  return grouped.value[key] || []
}

async function load() {
  loading.value = true
  try {
    const payload: any = await api.get('/favorites')
    grouped.value = {
      ingredients: payload.ingredients || [],
      products: payload.products || [],
      recipes: payload.recipes || [],
      merchants: payload.merchants || [],
    }
  } catch (e: any) {
    notify(getErrorMessage(e, t('favorites.loadFailed')), 'error')
  } finally {
    loading.value = false
  }
}

const detailPath: Record<TabKey, (id: number) => string> = {
  ingredients: (id) => `/data/ingredients/${id}`,
  products: (id) => `/data/products/${id}`,
  recipes: (id) => `/recipes/${id}`,
  merchants: (id) => `/data/merchants/${id}`,
}

const deletePath: Record<TabKey, (id: number) => string> = {
  ingredients: (id) => `/favorites/ingredient/${id}`,
  products: (id) => `/favorites/product/${id}`,
  recipes: (id) => `/favorites/recipe/${id}`,
  merchants: (id) => `/merchants/${id}/favorite`,
}

function goDetail(key: TabKey, id: number) {
  router.push(detailPath[key](id))
}

async function unfavorite(key: TabKey, id: number) {
  try {
    await api.delete(deletePath[key](id))
    grouped.value = {
      ...grouped.value,
      [key]: currentItems(key).filter((it) => it.id !== id),
    }
    notify(t('favorites.unfavorited'), 'info')
  } catch (e: any) {
    notify(getErrorMessage(e, t('favorites.unfavoriteFailed')), 'error')
  }
}

onMounted(load)
</script>
