<template>
  <v-snackbar v-model="show" :color="color" timeout="4000" location="top">
    {{ message }}
    <template #actions>
      <v-btn variant="text" @click="show = false">{{ t('actions.close') }}</v-btn>
    </template>
  </v-snackbar>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { useGlobalSnackbar } from '@/composables/useGlobalSnackbar'

const { t } = useI18n()

const { show, message, color } = useGlobalSnackbar()
</script>
