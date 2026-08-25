<template>
  <v-container fluid>
    <v-card elevation="0">
      <v-card-title class="d-flex align-center">
        <span class="mr-auto">汇率管理</span>
        <v-btn color="primary" prepend-icon="mdi-pencil-plus-outline" @click="openManualDialog">
          手动补汇率
        </v-btn>
      </v-card-title>
      <v-card-text>
        <v-alert type="info" variant="tonal" class="mb-4">
          最新快照：{{ status.latest || '暂无' }}（{{ status.source || '-' }}）
        </v-alert>
        <v-btn color="primary" :loading="loading" @click="onRefresh">立即刷新</v-btn>
      </v-card-text>
    </v-card>

    <!-- 手动补汇率对话框 -->
    <v-dialog v-model="manualDialog" max-width="520px" persistent>
      <v-card>
        <v-card-title>手动补汇率</v-card-title>
        <v-card-text>
          <v-form @submit.prevent="submitManual">
            <v-text-field
              v-model="form.rate_date"
              label="日期"
              type="date"
              required
            />
            <v-text-field
              v-model="form.base_currency"
              label="基准币种（3 位大写字母）"
              counter
              required
              hint="如 EUR / CNY"
              @input="form.base_currency = form.base_currency.toUpperCase()"
            />
            <v-textarea
              v-model="form.ratesText"
              label="汇率（每行一个：币种代码 + 数值）"
              rows="6"
              hint="格式：USD 1.1（也支持 USD:1.1 / USD=1.1）"
              persistent-hint
              required
            />
          </v-form>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="manualDialog = false">取消</v-btn>
          <v-btn color="primary" :loading="manualSaving" @click="submitManual">提交</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { ratesStatus, refreshRates, manualRate } from '@/api/currencies'
import { useGlobalSnackbar } from '@/composables/useGlobalSnackbar'

const { notify } = useGlobalSnackbar()

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
    notify(e?.userMessage || '获取汇率状态失败', 'error')
  }
}

async function onRefresh() {
  loading.value = true
  try {
    await refreshRates()
    await loadStatus()
    notify('汇率已刷新', 'success')
  } catch (e: any) {
    notify(e?.userMessage || '刷新失败', 'error')
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
    if (parts.length < 2) throw new Error(`无法解析行：${trimmed}`)
    const code = parts[0].toUpperCase()
    const value = Number(parts[1])
    if (!/^[A-Z]{3}$/.test(code) || Number.isNaN(value)) {
      throw new Error(`无法解析行：${trimmed}`)
    }
    rates[code] = value
  }
  if (Object.keys(rates).length === 0) throw new Error('请至少填写一条汇率')
  return rates
}

async function submitManual() {
  if (!form.rate_date) {
    notify('请选择日期', 'warning')
    return
  }
  const base = form.base_currency.trim()
  if (!/^[A-Z]{3}$/.test(base)) {
    notify('基准币种需为 3 位大写字母', 'warning')
    return
  }
  let rates: Record<string, number>
  try {
    rates = parseRates(form.ratesText)
  } catch (e: any) {
    notify(e?.message || '汇率格式错误', 'warning')
    return
  }
  manualSaving.value = true
  try {
    await manualRate({ rate_date: form.rate_date, base_currency: base, rates })
    manualDialog.value = false
    notify('汇率已手动写入', 'success')
    await loadStatus()
  } catch (e: any) {
    notify(e?.userMessage || '提交失败', 'error')
  } finally {
    manualSaving.value = false
  }
}
</script>
