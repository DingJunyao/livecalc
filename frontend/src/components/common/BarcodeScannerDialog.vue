<template>
  <v-dialog
    :model-value="modelValue"
    max-width="520"
    persistent
    @update:model-value="close"
  >
    <v-card>
      <v-card-title class="d-flex align-center">
        {{ t('common.scanBarcodeTitle') }}
        <v-spacer />
        <v-btn icon="mdi-close" variant="text" :aria-label="t('common.closeScanner')" @click="close" />
      </v-card-title>
      <v-card-text>
        <v-alert v-if="error" type="error" density="compact" class="mb-3">
          {{ error }}
        </v-alert>
        <div class="scanner-frame">
          <video ref="video" class="scanner-video" playsinline muted />
        </div>
      </v-card-text>
    </v-card>
  </v-dialog>
</template>

<script setup lang="ts">
import { nextTick, onBeforeUnmount, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import {
  BarcodeFormat,
  BrowserMultiFormatReader,
  type IScannerControls,
} from '@zxing/browser'

const props = defineProps<{ modelValue: boolean }>()
const { t } = useI18n()
const emit = defineEmits<{
  'update:modelValue': [value: boolean]
  detected: [code: string]
}>()

const video = ref<HTMLVideoElement>()
const error = ref('')
let reader: BrowserMultiFormatReader | null = null
let controls: IScannerControls | null = null

async function start() {
  error.value = ''
  await nextTick()
  if (!video.value) return

  reader = new BrowserMultiFormatReader()
  reader.possibleFormats = [
    BarcodeFormat.EAN_13,
    BarcodeFormat.EAN_8,
    BarcodeFormat.UPC_A,
    BarcodeFormat.UPC_E,
    BarcodeFormat.CODE_128,
    BarcodeFormat.CODE_39,
    BarcodeFormat.CODE_93,
    BarcodeFormat.ITF,
    BarcodeFormat.CODABAR,
  ]
  try {
    controls = await reader.decodeFromVideoDevice(undefined, video.value, (result) => {
      const code = result?.getText()?.trim()
      if (!code) return
      emit('detected', code)
      close()
    })
  } catch (e: any) {
    error.value = e?.name === 'NotAllowedError'
      ? t('common.cameraNotAuthorized')
      : e?.message || t('common.cameraStartFailed')
  }
}

function stopCamera() {
  controls?.stop()
  controls = null
  const stream = video.value?.srcObject as MediaStream | null
  stream?.getTracks().forEach((track) => track.stop())
  if (video.value) video.value.srcObject = null
  reader = null
}

function close() {
  stopCamera()
  emit('update:modelValue', false)
}

watch(
  () => props.modelValue,
  (open, was) => {
    if (open) void start()
    else if (was) stopCamera()
  },
  { immediate: true },
)

onBeforeUnmount(stopCamera)
</script>

<style scoped>
.scanner-frame {
  overflow: hidden;
  border-radius: 8px;
  background: rgb(0 0 0 / 80%);
  aspect-ratio: 4 / 3;
}

.scanner-video {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
</style>
