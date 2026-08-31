<template>
  <v-text-field
    :model-value="modelValue"
    :label="label"
    :loading="loading"
    :variant="variant"
    :density="density"
    @update:model-value="value => emit('update:modelValue', String(value ?? ''))"
    @keydown.enter.prevent="submit"
  >
    <template #append-inner>
      <v-btn
        icon="mdi-barcode-scan"
        variant="text"
        :aria-label="t('common.scanBarcode')"
        @click="scannerOpen = true"
      />
    </template>
  </v-text-field>
  <BarcodeScannerDialog
    v-model="scannerOpen"
    @detected="onDetected"
  />
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { t as translate } from '@/plugins/i18n'
import BarcodeScannerDialog from './BarcodeScannerDialog.vue'

const { t } = useI18n()

const props = withDefaults(defineProps<{
  modelValue: string
  label?: string
  loading?: boolean
  variant?: 'outlined' | 'underlined' | 'plain'
  density?: 'default' | 'comfortable' | 'compact'
}>(), {
  label: translate('common.barcode'),
  loading: false,
  variant: 'outlined',
  density: 'default',
})

const emit = defineEmits<{
  'update:modelValue': [value: string]
  barcode: [value: string]
}>()

const scannerOpen = ref(false)

function submit() {
  const code = props.modelValue.trim()
  if (!code) return
  emit('barcode', code)
}

function onDetected(code: string) {
  emit('update:modelValue', code)
  emit('barcode', code)
}
</script>
