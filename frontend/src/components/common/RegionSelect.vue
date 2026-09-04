<template>
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
        @update:model-value="onLevelChange(idx)"
      />
    </v-col>
  </v-row>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { api } from '@/api'

const { t } = useI18n()

interface Props {
  modelValue: number | null
}
const props = defineProps<Props>()
const emit = defineEmits<{ (e: 'update:modelValue', v: number | null): void }>()

const levels = computed(() => [
  { label: t('region.country'), code: 0 },
  { label: t('region.province'), code: 1 },
  { label: t('region.city'), code: 2 },
  { label: t('region.district'), code: 3 },
])
const selected = ref<(number | null)[]>([null, null, null, null])
const options = ref<any[][]>([[], [], [], []])

async function loadChildren(level: number, parentId: number | null) {
  const params = parentId != null ? { parent_id: parentId } : level === 0 ? {} : { level }
  const res = await api.get('/regions', { params })
  options.value[level] = Array.isArray(res) ? res : ((res as any)?.items || [])
  for (let i = level + 1; i < levels.value.length; i++) {
    selected.value[i] = null
    options.value[i] = []
  }
}

function currentRegionId(): number | null {
  for (let i = levels.value.length - 1; i >= 0; i--) {
    if (selected.value[i] != null) return selected.value[i]
  }
  return null
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
  emit('update:modelValue', currentRegionId())
}

// 已存 region_id 回填级联（含只填国家/地区）：GET /regions/{id} 返回祖先链
async function applyValue(v: number) {
  const res = (await api.get(`/regions/${v}`)) as any
  if (props.modelValue !== v) return // 外部值已变，丢弃过期回填
  const chain: { id: number; level: number }[] = [
    ...((res?.ancestors || []) as any[]).map(a => ({ id: a.id, level: a.level })),
    { id: res.id, level: res.level },
  ].sort((a, b) => a.level - b.level)
  if (!options.value[0].length) {
    await loadChildren(0, null)
    if (props.modelValue !== v) return
  }
  for (let i = 0; i < chain.length; i++) {
    selected.value[chain[i].level] = chain[i].id
    if (i < chain.length - 1) {
      await loadChildren(chain[i + 1].level, chain[i].id)
      if (props.modelValue !== v) return
    }
  }
}

watch(() => props.modelValue, (v) => {
  if (v == null) {
    for (let i = 0; i < levels.value.length; i++) { selected.value[i] = null; options.value[i] = [] }
    void loadChildren(0, null)
  } else if (v !== currentRegionId()) {
    void applyValue(v)
  }
}, { immediate: true })
</script>
