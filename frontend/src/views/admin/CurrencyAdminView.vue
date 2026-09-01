<template>
  <v-container fluid>
    <v-card elevation="0">
      <v-card-title class="d-flex align-center">
        <span class="mr-auto">{{ t('admin.currency.title') }}</span>
        <v-btn color="primary" prepend-icon="mdi-plus" @click="openCreateDialog">{{ t('admin.currency.create') }}</v-btn>
      </v-card-title>
      <v-card-text>
        <v-table>
          <thead>
            <tr>
              <th>{{ t('admin.currency.code') }}</th>
              <th>{{ t('admin.currency.name') }}</th>
              <th>{{ t('admin.currency.symbol') }}</th>
              <th>{{ t('admin.currency.decimals') }}</th>
              <th>{{ t('admin.currency.status') }}</th>
              <th>{{ t('admin.currency.actions') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="c in currencies" :key="c.code">
              <td>{{ c.code }}</td>
              <td>{{ c.name }}</td>
              <td>{{ c.symbol }}</td>
              <td>{{ formatCount(c.decimals) }}</td>
              <td>
                <div class="d-flex align-center ga-2">
                  <v-switch
                    :model-value="c.is_active"
                    color="success"
                    density="compact"
                    hide-details
                    :loading="togglingCode === c.code"
                    @update:model-value="(v) => toggleActive(c, Boolean(v))"
                  />
                  <span class="text-caption">{{ c.is_active ? t('admin.currency.enabled') : t('admin.currency.disabled') }}</span>
                </div>
              </td>
              <td>
                <v-btn
                  icon="mdi-delete"
                  size="small"
                  variant="text"
                  color="error"
                  :title="t('admin.currency.disable')"
                  @click="openDeleteDialog(c)"
                />
              </td>
            </tr>
          </tbody>
        </v-table>
      </v-card-text>
    </v-card>

    <!-- 新增币种对话框 -->
    <v-dialog v-model="createDialog" max-width="480px" persistent>
      <v-card>
        <v-card-title>{{ t('admin.currency.create') }}</v-card-title>
        <v-card-text>
          <v-form @submit.prevent="submitCreate">
            <v-text-field
              v-model="form.code"
              :label="t('admin.currency.codeLabel')"
              counter
              required
              :hint="t('admin.currency.codeHint')"
              @input="form.code = form.code.toUpperCase()"
            />
            <v-text-field v-model="form.name" :label="t('admin.currency.name')" required />
            <v-text-field v-model="form.symbol" :label="t('admin.currency.symbol')" :hint="t('admin.currency.symbolHint')" />
            <v-text-field v-model="form.decimals" :label="t('admin.currency.decimals')" type="number" min="0" max="4" />
          </v-form>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="createDialog = false">{{ t('actions.cancel') }}</v-btn>
          <v-btn color="primary" :loading="saving" @click="submitCreate">{{ t('actions.save') }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- 删除（停用）确认对话框 -->
    <v-dialog v-model="deleteDialog" max-width="420px" persistent>
      <v-card>
        <v-card-title>{{ t('admin.currency.disableTitle') }}</v-card-title>
        <v-card-text>
          {{ t('admin.currency.disableConfirm', { code: deleteTarget?.code ?? '' }) }}
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="deleteDialog = false">{{ t('actions.cancel') }}</v-btn>
          <v-btn color="error" :loading="deleting" @click="confirmDelete">{{ t('admin.currency.disable') }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { formatNumber } from '@/utils/format'
import { useLocaleStore } from '@/stores/locale'
import {
  listAdminCurrencies,
  createCurrency,
  updateCurrency,
  deleteCurrency,
} from '@/api/currencies'
import { useGlobalSnackbar } from '@/composables/useGlobalSnackbar'

const { notify } = useGlobalSnackbar()
const { t } = useI18n()
const localeStore = useLocaleStore()
const formatCount = (value: number) => formatNumber(value, localeStore.effectiveFormatLocale)

const currencies = ref<any[]>([])
const loading = ref(false)

const createDialog = ref(false)
const saving = ref(false)
const form = reactive({ code: '', name: '', symbol: '', decimals: 2 })

const deleteDialog = ref(false)
const deleting = ref(false)
const deleteTarget = ref<any>(null)
const togglingCode = ref('')

async function fetchCurrencies() {
  loading.value = true
  try {
    currencies.value = await listAdminCurrencies()
  } catch (e: any) {
    notify(e?.userMessage || t('admin.currency.loadFailed'), 'error')
  } finally {
    loading.value = false
  }
}

function openCreateDialog() {
  form.code = ''
  form.name = ''
  form.symbol = ''
  form.decimals = 2
  createDialog.value = true
}

async function submitCreate() {
  const code = form.code.trim()
  const name = form.name.trim()
  if (!code || !name) {
    notify(t('admin.currency.codeNameRequired'), 'warning')
    return
  }
  if (!/^[A-Z]{3}$/.test(code)) {
    notify(t('admin.currency.codeInvalid'), 'warning')
    return
  }
  saving.value = true
  try {
    await createCurrency({
      code,
      name,
      symbol: form.symbol.trim() || null,
      decimals: Number(form.decimals) || 2,
    })
    createDialog.value = false
    notify(t('admin.currency.saved'), 'success')
    await fetchCurrencies()
  } catch (e: any) {
    notify(e?.userMessage || t('errors.unknown'), 'error')
  } finally {
    saving.value = false
  }
}

async function toggleActive(c: any, value: boolean) {
  togglingCode.value = c.code
  try {
    await updateCurrency(c.code, { is_active: value })
    c.is_active = value
    notify(value ? t('admin.currency.enabledCode', { code: c.code }) : t('admin.currency.disabledCode', { code: c.code }), 'success')
  } catch (e: any) {
    notify(e?.userMessage || t('admin.currency.operationFailed'), 'error')
  } finally {
    togglingCode.value = ''
  }
}

function openDeleteDialog(c: any) {
  deleteTarget.value = c
  deleteDialog.value = true
}

async function confirmDelete() {
  if (!deleteTarget.value) return
  deleting.value = true
  try {
    await deleteCurrency(deleteTarget.value.code)
    const code = deleteTarget.value.code
    deleteDialog.value = false
    notify(t('admin.currency.disabledCode', { code }), 'success')
    await fetchCurrencies()
  } catch (e: any) {
    notify(e?.userMessage || t('admin.currency.disableFailed'), 'error')
  } finally {
    deleting.value = false
  }
}

onMounted(fetchCurrencies)
</script>
