<template>
  <v-container fluid>
    <v-card elevation="0">
      <v-card-title>币种管理</v-card-title>
      <v-card-text>
        <v-table>
          <thead><tr><th>代码</th><th>名称</th><th>符号</th><th>小数位</th></tr></thead>
          <tbody>
            <tr v-for="c in currencies" :key="c.code">
              <td>{{ c.code }}</td>
              <td>{{ c.name }}</td>
              <td>{{ c.symbol }}</td>
              <td>{{ c.decimals }}</td>
            </tr>
          </tbody>
        </v-table>
      </v-card-text>
    </v-card>
  </v-container>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { listCurrencies } from '@/api/currencies'
const currencies = ref<any[]>([])
onMounted(async () => { currencies.value = await listCurrencies() })
</script>
