<template>
  <v-bottom-navigation
    :elevation="3"
    color="primary"
    grow
    class="mobile-nav"
  >
    <v-btn value="meals" to="/">
      <v-icon>mdi-silverware-fork-knife</v-icon>
      <span>{{ t('nav.today') }}</span>
    </v-btn>

    <v-btn value="recipes" to="/recipes">
      <v-icon>mdi-book-open-variant</v-icon>
      <span>{{ t('nav.recipes') }}</span>
    </v-btn>

    <v-btn value="data" to="/data">
      <v-icon>mdi-database</v-icon>
      <span>{{ t('mobileNav.data') }}</span>
    </v-btn>

    <v-btn value="profile" to="/profile">
      <v-icon>mdi-account</v-icon>
      <span>{{ t('nav.profile') }}</span>
    </v-btn>
  </v-bottom-navigation>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'
const { t } = useI18n()
// 移动端底部导航 - 使用 CSS 媒体查询控制显示
</script>

<style>
/* 只在移动端显示 */
@media (max-width: 960px) {
  .mobile-nav {
    display: none !important;
  }
}
</style>
