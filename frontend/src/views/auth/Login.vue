<template>
  <v-app>
    <v-main class="d-flex align-center justify-center bg-background">
      <v-container class="h-100 d-flex align-center justify-center">
        <v-card class="elevation-8" max-width="400" width="100%">
          <v-card-title class="text-center pa-6">
            <div class="text-h4 font-weight-bold text-primary">{{ t('app.name') }}</div>
            <div class="text-subtitle-2 text-medium-emphasis mt-2">{{ t('app.slogan') }}</div>
          </v-card-title>

          <v-card-text>
            <v-form @submit.prevent="handleLogin">
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
                v-model="form.password"
                :label="t('auth.password')"
                prepend-inner-icon="mdi-lock"
                type="password"
                variant="outlined"
                required
                :error-messages="errors.password"
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
                {{ t('auth.login') }}
              </v-btn>
            </v-form>

            <v-alert v-if="errorMessage" type="error" class="mt-4" closable>
              {{ errorMessage }}
            </v-alert>
          </v-card-text>

          <v-card-actions class="pa-4 pt-0">
            <span class="text-body-2 text-medium-emphasis">{{ t('auth.noAccount') }}</span>
            <v-btn variant="text" color="primary" to="/register" class="ms-1">
              {{ t('auth.registerNow') }}
            </v-btn>
          </v-card-actions>
        </v-card>
      </v-container>
    </v-main>
  </v-app>
</template>

<script setup lang="ts">
import { ref, reactive } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import { useUserStore } from '@/stores/user'
import { hashPassword } from '@/utils/crypto'

const router = useRouter()
const userStore = useUserStore()
const { t } = useI18n()

const form = reactive({
  username: '',
  password: '',
})

const errors = reactive({
  username: '',
  password: '',
})

const loading = ref(false)
const errorMessage = ref('')

const handleLogin = async () => {
  // 清空错误
  errors.username = ''
  errors.password = ''
  errorMessage.value = ''

  // 验证
  let hasError = false
  if (!form.username) {
    errors.username = t('auth.usernameRequired')
    hasError = true
  }
  if (!form.password) {
    errors.password = t('auth.passwordRequired')
    hasError = true
  }

  if (hasError) return

  loading.value = true
  try {
    // 在前端加密密码
    const passwordHash = hashPassword(form.password)
    await userStore.login(form.username, passwordHash)
    router.push('/')
  } catch (error: any) {
    errorMessage.value = error.response?.data?.detail || t('auth.loginFailed')
  } finally {
    loading.value = false
  }
}
</script>
