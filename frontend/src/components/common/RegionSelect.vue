<template>
  <v-row dense>
    <v-col v-for="(level, idx) in levels" :key="idx" cols="12" sm="6">
      <v-select
        v-model="selected[idx]"
        :items="options[idx]"
        :label="level.label"
        item-title="name"
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
import { ref, watch, onMounted } from 'vue'
import { api } from '@/api'

interface Props {
  modelValue: number | null
}
const props = defineProps<Props>()
const emit = defineEmits<{ (e: 'update:modelValue', v: number | null): void }>()

const levels = [
  { label: '国家/地区', code: 0 },
  { label: '省份', code: 1 },
  { label: '城市', code: 2 },
  { label: '区县', code: 3 },
]
const selected = ref<(number | null)[]>([null, null, null, null])
const options = ref<any[][]>([[], [], [], []])

async function loadChildren(level: number, parentId: number | null) {
  const params = parentId != null ? { parent_id: parentId } : level === 0 ? {} : { level }
  const res = await api.get('/regions', { params })
  options.value[level] = Array.isArray(res) ? res : ((res as any)?.items || [])
  for (let i = level + 1; i < levels.length; i++) {
    selected.value[i] = null
    options.value[i] = []
  }
}

function currentRegionId(): number | null {
  for (let i = levels.length - 1; i >= 0; i--) {
    if (selected.value[i] != null) return selected.value[i]
  }
  return null
}

function onLevelChange(level: number) {
  const pid = selected.value[level]
  if (level < levels.length - 1) {
    if (pid == null) {
      for (let i = level + 1; i < levels.length; i++) { selected.value[i] = null; options.value[i] = [] }
    } else {
      void loadChildren(level + 1, pid)
    }
  }
  emit('update:modelValue', currentRegionId())
}

watch(() => props.modelValue, (v) => {
  // 外部值变化时，若为空则清空
  if (v == null) {
    for (let i = 0; i < levels.length; i++) { selected.value[i] = null; options.value[i] = [] }
    void loadChildren(0, null)
  }
})

onMounted(async () => {
  await loadChildren(0, null)
})
</script>