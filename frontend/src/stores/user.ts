// stores/user.ts
import { defineStore } from 'pinia'
import { ref, computed, watch } from 'vue'
import type { User } from '@/types'
import { api } from '@/api'
import { useLocaleStore } from '@/stores/locale'
import i18n from '@/plugins/i18n'
import { localUserNickname } from '@/utils/localDisplay'
import { CHINESE_JIN_NAME } from '@/data/localValues'

export const useUserStore = defineStore('user', () => {
  // ---- Local mode: return a fixed admin user without API calls ----
  if (import.meta.env.VITE_STORAGE_MODE === 'local') {
    const createLocalUserData = (): User => {
      return {
        id: 1,
        username: 'local',
        email: 'local@local.dev',
        phone: null,
        is_admin: true,
        is_active: true,
        email_verified: true,
        avatar: null,
        nickname: localUserNickname(),
        created_at: new Date().toISOString(),
        nutrition_goals: null,
        daily_budget: null,
        unit_preferences: {
          energy_unit: 'kcal',
          mass_unit: { id: 3, name: CHINESE_JIN_NAME, abbreviation: CHINESE_JIN_NAME },
          volume_unit: null,
          price_unit: { id: 3, name: CHINESE_JIN_NAME, abbreviation: CHINESE_JIN_NAME },
        },
        region_id: null,
        default_currency: null,
        default_calc_scope: null,
        locale: null,
        format_locale: null,
      }
    }

    const user = ref<User | null>(createLocalUserData())
    const token = ref<string | null>('local-mode')

    watch(() => i18n.global.locale.value, () => {
      user.value = createLocalUserData()
    })

    return {
      user,
      token,
      isLoggedIn: computed(() => true),
      fetchUser: async () => {},
      setTokens: () => {},
      login: async () => { user.value = createLocalUserData(); token.value = 'local-mode' },
      register: async () => { user.value = createLocalUserData(); token.value = 'local-mode' },
      logout: () => { user.value = null; token.value = null },
    }
  }

  // ---- Cloud/normal mode ----
  const user = ref<User | null>(null)
  const token = ref<string | null>(localStorage.getItem('access_token'))

  const isLoggedIn = computed(() => !!token.value)

  async function fetchUser() {
    if (!token.value) return
    try {
      const data = await api.get('/auth/me')
      user.value = data
      const localeStore = useLocaleStore()
      localeStore.syncFromUser(data)
    } catch (error) {
      console.error('Failed to fetch user:', error)
    }
  }

  function setTokens(access: string, refresh: string) {
    token.value = access
    localStorage.setItem('access_token', access)
    localStorage.setItem('refresh_token', refresh)
  }

  async function login(username: string, passwordHash: string) {
    const data = await api.post('/auth/login', { username, password_hash: passwordHash })
    setTokens(data.access_token, data.refresh_token)
    await fetchUser()
  }

  async function register(username: string, email: string, passwordHash: string, inviteCode?: string) {
    const data = await api.post('/auth/register', {
      username,
      email,
      password_hash: passwordHash,
      invite_code: inviteCode,
    })
    setTokens(data.access_token, data.refresh_token)
    await fetchUser()
  }

  function logout() {
    user.value = null
    token.value = null
    localStorage.removeItem('access_token')
    localStorage.removeItem('refresh_token')
  }

  return {
    user,
    token,
    isLoggedIn,
    fetchUser,
    setTokens,
    login,
    register,
    logout,
  }
})
