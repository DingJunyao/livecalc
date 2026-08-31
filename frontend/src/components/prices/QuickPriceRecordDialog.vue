<template>
  <v-dialog v-model="show" max-width="500" persistent>
    <v-card>
      <v-card-title>{{ t('prices.recordPrice') }}{{ displayProductName ? ' - ' + displayProductName : '' }}</v-card-title>
      <v-card-text>
        <v-form ref="formRef" v-model="formValid">
          <!-- 商家（必填，置于商品前） -->
          <v-autocomplete
            v-model="form.merchant_id"
            :items="merchantOptions"
            :item-title="(item: any) => item.display_name || item.name"
            item-value="id"
            :label="t('prices.merchantRequired')"
            variant="outlined"
            :rules="[(v: any) => !!v || t('prices.chooseMerchant')]"
            class="mb-4"
            @update:model-value="onMerchantChange"
          />

          <!-- 商品选择（原料页使用） -->
          <v-select
            v-if="products && products.length > 0"
            v-model="selectedProductId"
            :items="products"
            :item-title="(item: any) => item.display_name || item.name"
            item-value="id"
            :label="t('prices.product')"
            variant="outlined"
            :rules="[(v: any) => !!v || t('prices.chooseProduct')]"
            class="mb-4"
          />

          <!-- 价格（币种在价格右侧，显示三字母） -->
          <div class="d-flex align-center ga-2 mb-4">
            <v-text-field
              v-model.number="form.price"
              :label="t('prices.priceWithoutStar')"
              variant="outlined"
              type="number"
              :rules="priceRules"
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

          <v-row>
            <v-col cols="6">
              <v-text-field
                v-model.number="form.original_quantity"
                :label="t('prices.quantity')"
                variant="outlined"
                type="number"
                :rules="quantityRules"
              />
            </v-col>
            <v-col cols="6">
              <v-select
                v-model="form.original_unit"
                :items="unitOptions"
                :label="t('prices.unit')"
                variant="outlined"
                :rules="unitRules"
              />
            </v-col>
          </v-row>

          <v-checkbox
            v-model="form.is_purchase"
            :label="t('prices.countExpense')"
            color="primary"
            density="comfortable"
            class="mb-4"
          >
            <template #append>
              <v-tooltip location="top">
                <template #activator="{ props: tooltipProps }">
                  <v-icon v-bind="tooltipProps" size="small" color="grey">mdi-help-circle</v-icon>
                </template>
                <span>{{ t('prices.countExpenseTooltip') }}</span>
              </v-tooltip>
            </template>
          </v-checkbox>

          <v-text-field
            v-model="form.recorded_at"
            :label="t('prices.recordedAtOptional')"
            variant="outlined"
            type="datetime-local"
            class="mb-4"
          />

          <v-textarea
            v-model="form.notes"
            :label="t('prices.notesOptional')"
            variant="outlined"
            rows="2"
          />
        </v-form>
      </v-card-text>
      <v-alert v-if="saveError" type="error" variant="tonal" class="mx-4 mb-2" closable @click:close="saveError = ''">
        {{ saveError }}
      </v-alert>
      <v-card-actions>
        <v-spacer />
        <v-btn @click="close">{{ t('prices.cancel') }}</v-btn>
        <v-btn color="primary" :loading="saving" :disabled="!formValid" @click="save">{{ t('prices.add') }}</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { useUserUnits } from '@/composables/useUserUnits'
const { priceUnitName } = useUserUnits()
import { ref, computed, watch, nextTick } from 'vue'
import { api } from '@/api'
import { getErrorMessage } from '@/utils/errorHandler'
import { getLocalDateTimeString, formatToLocalDateTimeShort } from '@/utils/timezone'
import { loadCurrencies } from '@/utils/currency'

const { t } = useI18n()

interface Merchant {
  id: number
  name: string
  default_currency?: string | null
  effective_currency?: string | null
}

interface ProductOption {
  id: number
  name: string
}

const props = defineProps<{
  modelValue: boolean
  productId: number | null
  productName: string
  defaultUnit?: string
  products?: ProductOption[]
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'saved'): void
}>()

const show = ref(false)
const saving = ref(false)
const saveError = ref('')
const formRef = ref()
const formValid = ref(false)
const merchantOptions = ref<Merchant[]>([])
const currencies = ref<any[]>([])
const recordCurrency = ref<string>('CNY')

// 商品选择（原料页使用）
const selectedProductId = ref<number | null>(null)

const displayProductName = computed(() => {
  if (props.products && props.products.length > 0) {
    return props.products.find(p => p.id === selectedProductId.value)?.name || ''
  }
  return props.productName
})

const form = ref({
  price: null as number | null,
  original_quantity: 1 as number,
  original_unit: priceUnitName.value,
  merchant_id: null as number | null,
  recorded_at: '',
  notes: '',
  is_purchase: true,
})

// 单位选项（从 API 动态加载）
const unitOptions = ref<{ title: string; value: string }[]>([])

// 基本单位列表（API 加载失败时的回退）
const FALLBACK_UNITS = [
  { title: '克', value: 'g' },
  { title: '千克', value: 'kg' },
  { title: '斤', value: '斤' },
  { title: '两', value: '两' },
  { title: '毫升', value: 'ml' },
  { title: '升', value: 'L' },
  { title: '个', value: '个' },
]

// 加载全局单位列表
const loadUnits = async () => {
  try {
    const res = await api.get('/units/', { params: { limit: 100 } })
    const units = res.items || res || []
    unitOptions.value = units.map((u: any) => ({
      title: `${u.name} (${u.abbreviation})`,
      value: u.abbreviation,
    }))
  } catch (e) {
    // 回退到基本单位列表
    unitOptions.value = [...FALLBACK_UNITS]
  }
}

// 加载实体自定义单位（商品选择后追加）
const loadEntityUnits = async (productId: number) => {
  try {
    const res = await api.get(`/entities/product/${productId}/units`)
    const entityUnits = (res.items || res || []).map((eu: any) => ({
      title: eu.unit_name,
      value: eu.unit_name,
    }))
    // 追加到全局单位列表前面（实体单位优先），避免重复
    const existingValues = new Set(unitOptions.value.map(u => u.value))
    const newOptions = entityUnits.filter((u: { title: string; value: string }) => !existingValues.has(u.value))
    if (newOptions.length > 0) {
      unitOptions.value = [...newOptions, ...unitOptions.value]
    }
  } catch (e) {
    // 实体单位加载失败不影响全局单位
  }
}

const priceRules = [(v: number | null) => v !== null && v > 0 || t('prices.validPrice')]
const quantityRules = [(v: number | null) => v !== null && v > 0 || t('prices.validQuantity')]
const unitRules = [(v: string) => !!v || t('prices.chooseUnit')]

const SESSION_KEYS = {
  MERCHANT_ID: 'price_form_merchant_id',
  IS_PURCHASE: 'price_form_is_purchase',
} as const

const loadSessionMemory = () => {
  const savedMerchantId = sessionStorage.getItem(SESSION_KEYS.MERCHANT_ID)
  const savedIsPurchase = sessionStorage.getItem(SESSION_KEYS.IS_PURCHASE)
  return {
    merchantId: savedMerchantId ? parseInt(savedMerchantId, 10) : null,
    isPurchase: savedIsPurchase ? savedIsPurchase === 'true' : true,
  }
}

const saveSessionMemory = () => {
  if (form.value.merchant_id !== null && form.value.merchant_id !== undefined) {
    sessionStorage.setItem(SESSION_KEYS.MERCHANT_ID, form.value.merchant_id.toString())
  }
  sessionStorage.setItem(SESSION_KEYS.IS_PURCHASE, String(form.value.is_purchase))
}

const loadMerchants = async () => {
  try {
    const response = await api.get('/merchants', { params: { limit: 100 } })
    merchantOptions.value = response.items || []
    await applyMerchantCurrency(form.value.merchant_id)
  } catch (e: any) {
    console.error('加载商家失败', e)
  }
}

const applyMerchantCurrency = (merchantId: number | null) => {
  const m = merchantOptions.value.find((x) => x.id === merchantId)
  recordCurrency.value = m?.default_currency || m?.effective_currency || 'CNY'
}

const onMerchantChange = (val: number | null) => {
  applyMerchantCurrency(val)
}

const resetForm = () => {
  const sessionMemory = loadSessionMemory()
  selectedProductId.value = props.productId
  form.value = {
    price: null,
    original_quantity: 1,
    original_unit: props.defaultUnit || priceUnitName.value,
    merchant_id: sessionMemory.merchantId,
    recorded_at: getLocalDateTimeString(),
    notes: '',
    is_purchase: sessionMemory.isPurchase,
  }
  recordCurrency.value = 'CNY'
  nextTick(() => formRef.value?.resetValidation())
}

watch(() => props.modelValue, (val) => {
  show.value = val
  if (val) {
    resetForm()
    loadMerchants()
    loadCurrencies().then((list) => { currencies.value = list }).catch(() => {})
    loadUnits().then(() => {
      // 非列表模式下，直接加载 props.productId 对应的实体单位
      if (!props.products?.length && props.productId) {
        loadEntityUnits(props.productId)
      }
    })
  }
})

watch(show, (val) => {
  emit('update:modelValue', val)
})

// 监听商品选择，加载实体自定义单位
watch(selectedProductId, (newId) => {
  if (newId) {
    loadEntityUnits(newId)
  }
})

const close = () => {
  show.value = false
  saveError.value = ''
}

const save = async () => {
  if (!formRef.value?.validate()) return

  const productId = props.products ? selectedProductId.value : props.productId
  if (!productId) return

  saving.value = true
  try {
    const data: Record<string, any> = {
      product_id: productId,
      price: form.value.price,
      original_quantity: form.value.original_quantity,
      original_unit: form.value.original_unit,
      merchant_id: form.value.merchant_id,
      currency: recordCurrency.value,
      notes: form.value.notes || null,
      record_type: form.value.is_purchase ? 'purchase' : 'price',
    }

    if (form.value.recorded_at) {
      data.recorded_at = new Date(form.value.recorded_at).toISOString()
    }

    await api.post('/products', data)
    saveSessionMemory()
    close()
    emit('saved')
  } catch (e: any) {
    console.error('保存记录失败', e)
    saveError.value = getErrorMessage(e, t('prices.saveFailed'))
  } finally {
    saving.value = false
  }
}
</script>
