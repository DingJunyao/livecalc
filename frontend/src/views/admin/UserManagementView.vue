<template>
  <v-app-bar elevation="0" color="background" density="comfortable" fixed>
    <v-app-bar-nav-icon @click="toggleSidebar(isDesktop)" />
    <v-btn icon="mdi-arrow-left" variant="text" @click="goBack" />
    <v-app-bar-title class="text-h6">{{ t('admin.users.title') }}</v-app-bar-title>
    <template #append>
      <v-btn color="primary" variant="tonal" @click="openCreateDialog">
        <v-icon start>mdi-plus</v-icon>
        {{ t('admin.users.create') }}
      </v-btn>
    </template>
  </v-app-bar>

  <v-container class="pa-4">
    <!-- 搜索栏 -->
    <v-card class="rounded-lg mb-4">
      <v-card-text class="pb-0">
        <v-text-field
          v-model="search"
          :label="t('admin.users.search')"
          prepend-inner-icon="mdi-magnify"
          clearable
          hide-details
          single-line
          variant="plain"
          @update:model-value="onSearch"
        />
      </v-card-text>
    </v-card>

    <!-- 用户列表 -->
    <v-card class="rounded-lg">
      <v-data-table-server
        v-model:items-per-page="itemsPerPage"
        :headers="headers"
        :items="users"
        :items-length="totalItems"
        :loading="loading"
        item-value="id"
        class="rounded-lg"
        @update:options="fetchUsers"
      >
        <!-- 管理员列 -->
        <template #item.is_admin="{ item }">
          <v-chip
            v-if="item.is_admin"
            color="warning"
            size="small"
            variant="tonal"
          >
            <v-icon start size="16">mdi-shield-account</v-icon>
            {{ t('admin.users.administrator') }}
          </v-chip>
          <span v-else class="text-medium-emphasis">{{ t('admin.users.normalUser') }}</span>
        </template>

        <!-- 状态列 -->
        <template #item.is_active="{ item }">
          <v-chip
            :color="item.is_active ? 'success' : 'error'"
            size="small"
            variant="tonal"
          >
            {{ item.is_active ? t('admin.users.active') : t('admin.users.inactive') }}
          </v-chip>
        </template>

        <!-- 注册时间列 -->
        <template #item.created_at="{ item }">
          {{ item.created_at ? formatToLocalDateTimeShort(item.created_at) : '-' }}
        </template>

        <!-- 操作列 -->
        <template #item.actions="{ item }">
          <div class="d-flex ga-1 justify-end">
            <v-tooltip location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-pencil" size="small" variant="text" color="primary" @click="openEditDialog(item)" />
              </template>
              <span>{{ t('admin.users.edit') }}</span>
            </v-tooltip>
            <v-tooltip location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-shield-account" size="small" variant="text" :color="item.is_admin ? 'warning' : 'default'" :disabled="!canToggleAdmin(item)" @click="confirmToggleAdmin(item)" />
              </template>
              <span>{{ adminTooltip(item) }}</span>
            </v-tooltip>
            <v-tooltip location="top">
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-power" size="small" variant="text" :color="item.is_active ? 'error' : 'success'" :disabled="!canToggleActive(item)" @click="confirmToggleActive(item)" />
              </template>
              <span>{{ activeTooltip(item) }}</span>
            </v-tooltip>
          </div>
        </template>
      </v-data-table-server>
    </v-card>

    <!-- 新增/编辑对话框 -->
    <v-dialog v-model="formDialog" max-width="500px" persistent>
      <v-card class="rounded-lg">
        <v-card-title class="d-flex align-center py-4">
          <v-icon class="me-2">{{ isEditing ? 'mdi-pencil' : 'mdi-plus' }}</v-icon>
          <span>{{ isEditing ? t('admin.users.editTitle') : t('admin.users.create') }}</span>
        </v-card-title>
        <v-divider />
        <v-card-text class="pt-6">
          <v-form ref="form" @submit.prevent="saveUser">
            <v-text-field
              v-model="formData.username"
              :label="t('admin.users.username')"
              prepend-icon="mdi-account"
              required
              :rules="[rules.required]"
              variant="outlined"
              density="comfortable"
            />
            <v-text-field
              v-model="formData.email"
              :label="t('admin.users.email')"
              prepend-icon="mdi-email"
              required
              :rules="[rules.required, rules.email]"
              variant="outlined"
              density="comfortable"
            />
            <v-text-field
              v-model="formData.phone"
              :label="t('admin.users.phone')"
              prepend-icon="mdi-phone"
              variant="outlined"
              density="comfortable"
            />
            <v-text-field
              v-if="!isEditing"
              v-model="formData.password"
              :label="t('admin.users.password')"
              prepend-icon="mdi-lock"
              variant="outlined"
              density="comfortable"
              required
              :rules="[rules.required, rules.minPassword]"
              type="password"
            />
            <div v-else class="mb-2">
              <v-btn
                variant="outlined"
                color="primary"
                prepend-icon="mdi-lock-reset"
                @click="openResetPasswordDialog"
              >
                {{ t('admin.users.resetPassword') }}
              </v-btn>
              <div class="text-caption text-medium-emphasis mt-1">
                {{ t('admin.users.resetPasswordHint') }}
              </div>
            </div>
            <v-checkbox
              v-model="formData.is_admin"
              :label="t('admin.users.setAdministrator')"
              color="primary"
              density="comfortable"
            />
          </v-form>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="tonal" @click="formDialog = false">{{ t('actions.cancel') }}</v-btn>
          <v-btn color="primary" :loading="saving" @click="saveUser">
            {{ isEditing ? t('actions.save') : t('admin.users.create') }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- 重置密码对话框 -->
    <v-dialog v-model="resetDialog" max-width="420px" persistent>
      <v-card class="rounded-lg">
        <v-card-title class="text-h6 d-flex align-center py-4">
          <v-icon class="me-2">mdi-lock-reset</v-icon>
          <span>{{ t('admin.users.resetPasswordTitle', { name: resetUsername }) }}</span>
        </v-card-title>
        <v-divider />
        <v-card-text class="pt-6">
          <v-form ref="resetFormRef" @submit.prevent="submitResetPassword">
            <v-text-field
              v-model="resetFormData.newPassword"
              :label="t('admin.users.newPassword')"
              prepend-icon="mdi-lock"
              type="password"
              required
              :rules="[rules.required, rules.minPassword]"
              variant="outlined"
              density="comfortable"
            />
            <v-text-field
              v-model="resetFormData.confirmPassword"
              :label="t('admin.users.confirmNewPassword')"
              prepend-icon="mdi-lock-check"
              type="password"
              required
              :rules="[rules.required, confirmPasswordRule]"
              variant="outlined"
              density="comfortable"
            />
          </v-form>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="tonal" @click="resetDialog = false">{{ t('actions.cancel') }}</v-btn>
          <v-btn color="primary" :loading="resetting" @click="submitResetPassword">
            {{ t('admin.users.confirmReset') }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- 管理员切换确认 -->
    <v-dialog v-model="adminDialog" max-width="400px">
      <v-card class="rounded-lg">
        <v-card-title class="text-h6">
          {{ adminTarget?.is_admin ? t('admin.users.removeAdministrator') : t('admin.users.setAdministrator') }}
        </v-card-title>
        <v-card-text>
          {{ adminTarget?.is_admin ? t('admin.users.adminConfirmRemove', { name: adminTarget?.username ?? '' }) : t('admin.users.adminConfirmGrant', { name: adminTarget?.username ?? '' }) }}
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="tonal" @click="adminDialog = false">{{ t('actions.cancel') }}</v-btn>
          <v-btn color="primary" :loading="toggling" @click="toggleAdmin">{{ t('common.confirm') }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- 激活切换确认 -->
    <v-dialog v-model="activeDialog" max-width="400px">
      <v-card class="rounded-lg">
        <v-card-title class="text-h6">
          {{ activeTarget?.is_active ? t('admin.users.deactivateUser') : t('admin.users.activateUser') }}
        </v-card-title>
        <v-card-text>
          {{ activeTarget?.is_active ? t('admin.users.activeConfirmDeactivate', { name: activeTarget?.username ?? '' }) : t('admin.users.activeConfirmActivate', { name: activeTarget?.username ?? '' }) }}
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="tonal" @click="activeDialog = false">{{ t('actions.cancel') }}</v-btn>
          <v-btn :color="activeTarget?.is_active ? 'error' : 'success'" :loading="toggling" @click="toggleActive">{{ t('common.confirm') }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- 操作提示 -->
    <v-snackbar v-model="snackbar.show" :color="snackbar.color" timeout="3000">
      <v-icon start>{{ snackbar.icon }}</v-icon>
      {{ snackbar.message }}
    </v-snackbar>
  </v-container>
</template>

<script setup lang="ts">
import { ref, reactive, computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import { useMobileDrawerControl } from '@/composables/useMobileDrawer'
import { useUserStore } from '@/stores/user'
import { api } from '@/api'
import { formatToLocalDateTimeShort } from '@/utils/timezone'
import { hashPassword } from '@/utils/crypto'

const { isDesktop, toggleSidebar } = useMobileDrawerControl()
const { t } = useI18n()
const router = useRouter()
const userStore = useUserStore()

const currentUserId = computed(() => userStore.user?.id)

const goBack = () => {
  router.back()
}

interface User {
  id: number
  username: string
  email: string
  phone: string | null
  is_admin: boolean
  is_active?: boolean
  email_verified: boolean
  created_at: string | null
}

const headers = computed(() => [
  { title: 'ID', key: 'id', width: 60, sortable: false },
  { title: t('admin.users.username'), key: 'username', sortable: false },
  { title: t('admin.users.email'), key: 'email', sortable: false },
  { title: t('admin.users.phone'), key: 'phone', sortable: false },
  { title: t('admin.users.role'), key: 'is_admin', sortable: false, width: 100 },
  { title: t('admin.users.status'), key: 'is_active', sortable: false, width: 90 },
  { title: t('admin.users.registeredAt'), key: 'created_at', sortable: false },
  { title: t('admin.users.actions'), key: 'actions', sortable: false, align: 'end' as const, width: 140 },
])

const users = ref<User[]>([])
const loading = ref(false)
const totalItems = ref(0)
const itemsPerPage = ref(20)
const search = ref('')
let searchTimer: ReturnType<typeof setTimeout> | null = null

const rules = computed(() => ({
  required: (v: string) => !!v || t('admin.users.required'),
  email: (v: string) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v) || t('admin.users.emailInvalid'),
  minPassword: (v: string) => (v && v.length >= 6) || t('admin.users.passwordMin'),
}))

// 表单
const formDialog = ref(false)
const saving = ref(false)
const isEditing = ref(false)
const editingUserId = ref<number | null>(null)
const formData = reactive({
  username: '',
  email: '',
  phone: '',
  password: '',
  is_admin: false,
})

// 管理员切换
const adminDialog = ref(false)
const adminTarget = ref<User | null>(null)
const toggling = ref(false)

// 激活切换
const activeDialog = ref(false)
const activeTarget = ref<User | null>(null)

// 重置密码
const resetDialog = ref(false)
const resetting = ref(false)
const resetUserId = ref<number | null>(null)
const resetUsername = ref('')
const resetFormData = reactive({
  newPassword: '',
  confirmPassword: '',
})
const resetFormRef = ref()
const confirmPasswordRule = (v: string) =>
  v === resetFormData.newPassword || t('admin.users.passwordMismatch')

// 提示
const snackbar = reactive({
  show: false,
  message: '',
  color: 'success',
  icon: 'mdi-check-circle',
})

const showSnackbar = (message: string, color = 'success', icon = 'mdi-check-circle') => {
  snackbar.message = message
  snackbar.color = color
  snackbar.icon = icon
  snackbar.show = true
}

// 安全规则
const canToggleAdmin = (user: User): boolean => {
  if (user.id === currentUserId.value) return false
  if (user.id === 1) return false
  return true
}

const canToggleActive = (user: User): boolean => {
  if (user.id === currentUserId.value) return false
  if (user.id === 1) return false
  return true
}

const adminTooltip = (user: User): string => {
  if (user.id === currentUserId.value) return t('admin.users.cannotChangeOwnAdmin')
  if (user.id === 1) return t('admin.users.cannotChangeInitialAdmin')
  return user.is_admin ? t('admin.users.removeAdministrator') : t('admin.users.setAdministrator')
}

const activeTooltip = (user: User): string => {
  if (user.id === currentUserId.value) return t('admin.users.cannotDeactivateSelf')
  if (user.id === 1) return t('admin.users.cannotDeactivateInitialAdmin')
  return user.is_active ? t('admin.users.deactivateUser') : t('admin.users.activateUser')
}

// 获取用户列表
const fetchUsers = async ({ page, itemsPerPage: limit }: { page: number; itemsPerPage: number }) => {
  loading.value = true
  try {
    const skip = (page - 1) * limit
    const params: Record<string, any> = { skip, limit }
    if (search.value) params.search = search.value
    const response = await api.get('/auth/users', { params })
    users.value = response.items.map((u: any) => ({
      ...u,
      is_active: u.is_active !== false,
    }))
    totalItems.value = response.total
  } catch (error) {
    console.error('Failed to get users:', error)
    showSnackbar(t('admin.users.loadFailed'), 'error', 'mdi-alert-circle')
  } finally {
    loading.value = false
  }
}

const onSearch = () => {
  if (searchTimer) clearTimeout(searchTimer)
  searchTimer = setTimeout(() => {
    fetchUsers({ page: 1, itemsPerPage: itemsPerPage.value })
  }, 300)
}

// 新增/编辑
const openCreateDialog = () => {
  isEditing.value = false
  editingUserId.value = null
  formData.username = ''
  formData.email = ''
  formData.phone = ''
  formData.password = ''
  formData.is_admin = false
  formDialog.value = true
}

const openEditDialog = (user: User) => {
  isEditing.value = true
  editingUserId.value = user.id
  formData.username = user.username
  formData.email = user.email
  formData.phone = user.phone || ''
  formData.password = ''
  formData.is_admin = user.is_admin
  formDialog.value = true
}

const saveUser = async () => {
  saving.value = true
  try {
    const payload: Record<string, any> = {}
    if (isEditing.value) {
      payload.username = formData.username
      payload.email = formData.email
      payload.phone = formData.phone || null
      // 编辑不再处理密码：改密走「重置密码」对话框
    } else {
      payload.username = formData.username
      payload.email = formData.email
      payload.phone = formData.phone || null
      payload.password_hash = hashPassword(formData.password)
      payload.is_admin = formData.is_admin
    }

    if (isEditing.value) {
      await api.put(`/auth/users/${editingUserId.value}`, payload)
      showSnackbar(t('admin.users.updated'))
    } else {
      await api.post('/auth/users', payload)
      showSnackbar(t('admin.users.created'))
    }
    formDialog.value = false
    fetchUsers({ page: 1, itemsPerPage: itemsPerPage.value })
  } catch (error: any) {
    const msg = error?.response?.data?.detail || error?.message || t('admin.users.operationFailed')
    showSnackbar(msg, 'error', 'mdi-alert-circle')
  } finally {
    saving.value = false
  }
}

// 管理员切换
const confirmToggleAdmin = (user: User) => {
  adminTarget.value = user
  adminDialog.value = true
}

const toggleAdmin = async () => {
  if (!adminTarget.value) return
  toggling.value = true
  try {
    await api.put(`/auth/users/${adminTarget.value.id}/admin`, {
      is_admin: !adminTarget.value.is_admin,
    })
    showSnackbar(
      adminTarget.value.is_admin
        ? t('admin.users.adminRemoved', { name: adminTarget.value.username })
        : t('admin.users.adminGranted', { name: adminTarget.value.username })
    )
    adminDialog.value = false
    fetchUsers({ page: 1, itemsPerPage: itemsPerPage.value })
  } catch (error: any) {
    const msg = error?.response?.data?.detail || error?.message || t('admin.users.operationFailed')
    showSnackbar(msg, 'error', 'mdi-alert-circle')
  } finally {
    toggling.value = false
  }
}

// 激活切换
const confirmToggleActive = (user: User) => {
  activeTarget.value = user
  activeDialog.value = true
}

const toggleActive = async () => {
  if (!activeTarget.value) return
  toggling.value = true
  try {
    await api.put(`/auth/users/${activeTarget.value.id}/active`, {
      is_active: !activeTarget.value.is_active,
    })
    showSnackbar(
      activeTarget.value.is_active
        ? t('admin.users.deactivated', { name: activeTarget.value.username })
        : t('admin.users.activated', { name: activeTarget.value.username })
    )
    activeDialog.value = false
    fetchUsers({ page: 1, itemsPerPage: itemsPerPage.value })
  } catch (error: any) {
    const msg = error?.response?.data?.detail || error?.message || t('admin.users.operationFailed')
    showSnackbar(msg, 'error', 'mdi-alert-circle')
  } finally {
    toggling.value = false
  }
}

// 重置密码
const openResetPasswordDialog = () => {
  resetUserId.value = editingUserId.value
  resetUsername.value = formData.username
  resetFormData.newPassword = ''
  resetFormData.confirmPassword = ''
  resetDialog.value = true
}

const submitResetPassword = async () => {
  if (!resetUserId.value) return
  const { valid } = await resetFormRef.value.validate()
  if (!valid) return
  resetting.value = true
  try {
    await api.put(`/auth/users/${resetUserId.value}`, {
      password_hash: hashPassword(resetFormData.newPassword),
    })
    showSnackbar(t('admin.users.passwordReset', { name: resetUsername.value }))
    resetDialog.value = false
  } catch (error: any) {
    const msg = error?.response?.data?.detail || error?.message || t('admin.users.resetFailed')
    showSnackbar(msg, 'error', 'mdi-alert-circle')
  } finally {
    resetting.value = false
  }
}
</script>
