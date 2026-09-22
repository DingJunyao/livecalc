<template>
  <v-container fluid>
    <v-app-bar elevation="0" color="background" density="comfortable" fixed>
      <v-app-bar-nav-icon @click="toggleSidebar(isDesktop)" />
      <v-btn icon="mdi-arrow-left" variant="text" @click="goBack" />
      <v-app-bar-title>{{ t('admin.blacklist.title') }}</v-app-bar-title>
      <template #append>
        <v-select
          v-if="providerOptions.length"
          v-model="aiProvider"
          :items="localizedProviderOptions"
          item-title="label"
          item-value="value"
          :label="t('admin.provider')"
          variant="outlined"
          density="compact"
          hide-details
          class="me-2 provider-select"
        />
        <v-btn
          color="primary"
          prepend-icon="mdi-robot"
          size="small"
          class="me-2"
          :loading="aiMatchingAll"
          :disabled="!providerOptions.length || !groups.length"
          @click="triggerAiMatchAll"
        >
          {{ t('admin.blacklist.aiMatchAll') }}
        </v-btn>
        <v-btn color="primary" prepend-icon="mdi-plus" size="small" @click="openCreate">{{ t('admin.blacklist.createGroup') }}</v-btn>
      </template>
    </v-app-bar>

    <v-container style="max-width: 960px">
      <!-- 快速导入过敏原提示（仅在未完整导入时显示） -->
      <v-alert
        v-if="allergenStatus.needed"
        type="info"
        variant="tonal"
        class="mb-4"
        closable
      >
        <div class="text-body-2 mb-2">
          {{ t('admin.blacklist.allergenIntro') }}
          <span v-if="allergenStatus.missing_groups.length">
            {{ t('admin.blacklist.allergenMissing', { count: formatCount(allergenStatus.missing_groups.length) }) }}
          </span>
          <span v-if="allergenStatus.empty_groups.length">
            {{ t('admin.blacklist.allergenEmpty', { count: formatCount(allergenStatus.empty_groups.length) }) }}
          </span>
          {{ t('admin.blacklist.allergenComplete') }}
        </div>
        <v-btn
          color="primary"
          variant="tonal"
          size="small"
          :loading="seedingAllergens"
          @click="seedAllergens"
        >
          <v-icon start>mdi-shield-sync</v-icon>
          {{ t('admin.blacklist.importAllergens') }}
        </v-btn>
      </v-alert>

      <v-card v-for="group in groups" :key="group.id" class="mb-4" elevation="0">
        <v-card-title class="d-flex align-center">
          <v-icon icon="mdi-shield-alert" class="me-2" />
          {{ group.name }}
          <v-chip size="small" class="ms-2">{{ t('admin.blacklist.ingredientCount', { count: formatCount(group.ingredient_count) }) }}</v-chip>
          <v-spacer />
          <v-btn icon="mdi-pencil" variant="text" size="small" @click="openEdit(group)" />
          <v-btn icon="mdi-delete" variant="text" size="small" color="error" @click="confirmDelete(group)" />
        </v-card-title>
        <v-card-text>
          <!-- 原料列表 -->
          <div v-if="group.ingredients && group.ingredients.length > 0">
            <v-chip
              v-for="ing in group.ingredients"
              :key="ing.id"
              size="small"
              class="me-1 mb-1"
              :color="ing.is_ai_matched ? 'info' : undefined"
              closable
              @click:close="removeIngredient(group.id, ing.ingredient_id)"
            >
              {{ ing.ingredient_name }}
              <v-tooltip v-if="ing.is_ai_matched" activator="parent" :text="t('admin.blacklist.aiMatched')" />
            </v-chip>
          </div>
          <div v-else class="text-caption text-medium-emphasis">
            {{ t('admin.blacklist.noIngredients') }}
          </div>
        </v-card-text>
        <v-card-actions>
          <v-btn variant="text" size="small" color="primary" @click="openAddIngredients(group)">
            <v-icon start>mdi-plus</v-icon> {{ t('admin.blacklist.addIngredients') }}
          </v-btn>
          <v-btn
            variant="text"
            size="small"
            color="warning"
            :loading="aiMatchingGroups.has(group.id)"
            @click="triggerAiMatch(group)"
          >
            <v-icon start>mdi-robot</v-icon> {{ t('admin.blacklist.aiMatch') }}
          </v-btn>
        </v-card-actions>
      </v-card>

      <div v-if="groups.length === 0 && !loading" class="text-center pa-8 text-medium-emphasis">
        {{ t('admin.blacklist.empty') }}
      </div>
    </v-container>

    <!-- 创建/编辑对话框 -->
    <v-dialog v-model="editDialog" max-width="400">
      <v-card>
        <v-card-title>{{ editingGroup ? t('admin.blacklist.editGroup') : t('admin.blacklist.createGroup') }}</v-card-title>
        <v-card-text>
          <v-text-field v-model="form.name" :label="t('admin.blacklist.groupName')" variant="outlined" density="compact" />
          <v-text-field v-model.number="form.display_order" :label="t('admin.blacklist.order')" type="number" variant="outlined" density="compact" />
          <v-switch v-if="editingGroup" v-model="form.is_active" :label="t('admin.blacklist.enabled')" density="compact" hide-details />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="editDialog = false">{{ t('actions.cancel') }}</v-btn>
          <v-btn color="primary" :loading="saving" @click="saveGroup">{{ t('actions.save') }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- 添加原料对话框 -->
    <v-dialog v-model="addIngredientsDialog" max-width="500">
      <v-card>
        <v-card-title>{{ t('admin.blacklist.addIngredientsTo', { name: selectedGroupForAdd?.name ?? '' }) }}</v-card-title>
        <v-card-text>
          <v-autocomplete
            v-model="selectedIngredientIds"
            :items="ingredientOptions"
            item-title="name"
            item-value="id"
            :label="t('admin.blacklist.searchIngredients')"
            variant="outlined"
            density="compact"
            multiple
            chips
            closable-chips
            @update:search="searchAllIngredients"
          />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="addIngredientsDialog = false">{{ t('actions.cancel') }}</v-btn>
          <v-btn color="primary" :loading="saving" @click="saveIngredients">{{ t('admin.blacklist.confirmAdd') }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
    <!-- 删除确认对话框 -->
    <v-dialog v-model="deleteDialog" max-width="400">
      <v-card>
        <v-card-title>{{ t('admin.blacklist.deleteTitle') }}</v-card-title>
        <v-card-text>
          {{ t('admin.blacklist.deleteConfirm', { name: deleteTarget?.name ?? '' }) }}
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="deleteDialog = false">{{ t('actions.cancel') }}</v-btn>
          <v-btn color="error" :loading="saving" @click="doDelete">{{ t('admin.blacklist.delete') }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- 错误提示 -->
    <v-snackbar v-model="snackbar.show" :color="snackbar.color" timeout="4000" location="top">
      {{ snackbar.message }}
      <template #actions>
        <v-btn variant="text" @click="snackbar.show = false">{{ t('actions.close') }}</v-btn>
      </template>
    </v-snackbar>
  </v-container>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import { api } from '@/api'
import { useMobileDrawerControl } from '@/composables/useMobileDrawer'
import { enabledProviderOptions, type ProviderOption } from '@/utils/agentProviders'
import { formatNumber } from '@/utils/format'
import { useLocaleStore } from '@/stores/locale'

const { toggleSidebar, isDesktop } = useMobileDrawerControl()
const { t } = useI18n()
const localeStore = useLocaleStore()
const formatCount = (value: number) => formatNumber(value, localeStore.effectiveFormatLocale)
const router = useRouter()
const isLocalMode = computed(() => import.meta.env.VITE_STORAGE_MODE === 'local')

const goBack = () => {
  router.back()
}

interface GroupIngredient {
  id: number
  ingredient_id: number
  ingredient_name: string | null
  is_ai_matched: boolean
}

interface BlacklistGroup {
  id: number
  name: string
  display_order: number
  is_active: boolean
  ingredients: GroupIngredient[]
  ingredient_count: number
}

interface AllergenStatus {
  needed: boolean
  total: number
  existing: number
  with_mappings: number
  missing_groups: string[]
  empty_groups: string[]
}

const groups = ref<BlacklistGroup[]>([])
const translationConfig = ref<any>(null)
const aiProvider = ref('claude_code')
const aiMatchingAll = ref(false)
const providerOptions = computed<ProviderOption[]>(() =>
  enabledProviderOptions(translationConfig.value, ['ai'], isLocalMode.value),
)
const providerLabels = computed<Record<string, string>>(() => ({
  claude_code: 'Claude Code',
  codex: 'Codex',
  openai: t('adminAI.providers.openaiCompatible'),
  anthropic: t('adminAI.providers.anthropicCompatible'),
  baidu: t('adminAI.providers.baidu'),
  aliyun: t('adminAI.providers.aliyun'),
  deepl: t('adminAI.providers.deepl'),
}))
const localizedProviderOptions = computed<ProviderOption[]>(() =>
  providerOptions.value.map((option) => ({
    ...option,
    label: providerLabels.value[option.value] || option.label,
  })),
)
const allergenStatus = ref<AllergenStatus>({
  needed: false,
  total: 13,
  existing: 0,
  with_mappings: 0,
  missing_groups: [],
  empty_groups: [],
})
const seedingAllergens = ref(false)
const loading = ref(false)
const aiMatchingGroups = ref(new Set<number>())
const snackbar = ref({ show: false, message: '', color: 'error' })
const deleteDialog = ref(false)
const deleteTarget = ref<BlacklistGroup | null>(null)

function showError(msg: string) {
  snackbar.value = { show: true, message: msg, color: 'error' }
}

function showInfo(msg: string) {
  snackbar.value = { show: true, message: msg, color: 'info' }
}

function messageFrom(error: any): string {
  return error?.userMessage || error?.message || t('errors.unknown')
}

// 编辑
const editDialog = ref(false)
const editingGroup = ref<BlacklistGroup | null>(null)
const saving = ref(false)
const form = ref({ name: '', display_order: 0, is_active: true })

// 添加原料
const addIngredientsDialog = ref(false)
const selectedGroupForAdd = ref<BlacklistGroup | null>(null)
const selectedIngredientIds = ref<number[]>([])
const ingredientOptions = ref<any[]>([])
const selectedIngredientsCache = ref<Map<number, any>>(new Map())

async function loadGroups() {
  loading.value = true
  try {
    const data = await api.get('/admin/blacklist-groups')
    groups.value = data
  } catch (e) {
    console.error('Failed to load groups', e)
  } finally {
    loading.value = false
  }
}

function openCreate() {
  editingGroup.value = null
  form.value = { name: '', display_order: 0, is_active: true }
  editDialog.value = true
}

function openEdit(group: BlacklistGroup) {
  editingGroup.value = group
  form.value = { name: group.name, display_order: group.display_order, is_active: group.is_active }
  editDialog.value = true
}

async function saveGroup() {
  saving.value = true
  try {
    if (editingGroup.value) {
      await api.put(`/admin/blacklist-groups/${editingGroup.value.id}`, {
        name: form.value.name,
        display_order: form.value.display_order,
        is_active: form.value.is_active,
      })
    } else {
      await api.post('/admin/blacklist-groups', {
        name: form.value.name,
        display_order: form.value.display_order,
      })
    }
    editDialog.value = false
    await loadGroups()
  } catch (e: any) {
    showError(t('admin.blacklist.saveFailed', { message: messageFrom(e) }))
  } finally {
    saving.value = false
  }
}

function confirmDelete(group: BlacklistGroup) {
  deleteTarget.value = group
  deleteDialog.value = true
}

async function doDelete() {
  if (!deleteTarget.value) return
  saving.value = true
  try {
    await api.delete(`/admin/blacklist-groups/${deleteTarget.value.id}`)
    deleteDialog.value = false
    deleteTarget.value = null
    await loadGroups()
  } catch (e: any) {
    showError(t('admin.blacklist.deleteFailed', { message: messageFrom(e) }))
  } finally {
    saving.value = false
  }
}

function openAddIngredients(group: BlacklistGroup) {
  selectedGroupForAdd.value = group
  selectedIngredientIds.value = []
  ingredientOptions.value = []
  selectedIngredientsCache.value.clear()
  addIngredientsDialog.value = true
}

async function searchAllIngredients(search: string | null) {
  if (!search || search.length < 1) {
    // 无搜索词时显示已选中的原料
    ingredientOptions.value = Array.from(selectedIngredientsCache.value.values())
    return
  }
  try {
    const data = await api.get(`/ingredients/search-by-name/${encodeURIComponent(search || '')}`)
    const results: any[] = Array.isArray(data) ? data : []
    // 将已选中的原料合并进结果，避免已选项只显示数字 ID
    const merged = [...results]
    for (const cached of selectedIngredientsCache.value.values()) {
      if (!merged.some((r: any) => r.id === cached.id)) {
        merged.unshift(cached)
      }
    }
    ingredientOptions.value = merged
  } catch {
    ingredientOptions.value = Array.from(selectedIngredientsCache.value.values())
  }
}

// 监听选中变化，缓存完整对象避免只显示数字 ID
watch(selectedIngredientIds, (newIds, oldIds) => {
  // 新增的 ID：从当前选项中获取完整对象并缓存
  for (const id of newIds) {
    if (!selectedIngredientsCache.value.has(id)) {
      const found = ingredientOptions.value.find((item: any) => item.id === id)
      if (found) selectedIngredientsCache.value.set(id, found)
    }
  }
  // 移除的 ID：从缓存中清理
  for (const id of (oldIds || [])) {
    if (!newIds.includes(id)) {
      selectedIngredientsCache.value.delete(id)
    }
  }
})

async function saveIngredients() {
  if (!selectedGroupForAdd.value) return
  saving.value = true
  try {
    await api.post(`/admin/blacklist-groups/${selectedGroupForAdd.value.id}/ingredients`, {
      ingredient_ids: selectedIngredientIds.value,
    })
    addIngredientsDialog.value = false
    await loadGroups()
  } catch (e: any) {
    showError(t('admin.blacklist.addFailed', { message: messageFrom(e) }))
  } finally {
    saving.value = false
  }
}

async function removeIngredient(groupId: number, ingredientId: number) {
  try {
    await api.delete(`/admin/blacklist-groups/${groupId}/ingredients/${ingredientId}`)
    // 从本地列表移除
    const group = groups.value.find(g => g.id === groupId)
    if (group) {
      group.ingredients = group.ingredients.filter(i => i.ingredient_id !== ingredientId)
      group.ingredient_count = group.ingredients.length
    }
  } catch (e: any) {
    showError(t('admin.blacklist.removeFailed', { message: messageFrom(e) }))
  }
}

async function triggerAiMatch(group: BlacklistGroup) {
  aiMatchingGroups.value.add(group.id)
  try {
    const data = await api.post(`/admin/blacklist-groups/${group.id}/ai-match`, {
      provider: aiProvider.value,
    })
    showInfo(t('admin.blacklist.aiTaskStarted', { id: formatCount(data.agent_session_id) }))
  } catch (e: any) {
    showError(t('admin.blacklist.triggerFailed', { message: messageFrom(e) }))
  } finally {
    aiMatchingGroups.value.delete(group.id)
  }
}

async function triggerAiMatchAll() {
  aiMatchingAll.value = true
  try {
    const data = await api.post('/admin/blacklist-groups/ai-match-all', {
      provider: aiProvider.value,
    })
    showInfo(t('admin.blacklist.aiAllTaskStarted', { id: formatCount(data.agent_session_id) }))
  } catch (e: any) {
    showError(t('admin.blacklist.triggerFailed', { message: messageFrom(e) }))
  } finally {
    aiMatchingAll.value = false
  }
}

async function loadAllergenStatus() {
  try {
    const data = await api.get('/admin/blacklist-groups/allergens-status')
    allergenStatus.value = data
  } catch (e) {
    console.error('Failed to load allergen import status', e)
  }
}

async function seedAllergens() {
  seedingAllergens.value = true
  try {
    const data = await api.post('/admin/blacklist-groups/seed-allergens')
    showInfo(data.message)
    await Promise.all([loadGroups(), loadAllergenStatus()])
  } catch (e: any) {
    showError(t('admin.blacklist.importFailed', { message: messageFrom(e) }))
  } finally {
    seedingAllergens.value = false
  }
}

onMounted(async () => {
  try {
    translationConfig.value = await api.get('/admin/translation-config')
    if (
      providerOptions.value.length &&
      !providerOptions.value.some((o) => o.value === aiProvider.value)
    ) {
      aiProvider.value = providerOptions.value[0].value
    }
  } catch {
    // 保留默认 claude_code
  }
  await Promise.all([loadGroups(), loadAllergenStatus()])
})
</script>

<style scoped>
.provider-select {
  max-width: 180px;
}
</style>
