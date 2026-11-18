<template>
  <div>
    <div v-if="title" class="d-flex align-center mb-3">
      <v-icon start color="info">mdi-table-compare</v-icon>
      <span class="text-h6 font-weight-regular">{{ title }}</span>
      <span v-if="unitNote" class="text-caption text-medium-emphasis ms-2">{{ unitNote }}</span>
    </div>

    <v-card elevation="0" variant="outlined">
      <v-card-text class="pa-0">
        <div v-if="loading" class="text-center py-8">
          <v-progress-circular indeterminate size="24" />
        </div>
        <div v-else-if="!rows.length || !columns.length" class="text-center py-6 text-medium-emphasis">
          <v-icon size="40" color="medium-emphasis">mdi-table-off</v-icon>
          <div class="text-body-2 mt-2">{{ emptyText }}</div>
        </div>
        <div v-else class="price-table-wrapper">
          <table class="price-matrix">
            <thead>
              <tr>
                <th class="sticky-col" style="min-width:140px">{{ t('compare.matrixEntityCol') }}</th>
                <th v-for="c in columns" :key="c.id" class="text-end">
                  <span class="text-truncate d-inline-block" style="max-width:96px">{{ c.label }}</span>
                </th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in rows" :key="row.id">
                <td class="sticky-col" style="min-width:140px">
                  <span class="font-weight-medium">{{ row.label }}</span>
                  <span v-if="row.unit" class="qty-badge">/ {{ row.unit }}</span>
                </td>
                <td
                  v-for="c in columns"
                  :key="String(c.id)"
                  class="text-end"
                  :class="{ 'price-lowest': isLowest(row, c.id), 'price-missing': !hasData(row, c.id), 'price-stale': isStale(row, c.id) }"
                >
                  <template v-if="hasData(row, c.id)">
                    {{ formatMoney(cell(row, c.id)!.price, userCurrency) }}
                    <v-icon
                      v-if="isStale(row, c.id)"
                      size="x-small"
                      color="grey"
                      class="ms-1"
                    >mdi-clock-outline</v-icon>
                  </template>
                  <template v-else>—</template>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </v-card-text>
    </v-card>
    <div v-if="rows.length && columns.length" class="text-caption text-medium-emphasis mt-1">
      {{ t('compare.unassignedMerchantsNote') }}
    </div>
  </div>
</template>

<script setup lang="ts">
// 地区比价矩阵：行=实体、列=地区，每行最低价高亮、缺失「—」、超期置灰。
// 通用组件：与复用同一布局的商家比价矩阵（MerchantPriceMatrix）同构。
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { useUserCurrency } from '@/composables/useUserCurrency'
import { formatMoney } from '@/utils/currency'

const { t } = useI18n()
const { currency: userCurrency } = useUserCurrency()

export interface RegionMatrixColumn {
  id: number | string
  label: string
}

export interface RegionMatrixCell {
  price: number | null
  isStale?: boolean
}

export interface RegionMatrixRow {
  id: number | string
  label: string
  unit?: string | null
  cells: Record<string, RegionMatrixCell | null>
}

const props = withDefaults(defineProps<{
  columns?: RegionMatrixColumn[]
  rows?: RegionMatrixRow[]
  loading?: boolean
  title?: string
  unitNote?: string
  emptyText?: string
}>(), {
  columns: () => [],
  rows: () => [],
  loading: false,
  title: '',
  unitNote: '',
  emptyText: '',
})

function cell(row: RegionMatrixRow, colId: number | string): RegionMatrixCell | null {
  return row.cells[String(colId)] ?? null
}

function hasData(row: RegionMatrixRow, colId: number | string): boolean {
  const c = cell(row, colId)
  return !!(c && c.price != null)
}

function isStale(row: RegionMatrixRow, colId: number | string): boolean {
  return !!(cell(row, colId)?.isStale)
}

function isLowest(row: RegionMatrixRow, colId: number | string): boolean {
  const c = cell(row, colId)
  if (!c || c.price == null || c.isStale) return false
  const prices = props.columns
    .map(col => cell(row, col.id))
    .filter(x => x && x.price != null && !x.isStale)
    .map(x => x!.price as number)
  if (prices.length < 2) return false
  return c.price <= Math.min(...prices)
}
</script>

<style scoped>
.price-table-wrapper {
  overflow-x: auto;
  overflow-y: clip;
}
.price-matrix {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}
.price-matrix th,
.price-matrix td {
  padding: 8px 12px;
  white-space: nowrap;
  border-bottom: 1px solid #e0e0e0;
}
.price-matrix th {
  background: #f5f5f5;
  font-weight: 500;
  position: sticky;
  top: 0;
  z-index: 2;
}
.sticky-col {
  position: sticky;
  inset-inline-start: 0;
  background: white;
  z-index: 1;
  min-width: 120px;
  box-shadow: 2px 0 6px rgba(0,0,0,0.06);
}
.price-matrix th.sticky-col {
  background: #f5f5f5;
  z-index: 3;
  box-shadow: 2px 0 6px rgba(0,0,0,0.08);
}
.qty-badge {
  display: inline-block;
  color: #888;
  font-size: 12px;
  margin-inline-start: 6px;
  white-space: nowrap;
}
.price-lowest {
  font-weight: 700;
  color: #2e7d32;
}
.price-stale {
  color: #9e9e9e;
}
.price-missing {
  color: #ccc;
}
.text-end {
  text-align: end;
}
</style>
