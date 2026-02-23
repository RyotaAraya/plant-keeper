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
      path: '/inspections',
      name: 'Inspections',
      component: () => import('@/views/inspections/InspectionListView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/inspections/new',
      name: 'InspectionNew',
      component: () => import('@/views/inspections/InspectionFormView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/inspections/:id',
      name: 'InspectionDetail',
      component: () => import('@/views/inspections/InspectionDetailView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/inspections/:id/edit',
      name: 'InspectionEdit',
      component: () => import('@/views/inspections/InspectionFormView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/troubles',
      name: 'Troubles',
      component: () => import('@/views/troubles/TroubleListView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/troubles/:id',
      name: 'TroubleDetail',
      component: () => import('@/views/troubles/TroubleDetailView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/maintenances',
      name: 'Maintenances',
      component: () => import('@/views/maintenances/MaintenanceListView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/maintenances/:id',
      name: 'MaintenanceDetail',
      component: () => import('@/views/maintenances/MaintenanceDetailView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/materials',
      name: 'Materials',
      component: () => import('@/views/materials/MaterialListView.vue'),
      meta: { requiresAuth: true, requiresNonWorker: true },
    },
    {
      path: '/materials/:id',
      name: 'MaterialDetail',
      component: () => import('@/views/materials/MaterialDetailView.vue'),
      meta: { requiresAuth: true, requiresNonWorker: true },
    },
    {
      path: '/stocks',
      name: 'Stocks',
      component: () => import('@/views/stocks/StockListView.vue'),
      meta: { requiresAuth: true, requiresOwner: true },
    },
    {
      path: '/stocks/:id',
      name: 'StockDetail',
      component: () => import('@/views/stocks/StockDetailView.vue'),
      meta: { requiresAuth: true, requiresOwner: true },
    },
    {
      path: '/orders',
      name: 'Orders',
      component: () => import('@/views/orders/OrderListView.vue'),
      meta: { requiresAuth: true, requiresOwnerManager: true },
    },
    {
      path: '/users',
      name: 'Users',
      component: () => import('@/views/users/UserListView.vue'),
      meta: { requiresAuth: true, requiresAdmin: true },
    },
    {
      path: '/users/:id',
      name: 'UserDetail',
      component: () => import('@/views/users/UserDetailView.vue'),
      meta: { requiresAuth: true, requiresAdmin: true },
    },
    {
      path: '/audit-logs',
      name: 'AuditLogs',
      component: () => import('@/views/audit/AuditLogView.vue'),
      meta: { requiresAuth: true, requiresAdmin: true },
    },
    {
      path: '/settings',
      name: 'Settings',
      component: () => import('@/views/settings/SettingsView.vue'),
      meta: { requiresAuth: true, requiresAdmin: true },
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

  if (authStore.isLoggedIn) {
    const user = authStore.user
    const role = user?.system_role
    const companyType = user?.company?.company_type

    if (to.meta.requiresAdmin && role !== 'admin') {
      return { path: '/' }
    }
    if (to.meta.requiresOwner && companyType !== 'owner') {
      return { path: '/' }
    }
    if (to.meta.requiresOwnerManager && !(role === 'admin' || (role === 'manager' && companyType === 'owner'))) {
      return { path: '/' }
    }
    if (to.meta.requiresNonWorker && role === 'worker') {
      return { path: '/' }
    }
  }
})

export default router
