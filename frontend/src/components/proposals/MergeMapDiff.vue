<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import type { Proposal } from '@/api/proposals'
import { api } from '@/api'
import { formatNumber } from '@/utils/format'
import { useLocaleStore } from '@/stores/locale'

const props = defineProps<{ proposal: Proposal }>()
const { t } = useI18n()
const localeStore = useLocaleStore()

const entityType = computed(() => props.proposal.entity_type)
const isIngredient = computed(() => entityType.value === 'ingredient')
const snap = computed(() => props.proposal.snapshot || {})
const payload = computed(() => props.proposal.payload || {})

// ── 自动回填（snapshot 无数据时调用预览 API） ──
const previewBackfill = ref<Record<string, any> | null>(null)
const loadingPreview = ref(false)

async function fetchPreview() {
  // 已有 snapshot 数据 → 不重复加载
  if (isIngredient.value) {
    if (snap.value.recipe_ingredients?.length || snap.value.product_links?.length) return
  } else {
    if (snap.value.product_records?.length) return
  }
  loadingPreview.value = true
  try {
    const res = await api.post('/proposals/preview', {
      entity_type: props.proposal.entity_type,
      entity_id: props.proposal.entity_id,
      action: props.proposal.action,
      payload: props.proposal.payload,
    })
    previewBackfill.value = res
  } catch { /* ignore */ }
  finally { loadingPreview.value = false }
}

onMounted(fetchPreview)

// ── 数据源 ──
// 优先 snapshot，其次预填 payload.preview（旧前端提交式），其次自动回填
function pv(key: string): any {
  const pb = previewBackfill.value
  const pp = (payload.value.preview as Record<string, any>) || {}
  return pb?.[key] ?? pp?.[key]
}

// 来源列表
const sources = computed<string[]>(() => {
  const s = snap.value.sources as any[] | undefined
  if (s?.length) return s.map((x: any) => x.name || t('proposals.idFallback', { id: x.id }))
  const ps = pv('sources') as any[] | undefined
  if (ps?.length) return ps.map((x: any) => x.name || t('proposals.idFallback', { id: x.id }))
  return []
})

const sourceCount = computed(() => sources.value.length || pv('source_count') || 0)
const targetName = computed(() =>
  snap.value.target_name || pv('target_name') || t('proposals.idFallback', { id: payload.value.target_id })
)

/** 预览 API 字段名与影响范围标签的映射。
 *  食材合并预览返 affected_recipe_ingredients（数字），
 *  snapshot 存 recipe_ingredients（数组），统一取数。 */
const INGREDIENT_PREVIEW_KEYS: Record<string, string> = {
  recipe_ingredients: 'affected_recipe_ingredients',
  product_links: 'affected_product_links',
  hierarchies: 'affected_hierarchies',
  nutrition_mappings: 'affected_nutrition_mappings',
}
const MERCHANT_PREVIEW_KEYS: Record<string, string> = {
  product_records: 'affected_price_records',
  favorites: 'affected_favorites',
}

/** 预制食材合并 5 个影响维度标签，按此顺序渲染。 */
const INGREDIENT_CARD_KEYS: Array<{ key: string; labelKey: string }> = [
  { key: 'recipe_ingredients', labelKey: 'proposals.recipeReferences' },
  { key: 'product_links', labelKey: 'proposals.productLinks' },
  { key: 'hierarchies', labelKey: 'proposals.hierarchyRelationships' },
  { key: 'nutrition_mappings', labelKey: 'proposals.nutritionMappings' },
  { key: 'price_records', labelKey: 'proposals.priceRecords' },
]

function snapCount(key: string): number {
  // 优先后端实时补充的平字段（如 recipe_ingredients_count）
  const flat = snap.value[`${key}_count`] as number | undefined
  if (flat != null) return flat
  // 其次 snapshot 数组长度（build_snapshot/apply 存了完整数组）
  const arr = snap.value[key] as any[] | undefined
  if (arr?.length) return arr.length
  // 最后回退预览 API
  const ings = isIngredient.value ? INGREDIENT_PREVIEW_KEYS : MERCHANT_PREVIEW_KEYS
  const pvKey = ings[key]
  return pvKey ? (pv(pvKey) as number) ?? 0 : 0
}

function ingredientPriceCount(): number {
  // 后端实时补充的平字段
  const flat = snap.value.affected_price_records as number | undefined
  if (flat != null) return flat
  // 预览 API 回填
  return (pv('affected_price_records') as number) ?? 0
}

const impactCards = computed(() => {
  if (isIngredient.value) {
    return INGREDIENT_CARD_KEYS.map(c => ({
      label: t(c.labelKey),
      count: c.key === 'price_records'
        ? ingredientPriceCount()
        : snapCount(c.key),
    }))
  }
  return [
    { label: t('proposals.priceRecords'), count: snapCount('product_records') },
    { label: t('proposals.favorites'), count: snapCount('favorites') },
  ]
})

interface DetailRow { category: string; name: string }
const details = computed<DetailRow[]>(() => {
  const out: DetailRow[] = []
  if (isIngredient.value) {
    for (const r of (snap.value.recipe_ingredients || [])) {
      out.push({
        category: t('proposalEntityTypes.recipe'),
        name: r.recipe_name || t('proposals.namedFallback', { type: t('proposalEntityTypes.recipe'), id: r.recipe_id }),
      })
    }
    for (const l of (snap.value.product_links || [])) {
      out.push({
        category: t('proposalEntityTypes.product'),
        name: l.product_name || t('proposals.namedFallback', { type: t('proposalEntityTypes.product'), id: l.product_id }),
      })
    }
  } else {
    for (const r of (snap.value.product_records || [])) {
      out.push({
        category: t('proposals.priceRecords'),
        name: r.product_name || t('proposals.recordFallback', { id: r.id }),
      })
    }
  }
  return out
})

const sourceList = computed(() =>
  new Intl.ListFormat(localeStore.effectiveFormatLocale, { type: 'conjunction' }).format(sources.value))

const DETAIL_PREVIEW = 5
const showAllDetails = ref(false)
const visibleDetails = computed(() =>
  showAllDetails.value ? details.value : details.value.slice(0, DETAIL_PREVIEW))
</script>

<template>
  <div>
    <!-- merge direction -->
    <div class="d-flex align-center flex-wrap mb-3" style="gap: 4px">
      <div class="d-flex flex-wrap ga-1">
        <v-chip v-for="(s, i) in sources" :key="i" size="small" color="error" variant="tonal">
          <span class="text-decoration-line-through">{{ s }}</span>
        </v-chip>
      </div>
      <v-icon class="mx-2" size="small">mdi-arrow-right</v-icon>
      <v-chip size="small" color="success" variant="flat">{{ targetName }}</v-chip>
      <v-progress-circular v-if="loadingPreview" indeterminate size="14" width="2" class="ms-1" />
    </div>

    <!-- source handling note -->
    <v-alert type="info" variant="tonal" density="compact" class="mb-3">
      <template v-if="sources.length">
        {{ t('proposals.mergeSourceIntro', {
          count: formatNumber(sourceCount, localeStore.effectiveFormatLocale),
          sources: sourceList,
          target: targetName,
        }) }}
      </template>
      <template v-else-if="loadingPreview">
        {{ t('proposals.loadingPreview') }}
      </template>
      <template v-else>
        {{ t('proposals.noSourceInformation') }}
      </template>
    </v-alert>

    <!-- impact counts -->
    <div class="text-subtitle-2 mb-2">{{ t('proposals.impactScope') }}</div>
    <div class="d-flex mb-2" style="gap: 4px">
      <div v-for="card in impactCards" :key="card.label" style="flex: 1; min-width: 0">
        <v-card variant="outlined" density="compact" class="text-center pa-2">
          <div class="text-h6">{{ formatNumber(card.count, localeStore.effectiveFormatLocale) }}</div>
          <div class="text-caption text-medium-emphasis">{{ card.label }}</div>
        </v-card>
      </div>
    </div>

    <!-- migration details (default expanded) -->
    <div v-if="details.length" class="text-subtitle-2 mb-1">{{ t('proposals.migrationDetails') }}</div>
    <v-list v-if="details.length" density="compact" class="bg-transparent">
      <v-list-item v-for="(d, i) in visibleDetails" :key="i" class="px-0">
        <template #prepend>
          <v-chip size="x-small" variant="outlined">{{ d.category }}</v-chip>
        </template>
        <v-list-item-title class="text-body-2">{{ d.name }}</v-list-item-title>
      </v-list-item>
      <v-list-item v-if="details.length > DETAIL_PREVIEW" class="px-0">
        <v-btn variant="text" size="small" @click="showAllDetails = !showAllDetails">
          {{ showAllDetails
            ? t('proposals.collapse')
            : t('proposals.showRemaining', {
              count: formatNumber(details.length - DETAIL_PREVIEW, localeStore.effectiveFormatLocale),
            }) }}
        </v-btn>
      </v-list-item>
    </v-list>
  </div>
</template>
