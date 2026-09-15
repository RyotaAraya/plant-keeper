<script setup lang="ts">
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const authStore = useAuthStore()

function goToApp() {
  router.push(authStore.isLoggedIn ? '/dashboard' : '/login')
}

const featureGroups = [
  {
    icon: 'mdi-clipboard-check-outline',
    title: '保全管理',
    description: '設備台帳・点検記録・トラブル対応・定期整備のスケジュールまで、現場の保全業務を一元管理。',
    items: ['設備台帳・設備ツリー', 'チェックリスト点検・作業記録', 'トラブル報告〜対応完了の追跡', '定期整備のスケジュール管理'],
  },
  {
    icon: 'mdi-package-variant-closed',
    title: '資材管理',
    description: '型番・在庫・発注・修理の状況を拠点横断で把握し、資材切れや二重発注を防ぐ。',
    items: ['資材マスタ・代替品管理', '拠点別在庫・発注点アラート', '見積〜発注のステータス管理', '外部修理の送付・返却追跡'],
  },
  {
    icon: 'mdi-office-building-outline',
    title: '組織管理',
    description: '複数拠点・複数会社が関わる保全体制を、権限管理も含めて柔軟に表現。',
    items: ['6ロールのユーザー権限管理', '部→課→チームの組織階層', '複数拠点の横断管理', '操作履歴の監査ログ'],
  },
]

const techStack = ['Vue 3', 'TypeScript', 'Vuetify 3', 'Ruby on Rails 8', 'PostgreSQL']
</script>

<template>
  <v-main>
    <!-- ヘッダー -->
    <v-app-bar class="px-2 px-sm-6">
      <v-icon color="primary" size="28" class="mr-2">mdi-water-pump</v-icon>
      <span class="text-h6 font-weight-bold text-grey-darken-3">PlantKeeper</span>
      <v-spacer />
      <v-btn variant="text" color="primary" to="/login">ログイン</v-btn>
    </v-app-bar>

    <!-- ヒーロー -->
    <section class="hero-section px-4 px-sm-8 py-12 py-sm-16">
      <v-container>
        <v-row align="center" justify="center">
          <v-col cols="12" md="9" lg="7" class="text-center">
            <v-chip color="primary" variant="tonal" size="small" class="mb-4">
              石油プラント保全業務の統合管理
            </v-chip>
            <h1 class="text-h3 text-sm-h2 font-weight-bold mb-4" style="line-height: 1.3">
              現場の保全業務を、<br class="d-none d-sm-block" />まるごと一つに。
            </h1>
            <p class="text-body-1 text-grey-darken-2 mb-8 mx-auto" style="max-width: 640px">
              設備台帳・点検記録・トラブル管理・資材管理をバラバラのExcelや紙から解放。
              計装保全の実務経験をもとに設計した、プラント保全のドメインに特化したWebアプリケーションです。
            </p>
            <v-btn
              color="primary"
              size="x-large"
              class="px-8"
              append-icon="mdi-arrow-right"
              @click="goToApp"
            >
              デモアカウントで試す
            </v-btn>
            <div class="text-caption text-grey mt-4">
              <v-icon size="14" class="mr-1">mdi-information-outline</v-icon>
              登録不要。ログイン画面のデモアカウント一覧からクリックするだけで、すぐに操作を試せます。
            </div>
          </v-col>
        </v-row>
      </v-container>
    </section>

    <!-- 機能紹介 -->
    <section class="px-4 px-sm-8 py-12 py-sm-16" style="background: #F4F4F5">
      <v-container>
        <div class="text-center mb-10">
          <h2 class="text-h4 font-weight-bold mb-2">主な機能</h2>
          <p class="text-body-2 text-grey-darken-1">現場から本社まで、保全にまつわる情報をひとつのシステムに集約</p>
        </div>
        <v-row>
          <v-col v-for="group in featureGroups" :key="group.title" cols="12" md="4">
            <v-card variant="flat" class="pa-6 h-100" rounded="lg" border>
              <v-avatar color="primary" variant="tonal" size="48" class="mb-4">
                <v-icon size="26">{{ group.icon }}</v-icon>
              </v-avatar>
              <h3 class="text-h6 font-weight-bold mb-2">{{ group.title }}</h3>
              <p class="text-body-2 text-grey-darken-1 mb-4">{{ group.description }}</p>
              <v-list density="compact" class="bg-transparent pa-0">
                <v-list-item v-for="item in group.items" :key="item" class="px-0 min-height-0">
                  <template #prepend>
                    <v-icon size="16" color="success" class="mr-2">mdi-check-circle</v-icon>
                  </template>
                  <v-list-item-title class="text-body-2">{{ item }}</v-list-item-title>
                </v-list-item>
              </v-list>
            </v-card>
          </v-col>
        </v-row>
      </v-container>
    </section>

    <!-- CTA -->
    <section class="px-4 px-sm-8 py-12 py-sm-16">
      <v-container>
        <v-card color="primary" class="pa-8 pa-sm-12 text-center" border="0">
          <h2 class="text-h4 font-weight-bold text-white mb-3">今すぐ触って試せます</h2>
          <p class="text-body-1 mb-6" style="color: rgba(255,255,255,0.85)">
            ログイン画面に用意されたデモアカウントをクリックするだけで、管理者権限のダッシュボードから全機能を確認いただけます。
          </p>
          <v-btn color="white" size="x-large" class="px-8 text-primary" @click="goToApp">
            ログイン画面へ
          </v-btn>
        </v-card>
      </v-container>
    </section>

    <!-- フッター -->
    <v-footer class="d-flex flex-column py-6 px-4" color="grey-darken-4">
      <div class="d-flex flex-wrap ga-2 justify-center mb-3">
        <v-chip v-for="tech in techStack" :key="tech" size="small" variant="outlined" color="grey-lighten-1">
          {{ tech }}
        </v-chip>
      </div>
      <div class="text-caption text-grey-lighten-1">© {{ new Date().getFullYear() }} PlantKeeper</div>
    </v-footer>
  </v-main>
</template>

<style scoped>
.hero-section {
  background: linear-gradient(180deg, #EEF2FF 0%, #FAFAFA 100%);
}
.min-height-0 {
  min-height: 0;
}
</style>
