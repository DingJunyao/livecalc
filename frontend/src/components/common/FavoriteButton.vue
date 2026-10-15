<template>
  <v-btn
    :icon="active ? 'mdi-heart' : 'mdi-heart-outline'"
    :size="size"
    variant="text"
    :color="active ? 'error' : undefined"
    :title="active ? t('favorites.unfavorite') : t('favorites.favorite')"
    :aria-label="active ? t('favorites.unfavorite') : t('favorites.favorite')"
    @click.stop.prevent="$emit('toggle')"
  />
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'

withDefaults(defineProps<{ active: boolean; size?: 'x-small' | 'small' | 'default' | 'large' }>(), {
  size: 'small',
})
defineEmits<{ (e: 'toggle'): void }>()

const { t } = useI18n()
</script>
