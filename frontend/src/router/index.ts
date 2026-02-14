import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/login',
      name: 'Login',
      component: () => import('@/views/LoginView.vue'),
      meta: { guest: true },
    },
    {
      path: '/',
      name: 'Dashboard',
      component: () => import('@/views/DashboardView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/sites',
      name: 'Sites',
      component: () => import('@/views/sites/SiteListView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/sites/:id',
      name: 'SiteDetail',
      component: () => import('@/views/sites/SiteDetailView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/equipments',
      name: 'Equipments',
      component: () => import('@/views/equipments/EquipmentListView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/equipments/:id',
      name: 'EquipmentDetail',
      component: () => import('@/views/equipments/EquipmentDetailView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/instruments',
      name: 'Instruments',
      component: () => import('@/views/instruments/InstrumentListView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/instruments/:id',
      name: 'InstrumentDetail',
      component: () => import('@/views/instruments/InstrumentDetailView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/settings',
      name: 'Settings',
      component: () => import('@/views/settings/SettingsView.vue'),
      meta: { requiresAuth: true },
    },
  ],
})

router.beforeEach(async (to) => {
  const authStore = useAuthStore()

  // 初回アクセス時にトークンからユーザー情報を復元
  if (!authStore.initialized) {
    await authStore.initialize()
  }

  if (to.meta.requiresAuth && !authStore.isLoggedIn) {
    return { path: '/login' }
  }

  if (to.meta.guest && authStore.isLoggedIn) {
    return { path: '/' }
  }
})

export default router
