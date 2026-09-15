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

const painPoints = [
  { icon: 'mdi-file-document-alert-outline', text: '最新版かわからない回路図。手書きの追記だけが残り、更新されないまま放置された図面' },
  { icon: 'mdi-file-image-outline', text: '紙の記録とデータの二重管理。検索性の低いスキャン画像の山' },
  { icon: 'mdi-clipboard-text-multiple-outline', text: '何重にもなったチェックリストと、ハンコリレーによる承認フロー' },
]

const GITHUB_URL = 'https://github.com/RyotaAraya/plant-keeper'
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

    <!-- 開発の背景 -->
    <section class="px-4 px-sm-8 py-12 py-sm-16">
      <v-container>
        <v-row justify="center">
          <v-col cols="12" md="10" lg="8">
            <v-chip color="primary" variant="tonal" size="small" class="mb-4">開発の背景</v-chip>
            <h2 class="text-h4 font-weight-bold mb-6">なぜPlantKeeperを作ったのか</h2>
            <p class="text-body-1 text-grey-darken-2 mb-6">
              石油プラントの現場で<strong>計装保全員として10年間</strong>、計器や自動制御機器の保守に携わってきました。
              その中でずっと感じていたのが、現場に根強く残る「非効率」でした。
            </p>
            <v-card variant="flat" rounded="lg" border class="pa-6 mb-6" color="surface-variant">
              <v-list density="comfortable" class="bg-transparent pa-0">
                <v-list-item v-for="point in painPoints" :key="point.text" class="px-0">
                  <template #prepend>
                    <v-icon color="warning" class="mr-3">{{ point.icon }}</v-icon>
                  </template>
                  <v-list-item-title class="text-body-2" style="white-space: normal">{{ point.text }}</v-list-item-title>
                </v-list-item>
              </v-list>
            </v-card>
            <p class="text-body-1 text-grey-darken-2 mb-4">
              朝会・夕会で使う進捗確認表をExcelで使いやすく作り替えたのがきっかけで、「業務改善そのもの」に楽しさを見出し、
              独学でプログラミングを学び始めました。現場を離れてからは、電力会社・SaaS企業でWebエンジニアとして
              開発・チーム運営に携わってきました。
            </p>
            <p class="text-body-1 text-grey-darken-2 font-weight-medium">
              PlantKeeperは、その原体験をもとに「現場が本当に使いたくなる保全システムとは何か」を考えながら設計した
              アプリケーションです。設備台帳・点検記録・トラブル管理・資材管理を紙とExcelから解放し、
              計装保全の実務で培った現場感覚をそのままシステム設計に落とし込みました。
            </p>
          </v-col>
        </v-row>
      </v-container>
    </section>

    <!-- CTA -->
    <section class="px-4 px-sm-8 py-12 py-sm-16" style="background: #F4F4F5">
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
      <div class="d-flex flex-wrap ga-2 justify-center mb-4">
        <v-chip v-for="tech in techStack" :key="tech" size="small" variant="outlined" color="grey-lighten-1">
          {{ tech }}
        </v-chip>
      </div>
      <v-btn
        :href="GITHUB_URL"
        target="_blank"
        rel="noopener"
        variant="text"
        size="small"
        prepend-icon="mdi-github"
        color="grey-lighten-1"
        class="mb-2"
      >
        Developed by Ryota Araya — GitHubでソースコードを見る
      </v-btn>
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
