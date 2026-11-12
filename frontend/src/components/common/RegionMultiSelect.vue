<template>
  <div>
    <v-row dense>
      <v-col v-for="(level, idx) in levels" :key="idx" cols="12" sm="6">
        <v-select
          v-model="selected[idx]"
          :items="options[idx]"
          :label="level.label"
          :item-title="(item: any) => item.display_name || item.name"
          item-value="id"
          variant="outlined"
          density="compact"
          hide-details
          clearable
          :loading="loading[idx]"
          @update:model-value="onLevelChange(idx)"
        />
      </v-col>
    </v-row>
    <div class="d-flex align-center mt-2">
      <v-btn
        size="small"
        variant="tonal"
        prepend-icon="mdi-plus"
        :disabled="currentRegionId() == null || isAdded"
        @click="addCurrent"
      >{{ t('profile.customScope.addRegion') }}</v-btn>
      <span v-if="currentRegionId() != null && isAdded" class="text-caption text-medium-emphasis ms-2">
        {{ t('profile.customScope.regionAdded') }}
      </span>
    </div>
    <div v-if="chipItems.length" class="d-flex flex-wrap ga-2 mt-2">
      <v-chip
        v-for="chip in chipItems"
        :key="chip.id"
        closable
        size="small"
        label
        @click:close="removeRegion(chip.id)"
      >{{ chip.label }}</v-chip>
    </div>
    <div v-else class="text-caption text-medium-emphasis mt-2">
      {{ t('profile.customScope.noRegionSelected') }}
    </div>
  </div>
</template>

<script setup lang="ts">
// 多地区选择器：级联浏览 + 逐个添加 + chips 展示（层级可混合，如一个县 + 一个地级市）。
// modelValue 为地区 id 列表；chip 文案带祖先前缀（河南 / 三门峡市），编辑模式下
// 通过 GET /regions/{id} 的 ancestors 链回填。
import { ref, computed, watch, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { api } from '@/api'

const { t } = useI18n()

interface Props {
  modelValue: number[]
}
const props = defineProps<Props>()
const emit = defineEmits<{ (e: 'update:modelValue', v: number[]): void }>()

const levels = computed(() => [
  { label: t('region.country'), code: 0 },
  { label: t('region.province'), code: 1 },
  { label: t('region.city'), code: 2 },
  { label: t('region.district'), code: 3 },
])
const selected = ref<(number | null)[]>([null, null, null, null])
const options = ref<any[][]>([[], [], [], []])
const loading = ref<boolean[]>([false, false, false, false])
// id -> 展示文案（含祖先前缀），编辑模式回填与新增共用
const idLabel = ref<Record<number, string>>({})

async function loadChildren(level: number, parentId: number | null) {
  loading.value[level] = true
  try {
    const params = parentId != null ? { parent_id: parentId } : level === 0 ? {} : { level }
    const res = await api.get('/regions', { params })
    options.value[level] = Array.isArray(res) ? res : ((res as any)?.items || [])
    for (let i = level + 1; i < levels.value.length; i++) {
      selected.value[i] = null
      options.value[i] = []
    }
  } catch {
    options.value[level] = []
  } finally {
    loading.value[level] = false
  }
}

function onLevelChange(level: number) {
  const pid = selected.value[level]
  if (level < levels.value.length - 1) {
    if (pid == null) {
      for (let i = level + 1; i < levels.value.length; i++) { selected.value[i] = null; options.value[i] = [] }
    } else {
      void loadChildren(level + 1, pid)
    }
  }
}

function currentRegionId(): number | null {
  for (let i = levels.value.length - 1; i >= 0; i--) {
    if (selected.value[i] != null) return selected.value[i]
  }
  return null
}

const isAdded = computed(() => {
  const id = currentRegionId()
  return id != null && props.modelValue.includes(id)
})

function addCurrent() {
  const id = currentRegionId()
  if (id == null || props.modelValue.includes(id)) return
  // 用当前级联的选项名拼祖先前缀
  const parts: string[] = []
  for (let i = 0; i < levels.value.length; i++) {
    const sid = selected.value[i]
    if (sid == null) break
    const opt = options.value[i].find(o => o.id === sid)
    if (opt) parts.push(opt.display_name || opt.name)
    if (sid === id) break
  }
  idLabel.value[id] = parts.join(' / ') || String(id)
  emit('update:modelValue', [...props.modelValue, id])
}

function removeRegion(id: number) {
  emit('update:modelValue', props.modelValue.filter(x => x !== id))
}

const chipItems = computed(() => props.modelValue.map(id => ({ id, label: idLabel.value[id] || String(id) })))

// 外部值（编辑模式回填）补齐缺失的展示文案：GET /regions/{id} 祖先链
async function syncLabels(ids: number[]) {
  let changed = false
  for (const id of ids) {
    if (idLabel.value[id]) continue
    try {
      const res = (await api.get(`/regions/${id}`)) as any
      const chain = [
        ...((res?.ancestors || []) as any[]).map(a => a.display_name || a.name),
        res?.display_name || res?.name || String(id),
      ]
      idLabel.value[id] = chain.join(' / ')
      changed = true
    } catch {
      idLabel.value[id] = String(id)
      changed = true
    }
  }
  return changed
}

watch(() => props.modelValue, (ids) => {
  if (ids.length) void syncLabels(ids)
}, { immediate: true, deep: true })

onMounted(() => {
  void loadChildren(0, null)
})
</script>
