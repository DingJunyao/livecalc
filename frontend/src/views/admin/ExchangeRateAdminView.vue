<template>
  <v-container fluid>
    <v-card elevation="0">
      <v-card-title class="d-flex align-center">
        <span class="mr-auto">{{ t('admin.exchange.title') }}</span>
        <v-btn color="primary" prepend-icon="mdi-pencil-plus-outline" @click="openManualDialog">
          {{ t('admin.exchange.manualEntry') }}
        </v-btn>
      </v-card-title>
      <v-card-text>
        <v-alert type="info" variant="tonal" class="mb-4">
          {{ t('admin.exchange.latestSnapshot', {
            time: status.latest ? formatToLocalDateTimeShort(status.latest) : t('statuses.none'),
            source: status.source || '-',
          }) }}
        </v-alert>
        <v-btn color="primary" :loading="loading" @click="onRefresh">{{ t('admin.exchange.refreshNow') }}</v-btn>
      </v-card-text>
    </v-card>

    <!-- 手动补汇率对话框 -->
    <v-dialog v-model="manualDialog" max-width="520px" persistent>
      <v-card>
        <v-card-title>{{ t('admin.exchange.manualEntry') }}</v-card-title>
        <v-card-text>
          <v-form @submit.prevent="submitManual">
            <v-text-field
              v-model="form.rate_date"
              :label="t('admin.exchange.date')"
              type="date"
              required
            />
            <v-text-field
              v-model="form.base_currency"
              :label="t('admin.exchange.baseCurrencyLabel')"
              counter
              required
              :hint="t('admin.exchange.baseCurrencyHint')"
              @input="form.base_currency = form.base_currency.toUpperCase()"
            />
            <v-textarea
              v-model="form.ratesText"
              :label="t('admin.exchange.ratesLabel')"
              rows="6"
              :hint="t('admin.exchange.ratesHint')"
              persistent-hint
              required
            />
          </v-form>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="manualDialog = false">{{ t('actions.cancel') }}</v-btn>
          <v-btn color="primary" :loading="manualSaving" @click="submitManual">{{ t('admin.exchange.submit') }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { ratesStatus, refreshRates, manualRate } from '@/api/currencies'
import { useGlobalSnackbar } from '@/composables/useGlobalSnackbar'
import { formatToLocalDateTimeShort } from '@/utils/timezone'

const { notify } = useGlobalSnackbar()
const { t } = useI18n()

const status = ref<{ latest: string | null; source: string | null }>({ latest: null, source: null })
const loading = ref(false)

const manualDialog = ref(false)
const manualSaving = ref(false)
const form = reactive({ rate_date: '', base_currency: '', ratesText: '' })

onMounted(loadStatus)

async function loadStatus() {
  try {
    status.value = await ratesStatus()
  } catch (e: any) {
    notify(e?.userMessage || t('admin.exchange.loadStatusFailed'), 'error')
  }
}

async function onRefresh() {
  loading.value = true
  try {
    await refreshRates()
    await loadStatus()
    notify(t('admin.exchange.refreshed'), 'success')
  } catch (e: any) {
    notify(e?.userMessage || t('admin.exchange.refreshFailed'), 'error')
  } finally {
    loading.value = false
  }
}

function openManualDialog() {
  form.rate_date = new Date().toISOString().slice(0, 10)
  form.base_currency = ''
  form.ratesText = ''
  manualDialog.value = true
}

function parseRates(text: string): Record<string, number> {
  const rates: Record<string, number> = {}
  const lines = text.split(/\r?\n/)
  for (const line of lines) {
    const trimmed = line.trim()
    if (!trimmed) continue
    const parts = trimmed.split(/[\s:=]+/)
    if (parts.length < 2) throw new Error(t('admin.exchange.parseLineFailed', { line: trimmed }))
    const code = parts[0].toUpperCase()
    const value = Number(parts[1])
    if (!/^[A-Z]{3}$/.test(code) || Number.isNaN(value)) {
      throw new Error(t('admin.exchange.parseLineFailed', { line: trimmed }))
    }
    rates[code] = value
  }
  if (Object.keys(rates).length === 0) throw new Error(t('admin.exchange.ratesRequired'))
  return rates
}

async function submitManual() {
  if (!form.rate_date) {
    notify(t('admin.exchange.dateRequired'), 'warning')
    return
  }
  const base = form.base_currency.trim()
  if (!/^[A-Z]{3}$/.test(base)) {
    notify(t('admin.exchange.baseCurrencyInvalid'), 'warning')
    return
  }
  let rates: Record<string, number>
  try {
    rates = parseRates(form.ratesText)
  } catch (e: any) {
    notify(e?.message || t('admin.exchange.ratesInvalid'), 'warning')
    return
  }
  manualSaving.value = true
  try {
    await manualRate({ rate_date: form.rate_date, base_currency: base, rates })
    manualDialog.value = false
    notify(t('admin.exchange.manualSaved'), 'success')
    await loadStatus()
  } catch (e: any) {
    notify(e?.userMessage || t('admin.exchange.submitFailed'), 'error')
  } finally {
    manualSaving.value = false
  }
}
</script>
