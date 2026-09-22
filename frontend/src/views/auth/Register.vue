<template>
  <v-app>
    <v-main class="d-flex align-center justify-center bg-background">
      <v-container class="h-100 d-flex align-center justify-center">
        <v-card class="elevation-8" max-width="400" width="100%">
          <v-card-title class="text-center pa-6">
            <div class="text-h4 font-weight-bold text-primary">{{ t('auth.registerTitle') }}</div>
            <div class="text-subtitle-2 text-medium-emphasis mt-2">{{ t('auth.registerSubtitle') }}</div>
          </v-card-title>

          <v-card-text>
            <v-form @submit.prevent="handleRegister">
              <v-text-field
                v-model="form.username"
                :label="t('auth.username')"
                prepend-inner-icon="mdi-account"
                variant="outlined"
                required
                :error-messages="errors.username"
                class="mb-4"
              />

              <v-text-field
                v-model="form.email"
                :label="t('auth.email')"
                prepend-inner-icon="mdi-email"
                type="email"
                variant="outlined"
                required
                :error-messages="errors.email"
                class="mb-4"
              />

              <v-text-field
                v-model="form.password"
                :label="t('auth.password')"
                prepend-inner-icon="mdi-lock"
                type="password"
                variant="outlined"
                required
                :error-messages="errors.password"
                class="mb-4"
              />

              <v-text-field
                v-model="form.confirmPassword"
                :label="t('auth.confirmPassword')"
                prepend-inner-icon="mdi-lock-check"
                type="password"
                variant="outlined"
                required
                :error-messages="errors.confirmPassword"
                class="mb-4"
              />

              <v-text-field
                v-if="requireInviteCode"
                v-model="form.inviteCode"
                :label="t('auth.inviteCode')"
                prepend-inner-icon="mdi-ticket"
                variant="outlined"
                required
                :error-messages="errors.inviteCode"
                class="mb-4"
              />

              <v-btn
                type="submit"
                color="primary"
                size="large"
                block
                variant="elevated"
                :loading="loading"
              >
                {{ t('auth.register') }}
              </v-btn>
            </v-form>

            <v-alert v-if="errorMessage" type="error" class="mt-4" closable>
              {{ errorMessage }}
            </v-alert>
          </v-card-text>

          <v-card-actions class="pa-4 pt-0">
            <span class="text-body-2 text-medium-emphasis">{{ t('auth.haveAccount') }}</span>
            <v-btn variant="text" color="primary" to="/login" class="ms-1">
              {{ t('auth.loginNow') }}
            </v-btn>
          </v-card-actions>
        </v-card>
      </v-container>
    </v-main>
  </v-app>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import { useUserStore } from '@/stores/user'
import { api } from '@/api'
import { hashPassword } from '@/utils/crypto'

const router = useRouter()
const userStore = useUserStore()
const { t } = useI18n()

const form = reactive({
  username: '',
  email: '',
  password: '',
  confirmPassword: '',
  inviteCode: '',
})

const errors = reactive({
  username: '',
  email: '',
  password: '',
  confirmPassword: '',
  inviteCode: '',
})

const loading = ref(false)
const errorMessage = ref('')
const requireInviteCode = ref(false)

// 获取注册配置
onMounted(async () => {
  try {
    const config: any = await api.get('/auth/config')
    requireInviteCode.value = config.registration_require_invite_code || false
  } catch (error) {
    console.error('Failed to fetch auth config:', error)
  }
})

const handleRegister = async () => {
  // 清空错误
  Object.keys(errors).forEach(key => {
    errors[key as keyof typeof errors] = ''
  })
  errorMessage.value = ''

  // 验证
  let hasError = false
  if (!form.username) {
    errors.username = t('auth.usernameRequired')
    hasError = true
  } else if (form.username.length < 3 || form.username.length > 50) {
    errors.username = t('auth.usernameLength')
    hasError = true
  }
  if (!form.email) {
    errors.email = t('auth.emailRequired')
    hasError = true
  } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email)) {
    errors.email = t('auth.emailInvalid')
    hasError = true
  }
  if (!form.password) {
    errors.password = t('auth.passwordRequired')
    hasError = true
  } else if (form.password.length < 6) {
    errors.password = t('auth.passwordMin')
    hasError = true
  }
  if (form.password !== form.confirmPassword) {
    errors.confirmPassword = t('auth.passwordMismatch')
    hasError = true
  }
  if (requireInviteCode.value && !form.inviteCode) {
    errors.inviteCode = t('auth.inviteCodeRequired')
    hasError = true
  }

  if (hasError) return

  loading.value = true
  try {
    // 在前端加密密码
    const passwordHash = hashPassword(form.password)
    await userStore.register(
      form.username,
      form.email,
      passwordHash,
      requireInviteCode.value ? form.inviteCode : undefined
    )
    router.push('/')
  } catch (error: any) {
    errorMessage.value = error.userMessage || error.response?.data?.detail || t('auth.registerFailed')
  } finally {
    loading.value = false
  }
}
</script>
