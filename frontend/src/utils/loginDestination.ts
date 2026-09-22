import type { Router } from 'vue-router'

// 認証後は、実在する保護されたアプリ内画面だけに戻る。
export function loginDestination(router: Router, value: unknown): string {
  if (typeof value !== 'string' || !value.startsWith('/') || value.startsWith('//') || /[\\\s]/.test(value)) return '/plana'
  const target = router.resolve(value)
  return target.matched.length && target.meta.requiresAuth ? target.fullPath : '/plana'
}
