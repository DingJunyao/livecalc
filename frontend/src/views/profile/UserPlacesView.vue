<template>
  <v-app-bar elevation="0" color="background" density="comfortable" fixed>
    <v-app-bar-nav-icon @click="toggleSidebar(isDesktop)" />
    <v-btn icon="mdi-arrow-left" variant="text" @click="goBack" />
    <v-app-bar-title class="text-h6">{{ t('places.title') }}</v-app-bar-title>
  </v-app-bar>

  <v-container fluid>
    <v-alert v-if="!mapEnabled" type="info" variant="tonal" class="ma-4" icon="mdi-map-off">
      {{ t('places.mapDisabled') }}
    </v-alert>

    <v-alert v-if="error" type="error" class="ma-4" closable @click:close="error = null">
      {{ error }}
    </v-alert>

    <v-card elevation="0" class="mb-4">
      <v-list v-if="places.length > 0" lines="two">
        <v-list-item v-for="item in places" :key="item.id">
          <template #prepend>
            <v-icon
              :icon="kindIcon(item.kind)"
              :color="item.is_default ? 'primary' : undefined"
            />
          </template>
          <v-list-item-title>
            {{ item.name }}
            <v-icon v-if="item.is_default" size="small" color="primary" class="ms-1">mdi-star</v-icon>
          </v-list-item-title>
          <v-list-item-subtitle v-if="item.address">{{ item.address }}</v-list-item-subtitle>
          <v-list-item-subtitle class="text-caption">
            {{ kindLabel(item.kind) }} · {{ t('places.viewRadius', { radius: item.view_radius_km ?? 5 }) }} · {{ item.latitude.toFixed(4) }}, {{ item.longitude.toFixed(4) }}
          </v-list-item-subtitle>
          <template #append>
            <div class="d-flex ga-1">
              <v-btn
                icon="mdi-star-outline"
                size="small"
                variant="text"
                :color="item.is_default ? 'primary' : undefined"
                :disabled="item.is_default || !mapEnabled"
                :title="item.is_default ? t('places.alreadyDefault') : t('places.setDefault')"
                @click="setDefault(item)"
              />
              <v-btn icon="mdi-pencil" size="small" variant="text" color="primary" :disabled="!mapEnabled" @click="openEditDialog(item)" />
              <v-btn icon="mdi-delete" size="small" variant="text" color="error" :disabled="!mapEnabled" @click="deleteItem(item)" />
            </div>
          </template>
        </v-list-item>
      </v-list>
      <v-list v-else>
        <v-list-item>
          <v-list-item-title class="text-center text-medium-emphasis">
            {{ t('places.emptyHint') }}
          </v-list-item-title>
        </v-list-item>
      </v-list>
    </v-card>

    <p class="text-caption text-medium-emphasis px-2">
      {{ t('places.description') }}
    </p>

    <v-btn
      icon="mdi-plus"
      color="primary"
      size="large"
      elevation="6"
      class="fab-button"
      :disabled="!mapEnabled"
      @click="openEditDialog()"
    />

    <!-- 添加/编辑对话框 -->
    <v-dialog v-model="addDialog" max-width="500" :fullscreen="!isDesktop">
      <v-card>
        <v-card-title>{{ editingItem ? t('places.editTitle') : t('places.addTitle') }}</v-card-title>
        <v-card-text>
          <v-form>
            <v-text-field
              v-model="form.name"
              :label="t('places.nameLabel')"
              variant="outlined"
              required
              class="mb-4"
            />

            <v-select
              v-model="form.kind"
              :items="kindItems"
              item-title="label"
              item-value="value"
              :label="t('places.typeLabel')"
              variant="outlined"
              class="mb-4"
            />

            <v-select
              v-model="form.viewRadius"
              :items="radiusItems"
              item-title="label"
              item-value="value"
              :label="t('places.radiusLabel')"
              variant="outlined"
              class="mb-4"
            />

            <v-text-field v-model="form.address" :label="t('places.addressLabel')" variant="outlined" class="mb-4" />

            <div class="text-subtitle-2 mb-2">{{ t('places.location') }}</div>
            <MapPicker v-model="pickerCoords" :show-switcher="true" />
          </v-form>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="addDialog = false">{{ t('actions.cancel') }}</v-btn>
          <v-btn color="primary" :loading="saving" @click="saveItem">{{ t('actions.save') }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import { api } from '@/api'
import { getErrorMessage } from '@/utils/errorHandler'
import { useMobileDrawerControl } from '@/composables/useMobileDrawer'
import { useMapConfig } from '@/composables/useMapConfig'
import MapPicker from '@/components/map/MapPicker.vue'
import type { Coordinate } from '@/utils/map/mapTypes'

const { t } = useI18n()
const { isDesktop, toggleSidebar } = useMobileDrawerControl()
const { mapEnabled, ensureLoaded } = useMapConfig()
const router = useRouter()
const goBack = () => router.back()

interface PlaceOption {
  id: number
  name: string
  kind: string
  latitude: number
  longitude: number
  address?: string | null
  is_default?: boolean
  view_radius_km?: number
}

const places = ref<PlaceOption[]>([])
const loading = ref(false)
const error = ref<string | null>(null)
const addDialog = ref(false)
const editingItem = ref<PlaceOption | null>(null)
const saving = ref(false)
const pickerCoords = ref<Coordinate | undefined>()
const form = ref({ name: '', kind: 'custom', address: '', viewRadius: 5 })

const kindItems = [
  { label: t('places.kind.home'), value: 'home' },
  { label: t('places.kind.work'), value: 'work' },
  { label: t('places.kind.other'), value: 'custom' },
]

const radiusItems = [
  { label: '1 km', value: 1 },
  { label: '2 km', value: 2 },
  { label: '5 km', value: 5 },
  { label: '10 km', value: 10 },
  { label: '20 km', value: 20 },
  { label: '50 km', value: 50 },
]

const kindLabel = (k: string) => kindItems.find(i => i.value === k)?.label || t('places.kind.other')

const kindIcon = (k: string) => {
  if (k === 'home') return 'mdi-home'
  if (k === 'work') return 'mdi-office-building'
  return 'mdi-map-marker'
}

const loadPlaces = async () => {
  loading.value = true
  error.value = null
  try {
    const data = await api.get('/places')
    places.value = Array.isArray(data) ? data : []
  } catch (e: any) {
    error.value = getErrorMessage(e, t('places.loadFailed'))
  } finally {
    loading.value = false
  }
}

const openEditDialog = (item?: PlaceOption) => {
  editingItem.value = item || null
  if (item) {
    form.value = {
      name: item.name,
      kind: item.kind,
      address: item.address || '',
      viewRadius: item.view_radius_km ?? 5,
    }
    pickerCoords.value = { lat: item.latitude, lng: item.longitude }
  } else {
    form.value = { name: '', kind: 'custom', address: '', viewRadius: 5 }
    pickerCoords.value = undefined
  }
  addDialog.value = true
}

const saveItem = async () => {
  if (!form.value.name.trim()) return
  if (!pickerCoords.value) {
    error.value = t('places.selectLocation')
    return
  }
  saving.value = true
  try {
    const data: any = {
      name: form.value.name,
      kind: form.value.kind,
      latitude: pickerCoords.value.lat,
      longitude: pickerCoords.value.lng,
      address: form.value.address || undefined,
      view_radius_km: form.value.viewRadius,
    }
    if (editingItem.value) {
      await api.put(`/places/${editingItem.value.id}`, data)
    } else {
      await api.post('/places', data)
    }
    addDialog.value = false
    await loadPlaces()
  } catch (e: any) {
    error.value = getErrorMessage(e, t('places.saveFailed'))
  } finally {
    saving.value = false
  }
}

const setDefault = async (item: PlaceOption) => {
  try {
    await api.put(`/places/${item.id}/default`)
    await loadPlaces()
  } catch (e: any) {
    error.value = getErrorMessage(e, t('places.setDefaultFailed'))
  }
}

const deleteItem = async (item: PlaceOption) => {
  try {
    await api.delete(`/places/${item.id}`)
    await loadPlaces()
  } catch (e: any) {
    error.value = getErrorMessage(e, t('places.deleteFailed'))
  }
}

onMounted(() => {
  ensureLoaded()
  loadPlaces()
})
</script>

<style scoped>
.fab-button {
  position: fixed;
  bottom: 16px;
  right: 16px;
  z-index: 10;
}
</style>
