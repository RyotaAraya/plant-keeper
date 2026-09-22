import { onBeforeUnmount, onMounted, type Ref } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { onBeforeRouteLeave, onBeforeRouteUpdate } from 'vue-router'

const activeDirtyStates = new Set<Readonly<Ref<boolean>>>()

export function confirmUnsavedWork() {
  return ![...activeDirtyStates].some((state) => state.value)
    || window.confirm('未保存の入力があります。破棄して移動しますか？')
}

export function useUnsavedWork(dirty: Readonly<Ref<boolean>>) {
  const auth = useAuthStore()
  const confirmDiscard = () => !auth.isLoggedIn || confirmUnsavedWork()
  onBeforeRouteLeave(confirmDiscard)
  onBeforeRouteUpdate((to, from) => to.path === from.path || confirmDiscard())
  function beforeUnload(event: BeforeUnloadEvent) {
    if (!dirty.value) return
    event.preventDefault()
    event.returnValue = ''
  }
  onMounted(() => {
    activeDirtyStates.add(dirty)
    window.addEventListener('beforeunload', beforeUnload)
  })
  onBeforeUnmount(() => {
    activeDirtyStates.delete(dirty)
    window.removeEventListener('beforeunload', beforeUnload)
  })
}
