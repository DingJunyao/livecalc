<template>
  <v-dialog
    :model-value="modelValue"
    max-width="560"
    scrollable
    @update:model-value="(v: boolean) => emit('update:modelValue', v)"
  >
    <v-card>
      <v-card-title class="d-flex align-center">
        <template v-if="!editing">{{ t('profile.customScope.managerTitle') }}</template>
        <template v-else>{{ editing.id ? t('profile.customScope.editTitle') : t('profile.customScope.createTitle') }}</template>
        <v-spacer />
        <v-btn icon="mdi-close" variant="text" size="small" :aria-label="t('common.close')" @click="close" />
      </v-card-title>

      <v-divider />

      <!-- 列表视图 -->
      <v-card-text v-if="!editing" class="pa-0" style="min-height: 200px">
        <div v-if="!loading && !scopes.length" class="text-caption text-medium-emphasis pa-4">
          {{ t('profile.customScope.emptyHint') }}
        </div>
        <v-list>
          <v-list-item v-for="scope in scopes" :key="scope.id" class="py-2">
            <template #prepend>
              <v-icon>{{ scope.is_default ? 'mdi-star' : 'mdi-vector-square-plus' }}</v-icon>
            </template>
            <v-list-item-title class="d-flex align-center ga-2">
              {{ scope.name }}
              <v-chip v-if="scope.is_default" size="x-small" color="primary" label>
                {{ t('profile.customScope.defaultBadge') }}
              </v-chip>
            </v-list-item-title>
            <v-list-item-subtitle class="text-wrap">
              {{ scope.regions.map(r => r.display_name || r.name).join('、') }}
            </v-list-item-subtitle>
            <template #append>
              <v-btn
                v-if="!scope.is_default"
                icon="mdi-star-outline" variant="text" size="small"
                :loading="settingDefaultId === scope.id"
                :title="t('profile.customScope.setDefault')"
                @click="setDefault(scope)"
              />
              <v-btn icon="mdi-pencil" variant="text" size="small" :title="t('common.edit')" @click="openEdit(scope)" />
              <v-btn icon="mdi-delete" variant="text" size="small" color="error" :title="t('common.delete')" @click="removeScope(scope)" />
            </template>
          </v-list-item>
        </v-list>
      </v-card-text>

      <!-- 表单视图 -->
      <v-card-text v-else>
        <v-text-field
          v-model="editing.name"
          :label="t('profile.customScope.nameLabel')"
          :placeholder="t('profile.customScope.namePlaceholder')"
          variant="outlined"
          density="compact"
          maxlength="100"
          counter
        />
        <div class="text-subtitle-2 mb-1">{{ t('profile.customScope.regionsLabel') }}</div>
        <RegionMultiSelect v-model="editing.regionIds" />
        <div v-if="formError" class="text-error text-caption mt-2">{{ formError }}</div>
      </v-card-text>

      <v-divider />
      <v-card-actions>
        <template v-if="!editing">
          <v-btn variant="tonal" prepend-icon="mdi-plus" :loading="loading" @click="openCreate">
            {{ t('profile.customScope.createTitle') }}
          </v-btn>
        </template>
        <template v-else>
          <v-btn variant="text" :disabled="saving" @click="editing = null">{{ t('common.cancel') }}</v-btn>
          <v-spacer />
          <v-btn color="primary" variant="text" :loading="saving" @click="saveEditing">{{ t('common.save') }}</v-btn>
        </template>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script setup lang="ts">
// 自定义计算范围管理对话框：列表（设为默认 / 编辑 / 删除）+ 新建/编辑表单。
// 变更后 emit('changed')，由父页面刷新用户配置与范围下拉选项。
import { ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { api } from '@/api'
import { useGlobalSnackbar } from '@/composables/useGlobalSnackbar'
import { useConfirmDialog } from '@/composables/useConfirmDialog'
import { useUserStore } from '@/stores/user'
import type { UserCalcScope } from '@/types'
import RegionMultiSelect from '@/components/common/RegionMultiSelect.vue'

const { t } = useI18n()
const { notify } = useGlobalSnackbar()
const { ask } = useConfirmDialog()
const userStore = useUserStore()

interface Props {
  modelValue: boolean
}
const props = defineProps<Props>()
const emit = defineEmits<{
  (e: 'update:modelValue', v: boolean): void
  (e: 'changed'): void
}>()

const scopes = ref<UserCalcScope[]>([])
const loading = ref(false)
const editing = ref<{ id: number | null; name: string; regionIds: number[] } | null>(null)
const saving = ref(false)
const settingDefaultId = ref<number | null>(null)
const formError = ref<string | null>(null)

async function loadScopes() {
  loading.value = true
  try {
    const list = await api.get('/calc-scopes')
    scopes.value = Array.isArray(list) ? list : []
  } catch (e: any) {
    notify(e?.userMessage || e?.message || t('errors.unknown'), 'error')
  } finally {
    loading.value = false
  }
}

watch(() => props.modelValue, (open) => {
  if (open) {
    editing.value = null
    void loadScopes()
  }
})

function close() {
  emit('update:modelValue', false)
  editing.value = null
}

function openCreate() {
  formError.value = null
  editing.value = { id: null, name: '', regionIds: [] }
}

function openEdit(scope: UserCalcScope) {
  formError.value = null
  editing.value = { id: scope.id, name: scope.name, regionIds: [...scope.region_ids] }
}

async function saveEditing() {
  if (!editing.value) return
  const name = editing.value.name.trim()
  if (!name) { formError.value = t('profile.customScope.nameRequired'); return }
  if (!editing.value.regionIds.length) { formError.value = t('profile.customScope.regionRequired'); return }
  saving.value = true
  formError.value = null
  try {
    const body = { name, region_ids: editing.value.regionIds }
    if (editing.value.id != null) {
      await api.put(`/calc-scopes/${editing.value.id}`, body)
    } else {
      await api.post('/calc-scopes', body)
    }
    editing.value = null
    await loadScopes()
    emit('changed')
    notify(t('profile.customScope.saved'), 'success')
  } catch (e: any) {
    formError.value = e?.response?.data?.detail || e?.userMessage || e?.message || t('errors.unknown')
  } finally {
    saving.value = false
  }
}

async function setDefault(scope: UserCalcScope) {
  settingDefaultId.value = scope.id
  try {
    await api.patch('/auth/me', { default_calc_scope_id: scope.id })
    await userStore.fetchUser()
    await loadScopes()
    emit('changed')
    notify(t('profile.customScope.defaultSet'), 'success')
  } catch (e: any) {
    notify(e?.response?.data?.detail || e?.userMessage || e?.message || t('errors.unknown'), 'error')
  } finally {
    settingDefaultId.value = null
  }
}

async function removeScope(scope: UserCalcScope) {
  const ok = await ask({
    title: t('profile.customScope.deleteTitle'),
    text: t('profile.customScope.deleteMessage', { name: scope.name }),
    color: 'error',
  })
  if (!ok) return
  try {
    await api.delete(`/calc-scopes/${scope.id}`)
    await userStore.fetchUser()
    await loadScopes()
    emit('changed')
    notify(t('profile.customScope.deleted'), 'success')
  } catch (e: any) {
    notify(e?.response?.data?.detail || e?.userMessage || e?.message || t('errors.unknown'), 'error')
  }
}
</script>
