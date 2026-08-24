<template>
  <v-container fluid>
    <v-card elevation="0">
      <v-card-title class="d-flex align-center">
        <span class="mr-auto">币种管理</span>
        <v-btn color="primary" prepend-icon="mdi-plus" @click="openCreateDialog">新增币种</v-btn>
      </v-card-title>
      <v-card-text>
        <v-table>
          <thead>
            <tr>
              <th>代码</th>
              <th>名称</th>
              <th>符号</th>
              <th>小数位</th>
              <th>状态</th>
              <th>操作</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="c in currencies" :key="c.code">
              <td>{{ c.code }}</td>
              <td>{{ c.name }}</td>
              <td>{{ c.symbol }}</td>
              <td>{{ c.decimals }}</td>
              <td>
                <div class="d-flex align-center ga-2">
                  <v-switch
                    :model-value="c.is_active"
                    color="success"
                    density="compact"
                    hide-details
                    :loading="togglingCode === c.code"
                    @update:model-value="(v) => toggleActive(c, Boolean(v))"
                  />
                  <span class="text-caption">{{ c.is_active ? '启用' : '停用' }}</span>
                </div>
              </td>
              <td>
                <v-btn
                  icon="mdi-delete"
                  size="small"
                  variant="text"
                  color="error"
                  title="停用"
                  @click="openDeleteDialog(c)"
                />
              </td>
            </tr>
          </tbody>
        </v-table>
      </v-card-text>
    </v-card>

    <!-- 新增币种对话框 -->
    <v-dialog v-model="createDialog" max-width="480px" persistent>
      <v-card>
        <v-card-title>新增币种</v-card-title>
        <v-card-text>
          <v-form @submit.prevent="submitCreate">
            <v-text-field
              v-model="form.code"
              label="代码（3 位大写字母）"
              counter
              required
              hint="如 CNY / USD"
              @input="form.code = form.code.toUpperCase()"
            />
            <v-text-field v-model="form.name" label="名称" required />
            <v-text-field v-model="form.symbol" label="符号" hint="如 ¥ / $" />
            <v-text-field v-model="form.decimals" label="小数位" type="number" min="0" max="4" />
          </v-form>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="createDialog = false">取消</v-btn>
          <v-btn color="primary" :loading="saving" @click="submitCreate">保存</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- 删除（停用）确认对话框 -->
    <v-dialog v-model="deleteDialog" max-width="420px" persistent>
      <v-card>
        <v-card-title>停用币种</v-card-title>
        <v-card-text>
          确定要停用币种「{{ deleteTarget?.code }}」吗？停用后公共列表不再展示，数据保留。
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="deleteDialog = false">取消</v-btn>
          <v-btn color="error" :loading="deleting" @click="confirmDelete">停用</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import {
  listAdminCurrencies,
  createCurrency,
  updateCurrency,
  deleteCurrency,
} from '@/api/currencies'
import { useGlobalSnackbar } from '@/composables/useGlobalSnackbar'

const { notify } = useGlobalSnackbar()

const currencies = ref<any[]>([])
const loading = ref(false)

const createDialog = ref(false)
const saving = ref(false)
const form = reactive({ code: '', name: '', symbol: '', decimals: 2 })

const deleteDialog = ref(false)
const deleting = ref(false)
const deleteTarget = ref<any>(null)
const togglingCode = ref('')

async function fetchCurrencies() {
  loading.value = true
  try {
    currencies.value = await listAdminCurrencies()
  } catch (e: any) {
    notify(e?.userMessage || '获取币种列表失败', 'error')
  } finally {
    loading.value = false
  }
}

function openCreateDialog() {
  form.code = ''
  form.name = ''
  form.symbol = ''
  form.decimals = 2
  createDialog.value = true
}

async function submitCreate() {
  const code = form.code.trim()
  const name = form.name.trim()
  if (!code || !name) {
    notify('请填写代码和名称', 'warning')
    return
  }
  if (!/^[A-Z]{3}$/.test(code)) {
    notify('代码需为 3 位大写字母', 'warning')
    return
  }
  saving.value = true
  try {
    await createCurrency({
      code,
      name,
      symbol: form.symbol.trim() || null,
      decimals: Number(form.decimals) || 2,
    })
    createDialog.value = false
    notify('币种已保存', 'success')
    await fetchCurrencies()
  } catch (e: any) {
    notify(e?.userMessage || '保存失败', 'error')
  } finally {
    saving.value = false
  }
}

async function toggleActive(c: any, value: boolean) {
  togglingCode.value = c.code
  try {
    await updateCurrency(c.code, { is_active: value })
    c.is_active = value
    notify(value ? `已启用 ${c.code}` : `已停用 ${c.code}`, 'success')
  } catch (e: any) {
    notify(e?.userMessage || '操作失败', 'error')
  } finally {
    togglingCode.value = ''
  }
}

function openDeleteDialog(c: any) {
  deleteTarget.value = c
  deleteDialog.value = true
}

async function confirmDelete() {
  if (!deleteTarget.value) return
  deleting.value = true
  try {
    await deleteCurrency(deleteTarget.value.code)
    const code = deleteTarget.value.code
    deleteDialog.value = false
    notify(`已停用 ${code}`, 'success')
    await fetchCurrencies()
  } catch (e: any) {
    notify(e?.userMessage || '停用失败', 'error')
  } finally {
    deleting.value = false
  }
}

onMounted(fetchCurrencies)
</script>
