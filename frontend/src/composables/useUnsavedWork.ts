import { onBeforeUnmount, onMounted, type Ref } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { onBeforeRouteLeave, onBeforeRouteUpdate } from 'vue-router'

export function useUnsavedWork(dirty: Readonly<Ref<boolean>>) {
  const auth = useAuthStore()
  const confirmDiscard = () => !auth.isLoggedIn || !dirty.value || window.confirm('未保存の入力があります。破棄して移動しますか？')
  onBeforeRouteLeave(confirmDiscard)
  onBeforeRouteUpdate((to, from) => to.path === from.path || confirmDiscard())
  function beforeUnload(event: BeforeUnloadEvent) {
    if (!dirty.value) return
    event.preventDefault()
    event.returnValue = ''
  }
  onMounted(() => window.addEventListener('beforeunload', beforeUnload))
  onBeforeUnmount(() => window.removeEventListener('beforeunload', beforeUnload))
}
