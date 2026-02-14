import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import api from '@/api/axios'
import type { User } from '@/types/models'

export const useAuthStore = defineStore('auth', () => {
  const user = ref<User | null>(null)
  const initialized = ref(false)

  const isLoggedIn = computed(() => user.value !== null)

  async function login(email: string, password: string) {
    const response = await api.post('/login', { user: { email, password } })
    user.value = response.data.user
    if (response.data.token) {
      localStorage.setItem('jwt', response.data.token)
    }
  }

  async function logout() {
    try {
      await api.delete('/logout')
    } catch {
      // ignore logout errors
    }
    user.value = null
    localStorage.removeItem('jwt')
  }

  async function fetchCurrentUser() {
    const response = await api.get('/current_user')
    user.value = response.data.user
  }

  let initPromise: Promise<void> | null = null

  function initialize() {
    if (initPromise) return initPromise
    initPromise = _doInit()
    return initPromise
  }

  async function _doInit() {
    if (initialized.value) return
    const token = localStorage.getItem('jwt')
    if (token) {
      try {
        await fetchCurrentUser()
      } catch {
        localStorage.removeItem('jwt')
        user.value = null
      }
    }
    initialized.value = true
  }

  return { user, isLoggedIn, initialized, login, logout, fetchCurrentUser, initialize }
})
