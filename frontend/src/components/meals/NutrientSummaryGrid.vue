<template>
  <div class="nutrient-grid-wrap">
    <div class="nutrient-grid">
      <div v-for="item in items" :key="item.label" class="nutrient-grid__item">
        <span class="text-caption text-medium-emphasis d-flex align-center ga-1">
          <v-icon size="small">{{ item.icon }}</v-icon>
          {{ item.label }}
        </span>
        <span class="font-weight-medium text-no-wrap">{{ item.value }}</span>
        <span v-if="item.nrv" class="text-caption text-medium-emphasis text-no-wrap">
          {{ item.nrv }}
        </span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
/**
 * 营养素四宫格：宽屏（容器 ≥ 480px）一行 4 列；窄屏 / 窄容器自动折成 2×2。
 * 用容器查询（container query）而非视口媒体查询，餐卡在宽屏页面里也能按自身宽度折叠。
 */
defineProps<{
  items: { icon: string; label: string; value: string; nrv?: string }[]
}>()
</script>

<style scoped>
.nutrient-grid-wrap {
  container-type: inline-size;
}
.nutrient-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px 12px;
}
@container (min-width: 480px) {
  .nutrient-grid {
    grid-template-columns: repeat(4, minmax(0, 1fr));
  }
}
/* 老浏览器不支持容器查询时按视口宽度兜底 */
@supports not (container-type: inline-size) {
  @media (min-width: 600px) {
    .nutrient-grid {
      grid-template-columns: repeat(4, minmax(0, 1fr));
    }
  }
}
.nutrient-grid__item {
  display: flex;
  flex-direction: column;
  min-width: 0;
}
</style>
