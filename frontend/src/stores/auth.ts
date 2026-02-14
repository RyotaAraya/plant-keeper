import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import api from '@/api/axios'
import type { User } from '@/types/models'

export const useAuthStore = defineStore('auth', () => {
  const user = ref<User | null>(null)

  const isLoggedIn = computed(() => user.value !== null)

  async function login(email: string, password: string) {
    const response = await api.post('/login', { user: { email, password } })
    user.value = response.data.user
  }

  async function logout() {
    await api.delete('/logout')
    user.value = null
    localStorage.removeItem('jwt')
  }

  async function fetchCurrentUser() {
    const response = await api.get('/current_user')
    user.value = response.data.user
  }

  async function initialize() {
    const token = localStorage.getItem('jwt')
    if (token) {
      try {
        await fetchCurrentUser()
      } catch {
        localStorage.removeItem('jwt')
        user.value = null
      }
    }
  }

  return { user, isLoggedIn, login, logout, fetchCurrentUser, initialize }
})
