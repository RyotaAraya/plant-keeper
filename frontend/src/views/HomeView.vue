<script setup lang="ts">
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import HeroCanvas from '@/components/home/HeroCanvas.vue'
import equipmentsShot from '@/assets/screenshots/equipments.png'
import materialsShot from '@/assets/screenshots/materials.png'
import departmentsShot from '@/assets/screenshots/departments.png'
import dashboardShot from '@/assets/screenshots/dashboard.png'

const router = useRouter()
const authStore = useAuthStore()

function goToApp() {
  router.push(authStore.isLoggedIn ? '/dashboard' : '/login')
}

const featureGroups = [
  {
    key: 'maintenance',
    icon: 'mdi-clipboard-check-outline',
    title: '保全管理',
    description: '設備台帳・点検記録・トラブル対応・定期整備のスケジュールまで、現場の保全業務を一元管理。',
    shot: equipmentsShot,
    shotAlt: '設備台帳画面のスクリーンショット。常圧蒸留装置や流動接触分解装置などの設備一覧が並ぶ',
    shotCaption: '実際の設備台帳画面',
  },
  {
    key: 'materials',
    icon: 'mdi-package-variant-closed',
    title: '資材管理',
    description: '型番・在庫・発注・修理の状況を拠点横断で把握し、資材切れや二重発注を防ぐ。',
    shot: materialsShot,
    shotAlt: '資材管理画面のスクリーンショット。ガスケットやパッキンなどの資材が型番付きで並ぶ',
    shotCaption: '実際の資材管理画面',
  },
  {
    key: 'organization',
    icon: 'mdi-office-building-outline',
    title: '組織管理',
    description: '複数拠点・複数会社が関わる保全体制を、権限管理も含めて柔軟に表現。',
    shot: departmentsShot,
    shotAlt: '部署管理画面のスクリーンショット。保全部の下に検査課・計器保全課などが階層表示されている',
    shotCaption: '実際の部署管理画面',
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
    <v-app-bar class="px-2 px-sm-6" color="ink" theme="dark">
      <v-icon color="#E7B778" size="24" class="mr-2">mdi-gauge-full</v-icon>
      <span class="pk-navbrand">PlantKeeper</span>
      <v-spacer />
      <v-btn variant="outlined" color="#E7B778" to="/login">ログイン</v-btn>
    </v-app-bar>

    <!-- ヒーロー -->
    <section class="pk-hero">
      <HeroCanvas />
      <div class="pk-hero__scrim" />
      <v-container fluid class="pk-hero__content">
        <h1 class="pk-hero__brand">PlantKeeper</h1>
        <p class="pk-hero__tagline">
          現場の保全業務を、まるごと一つに。
        </p>
        <v-btn color="accent" size="x-large" class="px-8" @click="goToApp">
          デモアカウントで試す
        </v-btn>
        <div class="pk-hero__note">
          登録不要。ログイン画面のデモアカウント一覧からクリックするだけで操作を試せます。
        </div>
      </v-container>
    </section>

    <!-- 機能紹介 -->
    <section class="px-4 px-sm-8 py-12 py-sm-16">
      <v-container>
        <div class="mb-10">
          <h2 class="text-h4 font-weight-bold mb-2">主な機能</h2>
          <p class="text-body-2 text-medium-emphasis">現場から本社まで、保全にまつわる情報をひとつのシステムに集約</p>
        </div>
        <v-row>
          <v-col v-for="group in featureGroups" :key="group.title" cols="12" md="4">
            <v-card variant="flat" class="pa-6 h-100 pk-feature-card" border>
              <div class="pk-feature-icon">
                <v-icon color="primary" size="22">{{ group.icon }}</v-icon>
              </div>
              <h3 class="text-h6 font-weight-bold mb-2">{{ group.title }}</h3>
              <p class="text-body-2 text-medium-emphasis mb-4">{{ group.description }}</p>

              <figure class="pk-shot">
                <div class="pk-shot__frame">
                  <img :src="group.shot" :alt="group.shotAlt" class="pk-shot__img" loading="lazy" />
                  <div class="pk-shot__fade" />
                </div>
                <figcaption class="pk-shot__caption">{{ group.shotCaption }}</figcaption>
              </figure>
            </v-card>
          </v-col>
        </v-row>
      </v-container>
    </section>

    <!-- 開発の背景 -->
    <section class="px-4 px-sm-8 py-12 py-sm-16 pk-story">
      <v-container>
        <v-row justify="center">
          <v-col cols="12" md="10" lg="8">
            <h2 class="text-h4 font-weight-bold mb-10">なぜPlantKeeperを作ったのか</h2>

            <ol class="pk-timeline">
              <li class="pk-timeline__item">
                <span class="pk-timeline__dot" />
                <div class="pk-timeline__label pk-mono">計装保全員として10年</div>
                <p class="text-body-1 text-medium-emphasis mb-4">
                  石油プラントの現場で計器や自動制御機器の保守に携わってきました。
                  その中でずっと感じていたのが、現場に根強く残る「非効率」でした。
                </p>
                <v-card variant="flat" border class="pa-6 mb-4" color="surface-variant">
                  <ul class="pk-pain-list">
                    <li v-for="point in painPoints" :key="point.text">
                      <v-icon color="warning" class="mr-3">{{ point.icon }}</v-icon>
                      <span class="text-body-2">{{ point.text }}</span>
                    </li>
                  </ul>
                </v-card>
                <p class="text-body-2 text-medium-emphasis">
                  これらをすべて一度に解決するのは現実的ではないと考え、PlantKeeperでは
                  <strong class="text-high-emphasis">点検記録のチェックリスト化と承認フローの簡略化</strong>、
                  <strong class="text-high-emphasis">設備台帳・トラブル管理・資材管理の一元化</strong>にスコープを絞って実装しています。
                  回路図面のバージョン管理や、紙資料をスキャンした画像の検索性改善は、今回は対象外としました。
                </p>
              </li>

              <li class="pk-timeline__item">
                <span class="pk-timeline__dot" />
                <div class="pk-timeline__label pk-mono">小さな気づきから独学へ</div>
                <p class="text-body-1 text-medium-emphasis">
                  朝会・夕会で使う進捗確認表をExcelで使いやすく作り替えたのがきっかけで、「業務改善そのもの」に楽しさを見出し、
                  独学でプログラミングを学び始めました。
                </p>
              </li>

              <li class="pk-timeline__item">
                <span class="pk-timeline__dot" />
                <div class="pk-timeline__label pk-mono">エンジニアとしてのキャリア</div>
                <p class="text-body-1 text-medium-emphasis">
                  現場を離れてからは、電力会社・SaaS企業でWebエンジニアとして開発・チーム運営に携わってきました。
                </p>
              </li>

              <li class="pk-timeline__item pk-timeline__item--last">
                <span class="pk-timeline__dot pk-timeline__dot--accent" />
                <div class="pk-timeline__label pk-mono">そして、PlantKeeperへ</div>
                <p class="text-body-1 font-weight-medium">
                  その原体験をもとに「現場が本当に使いたくなる保全システムとは何か」を考えながら設計したアプリケーションです。
                  設備台帳・点検記録・トラブル管理・資材管理を紙とExcelから解放し、
                  計装保全の実務で培った現場感覚をそのままシステム設計に落とし込みました。
                </p>
              </li>
            </ol>
          </v-col>
        </v-row>
      </v-container>
    </section>

    <!-- CTA -->
    <section class="px-4 px-sm-8 py-12 py-sm-16">
      <v-container>
        <v-card color="ink" theme="dark" class="pa-8 pa-sm-12">
          <div class="pk-cta">
            <div class="pk-cta__text">
              <h2 class="text-h4 font-weight-bold mb-3">今すぐ触って試せます</h2>
              <p class="text-body-1 mb-6" style="color: rgba(255, 255, 255, 0.78)">
                ログイン画面に用意されたデモアカウントをクリックするだけで、管理者権限のダッシュボードから全機能を確認いただけます。
              </p>
              <v-btn color="accent" size="x-large" class="px-8" @click="goToApp">
                ログイン画面へ
              </v-btn>
            </div>
            <div class="pk-cta__shot">
              <img
                :src="dashboardShot"
                alt="ログイン後のダッシュボード画面のスクリーンショット。未対応トラブルや在庫アラートなどが一覧表示されている"
                class="pk-cta__shot-img"
                loading="lazy"
              />
            </div>
          </div>
        </v-card>
      </v-container>
    </section>

    <!-- フッター -->
    <v-footer class="d-flex flex-column py-6 px-4" color="ink" theme="dark">
      <div class="d-flex flex-wrap ga-2 justify-center mb-4">
        <span v-for="tech in techStack" :key="tech" class="pk-mono pk-tech-chip">{{ tech }}</span>
      </div>
      <div class="text-caption text-grey-lighten-1 mb-1">Developed by Ryota Araya</div>
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
        GitHubでソースコードを見る
      </v-btn>
      <div class="text-caption text-grey-lighten-1">© {{ new Date().getFullYear() }} PlantKeeper</div>
    </v-footer>
  </v-main>
</template>

<style scoped>
.pk-navbrand {
  font-family: var(--pk-font-display);
  font-weight: 700;
  font-size: 1.05rem;
}

.pk-hero {
  position: relative;
  min-height: min(86vh, 720px);
  display: flex;
  align-items: flex-end;
  overflow: hidden;
  background: var(--pk-ink);
  padding-bottom: clamp(3rem, 9vh, 6rem);
}

.pk-hero__scrim {
  position: absolute;
  inset: 0;
  background: linear-gradient(100deg, rgba(23, 34, 43, 0.82) 0%, rgba(23, 34, 43, 0.45) 42%, rgba(23, 34, 43, 0.08) 78%);
  pointer-events: none;
}

@media (max-width: 900px) {
  .pk-hero__scrim {
    background: linear-gradient(180deg, rgba(23, 34, 43, 0.5) 0%, rgba(23, 34, 43, 0.8) 100%);
  }
}

.pk-hero__content {
  position: relative;
  z-index: 1;
  max-width: 720px;
  width: 100%;
  padding-left: clamp(1.5rem, 7vw, 6.5rem) !important;
  padding-right: clamp(1.5rem, 6vw, 3rem) !important;
}

.pk-hero__brand {
  font-family: var(--pk-font-display);
  font-weight: 900;
  color: #f5f6f5;
  font-size: clamp(2rem, 11vw, 6.5rem);
  line-height: 1;
  letter-spacing: -0.01em;
  margin-bottom: 0.75rem;
}

.pk-hero__tagline {
  font-family: var(--pk-font-display);
  font-weight: 500;
  font-size: clamp(1.05rem, 2.6vw, 1.6rem);
  color: rgba(245, 246, 245, 0.8);
  margin-bottom: 2rem;
}

.pk-hero__note {
  margin-top: 1rem;
  font-size: 0.8rem;
  color: rgba(245, 246, 245, 0.65);
}

.pk-feature-card {
  border-color: var(--pk-line) !important;
}

.pk-feature-icon {
  width: 44px;
  height: 44px;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 1px solid var(--pk-line);
  background: var(--pk-mist);
  margin-bottom: 1rem;
}

.pk-pain-list {
  list-style: none;
  margin: 0;
  padding: 0;
}

.pk-pain-list li {
  display: flex;
  align-items: flex-start;
  padding: 0.25rem 0;
}

.pk-shot {
  margin: 0;
  border: 1px solid var(--pk-line);
  background: #fff;
}

.pk-shot__frame {
  position: relative;
  height: 190px;
  overflow: hidden;
  background: var(--pk-mist);
}

.pk-shot__img {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: auto;
  display: block;
}

.pk-shot__fade {
  position: absolute;
  inset: auto 0 0 0;
  height: 2.5rem;
  background: linear-gradient(to bottom, rgba(255, 255, 255, 0), #fff);
}

.pk-shot__caption {
  padding: 0.5rem 0.75rem;
  font-size: 0.7rem;
  color: #8a9296;
  border-top: 1px solid var(--pk-line);
}

.pk-story {
  background: var(--pk-mist);
}

.pk-timeline {
  list-style: none;
  margin: 0;
  padding: 0;
  position: relative;
}

.pk-timeline::before {
  content: '';
  position: absolute;
  left: 5px;
  top: 6px;
  bottom: 6px;
  width: 1px;
  background: var(--pk-line);
}

.pk-timeline__item {
  position: relative;
  padding-left: 2.25rem;
  padding-bottom: 3rem;
}

.pk-timeline__item--last {
  padding-bottom: 0;
}

.pk-timeline__dot {
  position: absolute;
  left: 0;
  top: 6px;
  width: 11px;
  height: 11px;
  border-radius: 50%;
  background: var(--pk-mist);
  border: 2px solid var(--pk-steel);
}

.pk-timeline__dot--accent {
  border-color: var(--pk-amber);
}

.pk-timeline__label {
  font-size: 0.8rem;
  color: var(--pk-steel);
  margin-bottom: 0.5rem;
}

.pk-tech-chip {
  font-size: 0.75rem;
  color: #cfd6d8;
  border: 1px solid rgba(255, 255, 255, 0.18);
  padding: 0.25rem 0.6rem;
}

.pk-cta {
  display: flex;
  align-items: center;
  gap: clamp(2rem, 5vw, 3.5rem);
}

.pk-cta__text {
  flex: 1 1 360px;
}

.pk-cta__shot {
  flex: 1 1 460px;
  width: 100%;
}

.pk-cta__shot-img {
  width: 100%;
  display: block;
  border: 1px solid rgba(255, 255, 255, 0.12);
  box-shadow: 0 30px 70px -25px rgba(0, 0, 0, 0.6);
}

@media (max-width: 900px) {
  .pk-cta {
    flex-direction: column;
    align-items: stretch;
  }
}
</style>
