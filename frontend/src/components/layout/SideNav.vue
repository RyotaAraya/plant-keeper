<script setup lang="ts">
import { useRoute } from 'vue-router'
import { useNavigation } from '@/composables/useNavigation'
import { useDisplay } from 'vuetify'
import PlanaAvatar from '@/components/plana/PlanaAvatar.vue'

const route = useRoute()
const { mobile } = useDisplay()

defineProps<{
  modelValue: boolean
}>()

defineEmits<{
  'update:modelValue': [value: boolean]
}>()

const { visibleGroups } = useNavigation()

// 詳細画面（/sites/:id 等）は一覧と別ルートのため、Vue Routerの自動判定だけでは
// アクティブ表示が外れてしまう。パスの前方一致で明示的に判定する。
function isItemActive(path: string) {
  return route.path === path || route.path.startsWith(`${path}/`)
}
</script>

<template>
  <v-navigation-drawer
    :model-value="modelValue"
    :permanent="!mobile"
    :temporary="mobile"
    class="pk-sidenav"
    aria-label="業務メニュー"
    width="248"
    @update:model-value="$emit('update:modelValue', $event)"
  >
    <div class="pk-sidenav__brand">
      <v-icon size="26" color="primary">mdi-gauge-full</v-icon>
      <span class="pk-sidenav__brand-text">PlantKeeper</span>
    </div>
    <v-list nav density="compact" class="pk-sidenav__list">
      <template v-for="group in visibleGroups" :key="group.label ?? 'top'">
        <v-list-subheader v-if="group.label" class="pk-sidenav__group">{{ group.label }}</v-list-subheader>
        <v-list-item
          v-for="item in group.items"
          :key="item.title"
          :to="item.to"
          :active="isItemActive(item.to)"
          :aria-current="isItemActive(item.to) ? 'page' : undefined"
          :prepend-icon="item.icon"
          :title="item.title"
          class="pk-sidenav__item"
        />
      </template>
    </v-list>
    <!-- プラナは記録や調べものを手伝う入口のため、仕事の流れ・台帳のあとに置く -->
    <router-link to="/plana" class="pk-sidenav__assistant" :aria-current="route.path === '/plana' ? 'page' : undefined">
      <PlanaAvatar :size="38" />
      <span><strong>プラナ</strong><small>記録と調べもの</small></span>
      <v-icon size="16" aria-hidden="true">mdi-chevron-right</v-icon>
    </router-link>
  </v-navigation-drawer>
</template>

<style scoped>
.pk-sidenav {
  background: #fff !important;
  border-right: 1px solid var(--pk-line) !important;
}

.pk-sidenav__brand {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 1.1rem 1.25rem;
}

.pk-sidenav__brand-text {
  font-family: var(--pk-font-display);
  font-weight: 700;
  font-size: 1.2rem;
  color: var(--pk-plana-navy);
  letter-spacing: 0.01em;
}

.pk-sidenav__list {
  padding: 0.5rem 0.75rem 1rem;
}

.pk-sidenav__assistant { display: flex; align-items: center; gap: 0.55rem; margin: 0 0.75rem 1rem; padding: 0.85rem 0.65rem; background: var(--pk-soft-blue); border-radius: 14px; color: var(--pk-plana-navy); text-decoration: none; }
.pk-sidenav__assistant strong { display: block; font-size: 0.875rem; }
.pk-sidenav__assistant small { display: block; margin-top: 0.15rem; font-size: 0.65rem; color: var(--pk-muted); }
.pk-sidenav__assistant:focus-visible { outline: 2px solid var(--pk-steel); outline-offset: 3px; }
.pk-sidenav__assistant[aria-current="page"] { box-shadow: inset 3px 0 var(--pk-steel); }
.pk-sidenav__assistant:hover { outline: 1px solid var(--pk-steel); }

/* グループ見出し。項目より一段静かにし、右へ伸びる細線でグループの区切りを示す */
.pk-sidenav__group {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  min-height: 0 !important;
  margin-top: 0.75rem;
  padding: 0.5rem 0.75rem 0.25rem !important;
  font-size: 0.72rem !important;
  font-weight: 700;
  letter-spacing: 0;
  color: var(--pk-muted) !important;
  opacity: 1 !important;
}

.pk-sidenav__group::after {
  content: '';
  flex: 1;
  height: 1px;
  background: var(--pk-line);
}

.pk-sidenav__item {
  border-radius: 10px;
  color: var(--pk-muted) !important;
  min-height: 36px;
  margin-bottom: 2px;
}

.pk-sidenav__item :deep(.v-icon) {
  color: var(--pk-muted);
  transition: color 0.15s ease;
}

.pk-sidenav__item:hover {
  background: var(--pk-mist);
  color: var(--pk-steel) !important;
}

.pk-sidenav__item:hover :deep(.v-icon) {
  color: var(--pk-steel);
}

.pk-sidenav__item.v-list-item--active {
  background: var(--pk-soft-blue) !important;
  color: var(--pk-steel-dark) !important;
  font-weight: 700;
}

.pk-sidenav__item.v-list-item--active :deep(.v-icon) {
  color: var(--pk-steel);
}
</style>
