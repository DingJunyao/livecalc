<template>
  <v-card elevation="0" class="ma-4">
    <v-card-title class="d-flex align-center pb-2">
      <v-icon start color="primary">mdi-information-outline</v-icon>
      {{ t('recipes.introduction') }}
      <v-spacer />
      <template v-if="!editing">
        <v-btn
          size="small"
          variant="text"
          color="primary"
          prepend-icon="mdi-pencil"
          @click="startEdit"
        >{{ t('recipes.edit') }}</v-btn>
      </template>
      <template v-else>
        <v-btn
          size="small"
          variant="text"
          color="success"
          prepend-icon="mdi-check"
          :loading="saving"
          @click="handleSave"
        >{{ t('recipes.save') }}</v-btn>
        <v-btn
          size="small"
          variant="text"
          color="medium-emphasis"
          prepend-icon="mdi-close"
          :disabled="saving"
          @click="cancelEdit"
          class="ml-1"
        >{{ t('recipes.cancel') }}</v-btn>
      </template>
    </v-card-title>
    <v-divider />

    <!-- 查看模式 -->
    <template v-if="!editing">
      <v-card-text>
        <div class="d-flex flex-wrap ga-2 mb-3">
          <v-chip
            v-if="recipe.category"
            size="small"
            variant="tonal"
            color="primary"
          >{{ recipeCategoryLabel(recipe.category) }}</v-chip>
          <v-chip
            v-if="recipe.difficulty"
            size="small"
            variant="tonal"
            color="secondary"
          >{{ difficultyLabel }}</v-chip>
          <v-chip
            v-if="resultIngredientName"
            size="small"
            variant="tonal"
            color="success"
          >{{ t('recipes.resultOutput', { name: resultIngredientName }) }}</v-chip>
        </div>
        <div
          v-if="recipe.description"
          class="text-body-2"
          style="white-space: pre-wrap"
        >{{ recipe.description }}</div>
        <div
          v-else
          class="text-body-2 text-medium-emphasis"
        >{{ t('recipes.noIntroduction') }}</div>
      </v-card-text>
    </template>

    <!-- 编辑模式 -->
    <v-card-text v-else>
      <v-text-field
        v-model="editForm.name"
        :label="t('recipes.name')"
        variant="outlined"
        density="compact"
        maxlength="200"
        hide-details
        class="mb-3"
      />
      <v-row class="mb-3">
        <v-col cols="6">
          <v-select
            v-model="editForm.category"
            :label="t('recipes.category')"
            variant="outlined"
            density="compact"
            :items="categoryOptions"
            hide-details
          />
        </v-col>
        <v-col cols="6">
          <v-select
            v-model="editForm.difficulty"
            :label="t('recipes.difficulty')"
            variant="outlined"
            density="compact"
            :items="difficultyOptions"
            item-title="label"
            item-value="value"
            hide-details
          />
        </v-col>
      </v-row>
      <v-textarea
        v-model="editForm.description"
        :label="t('recipes.description')"
        variant="outlined"
        density="compact"
        auto-grow
        rows="3"
        maxlength="2000"
        hide-details
        class="mb-4"
      />

      <!-- 成品产出原料（半成品菜谱） -->
      <div class="text-subtitle-2 mb-1">{{ t('recipes.resultOutputTitle') }}</div>
      <div class="text-caption text-medium-emphasis mb-2">{{ t('recipes.resultOutputHint') }}</div>
      <v-autocomplete
        v-model="editForm.result_ingredient_id"
        :items="ingredientOptions"
        item-title="name"
        item-value="id"
        :label="t('recipes.resultIngredient')"
        variant="outlined"
        density="compact"
        clearable
        :loading="ingredientSearching"
        @update:search="onIngredientSearch"
        hide-details
        class="mb-4"
      />

      <!-- 配图管理 -->
      <v-divider class="mb-3" />
      <div class="text-subtitle-2 mb-2">{{ t('recipes.imageManagement') }}</div>
      <ImageManager
        :model-value="editImages"
        :image-urls="editImageUrls"
        :recipe-id="recipe.id"
        :uploading="uploadingImage"
        @update:model-value="onEditImagesUpdated"
        @upload="handleImageUpload"
        @remove="handleImageRemove"
      />
    </v-card-text>
  </v-card>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { api } from '@/api'
import ImageManager from './ImageManager.vue'
import {
  type RecipeDetail,
} from './types'
import { useI18n } from 'vue-i18n'
import {
  RECIPE_CATEGORY_KEYS,
  RECIPE_CATEGORY_VALUES,
} from '../../data/recipeCategories.ts'

const props = defineProps<{
  recipe: RecipeDetail
}>()

const { t } = useI18n()

const RECIPE_DIFFICULTY_KEYS: Record<string, string> = {
  simple: 'recipeDifficulties.simple',
  easy: 'recipeDifficulties.easy',
  medium: 'recipeDifficulties.medium',
  hard: 'recipeDifficulties.hard',
  expert: 'recipeDifficulties.expert',
}

function recipeCategoryLabel(category?: string): string {
  const key = category ? RECIPE_CATEGORY_KEYS[category] : null
  return key && category ? t(key) : (category || '')
}

function recipeDifficultyLabel(difficulty?: string): string {
  const key = difficulty ? RECIPE_DIFFICULTY_KEYS[difficulty] : null
  return key && difficulty ? t(key) : (difficulty || '')
}

const emit = defineEmits<{
  (e: 'saved', recipe: RecipeDetail): void
  (e: 'images-changed'): void
}>()

const editing = ref(false)
const saving = ref(false)
const uploadingImage = ref(false)
const editForm = ref({
  name: '',
  category: '',
  difficulty: '',
  description: '',
  result_ingredient_id: null as number | null,
})
const editImages = ref<string[]>([])
const editImageUrls = ref<string[]>([])

// 成品产出原料搜索
const ingredientOptions = ref<{ id: number; name: string }[]>([])
const ingredientSearching = ref(false)
const resultIngredientName = ref('')
let searchTimer: any = null

const onIngredientSearch = (q: string) => {
  if (searchTimer) clearTimeout(searchTimer)
  if (!q || !q.trim()) return
  searchTimer = setTimeout(async () => {
    ingredientSearching.value = true
    try {
      const res = await api.get(`/ingredients/search-by-name/${encodeURIComponent(q.trim())}`)
      ingredientOptions.value = (res || []).map((i: any) => ({ id: i.id, name: i.name }))
    } catch (e) {
      console.error('Failed to search ingredients', e)
    } finally {
      ingredientSearching.value = false
    }
  }, 300)
}

// 成品原料名（查看模式展示）：初始加载时若已绑定则查名
watch(() => props.recipe.result_ingredient_id, async (id) => {
  if (id) {
    try {
      const r = await api.get(`/ingredients/${id}`)
      resultIngredientName.value = r?.name || ''
      ingredientOptions.value = [{ id, name: r?.name || '' }]
    } catch {
      resultIngredientName.value = ''
    }
  } else {
    resultIngredientName.value = ''
  }
}, { immediate: true })

const categoryOptions = computed(() => RECIPE_CATEGORY_VALUES.map((value) => ({
  title: recipeCategoryLabel(value),
  value,
})))

const difficultyOptions = computed(() => [
  { label: recipeDifficultyLabel('simple'), value: 'simple' },
  { label: recipeDifficultyLabel('easy'), value: 'easy' },
  { label: recipeDifficultyLabel('medium'), value: 'medium' },
  { label: recipeDifficultyLabel('hard'), value: 'hard' },
  { label: recipeDifficultyLabel('expert'), value: 'expert' },
])

const difficultyLabel = computed(() => {
  const opt = difficultyOptions.value.find(d => d.value === props.recipe.difficulty)
  return opt?.label || props.recipe.difficulty || ''
})

const startEdit = () => {
  editForm.value = {
    name: props.recipe.name || '',
    category: props.recipe.category || '',
    difficulty: props.recipe.difficulty || '',
    description: props.recipe.description || '',
    result_ingredient_id: props.recipe.result_ingredient_id ?? null,
  }
  editImages.value = [...(props.recipe.images || [])]
  editImageUrls.value = [...(props.recipe.image_urls || [])]
  editing.value = true
}

const cancelEdit = () => {
  editing.value = false
}

// 上传配图 — 立即上传到后端
const handleImageUpload = async (file: File) => {
  uploadingImage.value = true
  try {
    const formData = new FormData()
    formData.append('file', file)
    const result = await api.post(`/recipes/${props.recipe.id}/images`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    })
    if (result?.image_path) {
      editImages.value.push(result.image_path)
    }
    if (result?.image_url) {
      editImageUrls.value.push(result.image_url)
    }
  } catch (e: any) {
    console.error('Failed to upload image', e)
  } finally {
    uploadingImage.value = false
  }
}

// ImageManager 通过 update:modelValue 通知列表变更（移动排序时）
// 需同步 editImageUrls 保持 URL 与 key 的索引一致
const onEditImagesUpdated = (newImages: string[]) => {
  const oldImages = editImages.value
  editImages.value = newImages
  // 如果长度相同，说明是排序操作（非增删），同步 URL 顺序
  if (newImages.length === oldImages.length) {
    const urlByKey: Record<string, string> = {}
    oldImages.forEach((key, i) => {
      if (editImageUrls.value[i]) urlByKey[key] = editImageUrls.value[i]
    })
    editImageUrls.value = newImages.map(key => urlByKey[key] || '')
  }
  // 长度不同时，增删操作有各自的 handler（handleImageRemove / handleImageUpload）
  // 不需要额外处理
}

// 删除配图 — 仅从本地列表移除，实际变更在保存时通过 PUT /recipes/{id} 的 images 字段提交
// 这样已发布菜谱会走审核提议流程（与菜谱信息编辑一致），未发布菜谱直接生效
// 注意：editImageUrls 必须与 editImages 同步删除，否则 ImageManager 的 imageUrls 索引会错位
const handleImageRemove = (index: number) => {
  editImages.value.splice(index, 1)
  editImageUrls.value.splice(index, 1)
}

const handleSave = async () => {
  saving.value = true
  try {
    // 收集有变化的字段
    const payload: Record<string, any> = {}
    if (editForm.value.name !== props.recipe.name) payload.name = editForm.value.name
    if (editForm.value.category !== props.recipe.category) payload.category = editForm.value.category
    if (editForm.value.difficulty !== props.recipe.difficulty) payload.difficulty = editForm.value.difficulty
    if (editForm.value.description !== (props.recipe.description || '')) payload.description = editForm.value.description
    const newRiId = editForm.value.result_ingredient_id ?? null
    const oldRiId = props.recipe.result_ingredient_id ?? null
    if (newRiId !== oldRiId) payload.result_ingredient_id = newRiId
    if (JSON.stringify(editImages.value) !== JSON.stringify(props.recipe.images || [])) {
      payload.images = editImages.value
    }

    if (Object.keys(payload).length === 0) {
      editing.value = false
      return
    }

    const result = await api.put(`/recipes/${props.recipe.id}`, payload)
    emit('saved', result)
    emit('images-changed')
    editing.value = false
  } catch (e: any) {
    console.error('Failed to save basic information', e)
  } finally {
    saving.value = false
  }
}
</script>
