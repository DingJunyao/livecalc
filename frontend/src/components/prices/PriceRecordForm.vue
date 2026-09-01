<template>
  <v-dialog
    :model-value="modelValue"
    max-width="500"
    class="price-form-dialog"
    @update:model-value="$emit('update:modelValue', $event)"
  >
    <v-card>
      <v-card-title class="d-flex align-center pa-4">
        <v-btn icon="mdi-arrow-left" variant="text" @click="close" />
        <span class="text-h6 ml-2">{{ isEdit ? t('prices.editRecord') : t('prices.addRecord') }}</span>
        <v-spacer />
        <v-btn
          color="primary"
          variant="text"
          :loading="saving"
          @click="save"
        >
          {{ t('prices.save') }}
        </v-btn>
      </v-card-title>

      <v-card-text class="pa-4">
        <v-form ref="formRef">
          <!-- 商家（必填，置于商品前） -->
          <v-autocomplete
            v-model="form.merchant_id"
            :items="merchants"
            :item-title="(item: any) => item.display_name || item.name"
            item-value="id"
            :label="t('prices.merchantRequired')"
            prepend-inner-icon="mdi-store"
            variant="outlined"
            required
            :rules="[rules.required]"
            class="mb-4"
            @update:model-value="onMerchantChange"
          />

          <!-- 商品选择 -->
          <v-text-field
            v-model="form.product_name"
            :label="t('prices.productName')"
            prepend-inner-icon="mdi-magnify"
            variant="outlined"
            required
            :rules="[rules.required]"
            class="mb-4"
          />

          <!-- 价格（币种在价格右侧，显示三字母） -->
          <div class="d-flex align-center ga-2 mb-4">
            <v-text-field
              v-model="form.price"
              :label="t('prices.price')"
              type="number"
              variant="outlined"
              required
              :rules="[rules.required]"
              class="flex-grow-1"
            />
            <v-menu :close-on-content-click="true" location="bottom">
              <template #activator="{ props: menuProps }">
                <v-btn variant="text" size="x-small" class="pa-0" v-bind="menuProps" :aria-label="t('prices.selectCurrency')">{{ recordCurrency }}</v-btn>
              </template>
              <v-list density="compact">
                <v-list-item
                  v-for="c in currencies"
                  :key="c.code"
                  :title="`${c.display_name || c.name} ${c.code}`"
                  :active="recordCurrency === c.code"
                  @click="recordCurrency = c.code"
                />
              </v-list>
            </v-menu>
          </div>

          <!-- 数量和单位 -->
          <v-row class="mb-4">
            <v-col cols="6">
              <v-text-field
                v-model="form.quantity"
                :label="t('prices.quantity') + ' *'"
                type="number"
                variant="outlined"
                required
                :rules="[rules.required]"
              />
            </v-col>
            <v-col cols="6">
              <v-select
                v-model="form.unit"
                :label="t('prices.unit') + ' *'"
                :items="units"
                variant="outlined"
                required
              />
            </v-col>
          </v-row>

          <!-- 计入支出 -->
          <v-checkbox
            v-model="form.is_purchase"
            :label="t('prices.countExpense')"
            color="primary"
            density="comfortable"
            class="mb-4"
          />

          <!-- 记录时间 -->
          <v-text-field
            v-model="form.record_date"
            :label="t('prices.recordedAt')"
            prepend-inner-icon="mdi-calendar"
            type="date"
            variant="outlined"
          />
        </v-form>
      </v-card-text>

      <!-- 桌面端底部操作按钮 -->
      <v-card-actions class="pa-4 pt-0 d-none d-md-flex">
        <v-spacer />
        <v-btn variant="text" @click="close">{{ t('prices.cancel') }}</v-btn>
        <v-btn
          color="primary"
          variant="elevated"
          :loading="saving"
          @click="save"
        >
          {{ t('prices.save') }}
        </v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { useUserUnits } from '@/composables/useUserUnits'
const { priceUnitName } = useUserUnits()
import { ref, reactive, watch, computed, onMounted } from 'vue'
import { api } from '@/api'
import type { PriceRecord } from '@/types'
import { getLocalDateString } from '@/utils/timezone'
import { loadCurrencies } from '@/utils/currency'
import { FALLBACK_PRICE_UNIT_VALUES } from '@/data/localValues'

const { t } = useI18n()

interface Props {
  modelValue: boolean
  record?: PriceRecord
}

interface Emits {
  (e: 'update:modelValue', value: boolean): void
  (e: 'save', record: PriceRecord): void
}

const props = defineProps<Props>()
const emit = defineEmits<Emits>()

const isEdit = computed(() => !!props.record)

const form = reactive({
  product_name: '',
  price: '',
  quantity: 1,
  unit: priceUnitName.value,
  merchant_name: '',
  merchant_id: null as number | null,
  is_purchase: true,
  record_date: getLocalDateString(),
})

const merchants = ref<{ id: number; name: string; default_currency?: string | null; effective_currency?: string | null }[]>([])
const currencies = ref<any[]>([])
const recordCurrency = ref<string>('CNY')
const formRef = ref()

// 单位选项（从 API 动态加载）
const units = ref<string[]>([])

// 基本单位列表（API 加载失败时的回退）
const FALLBACK_UNITS = FALLBACK_PRICE_UNIT_VALUES

// 加载全局单位列表
const loadUnits = async () => {
  try {
    const res = await api.get('/units/', { params: { limit: 100 } })
    const unitList = res.items || res || []
    units.value = unitList.map((u: any) => u.abbreviation)
  } catch (e) {
    units.value = [...FALLBACK_UNITS]
  }
}

const loadMerchants = async () => {
  try {
    const res = await api.get('/merchants', { params: { limit: 100 } })
    merchants.value = (res as any).items || []
  } catch {
    merchants.value = []
  }
}

const applyCurrency = (code: string) => {
  recordCurrency.value = code || 'CNY'
}

const onMerchantChange = async (val: number | null) => {
  const m = merchants.value.find((x) => x.id === val)
  form.merchant_name = m?.name || ''
  await applyCurrency(m?.default_currency || m?.effective_currency || 'CNY')
}

onMounted(() => {
  loadUnits()
  loadMerchants()
  loadCurrencies().then((list) => { currencies.value = list }).catch(() => {})
})

const saving = ref(false)

const rules = {
  required: (value: any) => !!value || t('prices.fieldRequired'),
}

// 监听 record 变化，填充表单
watch(() => props.record, (newRecord) => {
  if (newRecord) {
    form.product_name = newRecord.product_name
    form.price = newRecord.price.toString()
    form.quantity = newRecord.quantity
    form.unit = newRecord.unit
    form.merchant_name = newRecord.merchant_name || ''
    form.merchant_id = newRecord.merchant_id ?? null
    void applyCurrency(newRecord.currency || 'CNY')
    form.is_purchase = true
    form.record_date = newRecord.record_date.split('T')[0]
  } else {
    resetForm()
  }
}, { immediate: true })

const resetForm = () => {
  form.product_name = ''
  form.price = ''
  form.quantity = 1
  form.unit = priceUnitName.value
  form.merchant_name = ''
  form.merchant_id = null
  form.is_purchase = true
  recordCurrency.value = 'CNY'
  form.record_date = getLocalDateString()
}

const close = () => {
  emit('update:modelValue', false)
  resetForm()
}

const save = async () => {
  if (formRef.value) {
    const { valid } = await formRef.value.validate()
    if (!valid) return
  }
  const record: PriceRecord = {
    id: props.record?.id || Date.now(),
    product_name: form.product_name,
    price: parseFloat(form.price),
    quantity: form.quantity,
    unit: form.unit,
    merchant_name: form.merchant_name || undefined,
    record_date: new Date(form.record_date).toISOString(),
    created_at: props.record?.created_at || new Date().toISOString(),
    currency: recordCurrency.value,
    exchange_rate: props.record?.exchange_rate ?? 1,
    user_currency: props.record?.user_currency || 'CNY',
    merchant_id: form.merchant_id ?? null,
  }

  emit('save', record)
  close()
}
</script>

<style>
/* 移动端全屏显示对话框 */
@media (max-width: 959px) {
  .price-form-dialog .v-overlay__content {
    max-width: 100% !important;
    width: 100% !important;
    height: 100% !important;
    max-height: 100% !important;
    margin: 0 !important;
  }

  .price-form-dialog .v-card {
    height: 100%;
    border-radius: 0;
  }
}
</style>
