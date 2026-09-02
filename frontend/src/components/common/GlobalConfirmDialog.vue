<template>
  <v-dialog v-model="visible" max-width="420">
    <v-card>
      <v-card-title class="d-flex align-center">
        <v-icon v-if="options.color === 'error'" class="me-2" color="error">mdi-alert-circle-outline</v-icon>
        {{ options.title || t('common.confirmTitle') }}
      </v-card-title>
      <v-card-text class="text-body-1" style="white-space: pre-line;">{{ options.text }}</v-card-text>
      <v-card-actions>
        <v-spacer />
        <v-btn variant="text" @click="answer(false)">{{ options.cancelText || t('actions.cancel') }}</v-btn>
        <v-btn :color="options.color || 'primary'" variant="tonal" @click="answer(true)">{{ options.confirmText || t('common.confirm') }}</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { useConfirmDialog } from '@/composables/useConfirmDialog'

const { t } = useI18n()

const { visible, options, answer } = useConfirmDialog()
</script>
