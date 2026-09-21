<script setup lang="ts">
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import HeroCanvas from '@/components/home/HeroCanvas.vue'
import PermissionMatrix from '@/components/PermissionMatrix.vue'
import PlanaAvatar from '@/components/plana/PlanaAvatar.vue'
import PlanaConsultBar from '@/components/plana/PlanaConsultBar.vue'
import inspectionsShot from '@/assets/screenshots/inspections.png'
import materialsShot from '@/assets/screenshots/materials.png'
import departmentsShot from '@/assets/screenshots/departments.png'
import dashboardShot from '@/assets/screenshots/dashboard.png'
import aiDraftShot from '@/assets/screenshots/ai-draft.png'

const router = useRouter()
const authStore = useAuthStore()

function goToApp() {
  router.push(authStore.isLoggedIn ? '/dashboard' : '/login')
}

// ヒーローの「プラナ AI」から、すぐ下のプラナの帯へ移る（動きを減らす設定のときは、滑らかにスクロールしない）
function scrollToPlana() {
  const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches
  document.getElementById('plana')?.scrollIntoView({ behavior: reduced ? 'auto' : 'smooth', block: 'center' })
}

const featureGroups = [
  {
    key: 'maintenance',
    icon: 'mdi-clipboard-check-outline',
    title: '保全管理',
    description: '設備台帳・点検記録・トラブル対応・定期整備のスケジュールまで、現場の保全業務を一元管理。',
    shot: inspectionsShot,
    shotAlt: '点検・作業記録画面のスクリーンショット。減圧蒸留装置や接触改質装置などの点検記録が計器タグ番号・ステータス付きで並ぶ',
    shotCaption: '実際の点検・作業記録画面',
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
    shotAlt: '部署管理画面のスクリーンショット。保全部の下の計装保全課を選択し、所属チームとメンバー（鈴木一郎、課長）が表示されている',
    shotCaption: '実際の部署管理画面',
  },
  {
    key: 'ai',
    icon: '',
    title: 'プラナの提案',
    description: '点検中のメモから、トラブル報告の下書きを作ります。タイトル・優先度・推定原因の候補まで整えます。過去の類似トラブルの検索と、対応記録の下書きも、プラナが手伝います。',
    points: [
      'プラナは提案まで。入力欄に反映するかは、人が決めます',
      '応急処置の手順や、運転を続けてよいかの判断は出しません',
      '呼び出しは記録され、AIの案と確定した内容を突き合わせられます',
    ],
    shot: aiDraftShot,
    shotAlt: '点検記録の入力画面のスクリーンショット。現場メモの下に、AIの下書きが表示されている。タイトル・説明・優先度と、推定原因の候補、確認したい点が並び、「入力欄に反映」ボタンがある',
    shotCaption: '実際の点検記録の入力画面。「反映」を押すまで、入力欄は変わりません',
    fit: true,
  },
]

// 「主な機能」の頭に置く、保全業務でデータがつながる順。説明は、実装済みの動作だけを書く
const flowSteps = [
  { icon: 'mdi-factory', title: '設備', note: '設備台帳・計器・タグ番号' },
  { icon: 'mdi-clipboard-check-outline', title: '点検', note: 'チェックリストと承認' },
  { icon: 'mdi-alert-circle-outline', title: 'トラブル', note: '不具合から自動で登録' },
  { icon: 'mdi-hammer-wrench', title: '修理', note: '対応記録と修理の依頼' },
  { icon: 'mdi-package-variant', title: '資材', note: '型番の表記ゆれも検索' },
  { icon: 'mdi-warehouse', title: '在庫', note: '拠点をまたいで確認' },
  { icon: 'mdi-cart-outline', title: '発注', note: '受領すると在庫へ入庫' },
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
        <div class="pk-hero__layout">
          <div class="pk-hero__text">
            <h1 class="pk-hero__brand">PlantKeeper</h1>
            <p class="pk-hero__tagline">
              設備保全に必要な情報を、ひとつの場所へ。
            </p>
            <p class="pk-hero__lead">
              設備・点検・トラブル・修理・資材・在庫・発注まで、保全業務に必要な情報を一元管理します。
            </p>
            <button type="button" class="pk-hero__ai" @click="scrollToPlana">
              <PlanaAvatar :size="30" />
              <span class="pk-hero__ai-text"><strong>プラナ AI</strong>過去の記録から、次の判断をサポートします</span>
              <v-icon size="18" class="pk-hero__ai-chevron">mdi-chevron-down</v-icon>
            </button>
            <v-btn color="accent" size="x-large" class="px-8" @click="goToApp">
              デモアカウントで試す
            </v-btn>
            <div class="pk-hero__note">
              登録不要。ログイン画面のデモアカウント一覧からクリックするだけで操作を試せます。
            </div>
          </div>
          <div class="pk-hero__shot">
            <img
              :src="dashboardShot"
              alt="ログイン後のダッシュボード画面のスクリーンショット。未対応トラブルや在庫アラートなどが一覧表示されている"
              class="pk-hero__shot-img"
            />
          </div>
        </div>
      </v-container>
    </section>

    <!-- プラナ AI: PlantKeeperのAIアシスタント。主役は業務機能なので、帯は1つだけ・ヒーローの下に置く -->
    <section id="plana" class="pk-plana" aria-labelledby="plana-title">
      <svg class="pk-plana__skyline" viewBox="0 0 1440 220" preserveAspectRatio="xMidYMax slice" aria-hidden="true" focusable="false">
        <g fill="#fff" fill-opacity="0.16">
          <rect x="90" y="70" width="34" height="150" />
          <rect x="96" y="56" width="22" height="14" />
          <rect x="105" y="20" width="5" height="36" />
          <rect x="150" y="104" width="26" height="116" />
          <rect x="154" y="94" width="18" height="10" />
          <path d="M250 220V150q60-38 120 0v70z" />
          <rect x="420" y="84" width="30" height="136" />
          <rect x="425" y="70" width="20" height="14" />
          <rect x="470" y="112" width="22" height="108" />
          <rect x="474" y="30" width="6" height="82" />
          <path d="M560 220V160q52-30 104 0v70z" />
          <rect x="700" y="64" width="36" height="156" />
          <rect x="707" y="50" width="22" height="14" />
          <rect x="716" y="14" width="5" height="36" />
          <rect x="752" y="100" width="24" height="120" />
          <rect x="820" y="130" width="120" height="90" />
          <path d="M820 130q60-30 120 0z" />
          <rect x="1010" y="80" width="30" height="140" />
          <rect x="1015" y="66" width="20" height="14" />
          <rect x="1180" y="100" width="28" height="120" />
          <rect x="1184" y="88" width="20" height="12" />
          <rect x="1230" y="118" width="22" height="102" />
          <rect x="1300" y="150" width="140" height="70" />
          <path d="M1300 150q70-32 140 0z" />
        </g>
        <g fill="#12306b" fill-opacity="0.5">
          <rect x="0" y="192" width="1440" height="6" />
          <rect x="60" y="192" width="6" height="28" />
          <rect x="360" y="192" width="6" height="28" />
          <rect x="640" y="192" width="6" height="28" />
          <rect x="960" y="192" width="6" height="28" />
          <rect x="1260" y="192" width="6" height="28" />
          <circle cx="210" cy="200" r="20" />
          <circle cx="262" cy="204" r="16" />
          <circle cx="1090" cy="200" r="20" />
          <circle cx="1142" cy="204" r="16" />
          <rect x="0" y="210" width="1440" height="10" />
        </g>
        <!-- 遠くのフレアスタック。夕暮れの橙は、ロゴの橙 -->
        <rect x="1122" y="62" width="5" height="140" fill="#fff" fill-opacity="0.34" />
        <path d="M1124.5 30c8 10 10 18 3 28-3 4-9 4-12 0-6-8-2-18 9-28z" fill="#f3a340" />
      </svg>

      <div class="pk-plana__inner">
        <div class="pk-plana__figure">
          <PlanaAvatar variant="full" alt="プラナ。ヘルメットをかぶり、タブレットを持った、PlantKeeperのAIアシスタントのキャラクター" />
        </div>
        <div class="pk-plana__body">
          <h2 id="plana-title" class="pk-plana__title">プラナ <span class="pk-plana__badge">AI</span></h2>
          <p class="pk-plana__tagline">過去の記録から、次の判断をサポート。</p>
          <p class="pk-plana__lead">
            PlantKeeperに蓄積された設備・点検・トラブルなどの記録をもとに、情報の整理や過去事例の検索、報告の下書き作成などをサポートします。
          </p>
          <PlanaConsultBar tone="scene" />
          <p v-if="!authStore.isLoggedIn" class="pk-plana__note">プラナはログイン後に使えます。デモアカウントで、そのまま試せます。</p>
        </div>
      </div>
    </section>

    <!-- 機能紹介 -->
    <section class="px-4 px-sm-8 py-12 py-sm-16">
      <v-container>
        <div class="mb-10">
          <h2 class="text-h4 font-weight-bold mb-2">主な機能</h2>
          <p class="text-body-2 text-medium-emphasis">保全業務に必要な情報を、一つの流れで管理します。</p>
        </div>
        <ol class="pk-flow" aria-label="PlantKeeperで管理する保全業務の流れ">
          <li v-for="step in flowSteps" :key="step.title" class="pk-flow__step">
            <v-icon size="22" color="primary" aria-hidden="true">{{ step.icon }}</v-icon>
            <strong class="pk-flow__name">{{ step.title }}</strong>
            <span class="pk-flow__note">{{ step.note }}</span>
          </li>
        </ol>
        <div class="pk-feature-rows">
          <div v-for="group in featureGroups" :key="group.title" class="pk-feature-row">
            <div class="pk-feature-row__text">
              <div class="pk-feature-row__heading">
                <PlanaAvatar v-if="group.key === 'ai'" :size="26" />
                <v-icon v-else color="primary" size="22">{{ group.icon }}</v-icon>
                <h3 class="text-h6 font-weight-bold">{{ group.title }}</h3>
              </div>
              <p class="text-body-2 text-medium-emphasis">{{ group.description }}</p>
              <ul v-if="group.points" class="pk-feature-row__points">
                <li v-for="point in group.points" :key="point">{{ point }}</li>
              </ul>
            </div>

            <figure class="pk-shot pk-feature-row__shot">
              <div class="pk-shot__frame" :class="{ 'pk-shot__frame--fit': group.fit }">
                <img :src="group.shot" :alt="group.shotAlt" class="pk-shot__img" loading="lazy" />
                <div class="pk-shot__fade" />
              </div>
              <figcaption class="pk-shot__caption">{{ group.shotCaption }}</figcaption>
            </figure>
          </div>
        </div>
      </v-container>
    </section>

    <!-- 権限ごとにできること -->
    <section id="permissions" class="px-4 px-sm-8 py-12 py-sm-16 pk-permissions">
      <v-container>
        <div class="pk-permissions__intro mb-8">
          <h2 class="text-h4 font-weight-bold mb-2">権限ごとに、できることが違います</h2>
          <p class="text-body-2 text-medium-emphasis">
            自社と協力会社で、見られる範囲も操作できる範囲も分かれます。デモアカウントは、この5つの権限に1人ずつ用意しています。
          </p>
        </div>
        <PermissionMatrix />
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
                <p class="text-body-1 font-weight-medium mb-4">
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
        <v-card color="ink" theme="dark" class="pa-8 pa-sm-12 text-center">
          <h2 class="text-h4 font-weight-bold mb-3">今すぐ触って試せます</h2>
          <p class="text-body-1 mb-6" style="color: rgba(255, 255, 255, 0.78)">
            ログイン画面に用意されたデモアカウントをクリックするだけで、管理者権限のダッシュボードから全機能を確認いただけます。
          </p>
          <v-btn color="accent" size="x-large" class="px-8" @click="goToApp">
            ログイン画面へ
          </v-btn>
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
  max-width: 1240px;
  width: 100%;
  padding-left: clamp(1.5rem, 7vw, 6.5rem) !important;
  padding-right: clamp(1.5rem, 6vw, 3rem) !important;
}

.pk-hero__layout {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: clamp(2rem, 5vw, 4rem);
}

.pk-hero__text {
  flex: 1 1 480px;
  max-width: 560px;
}

.pk-hero__shot {
  flex: 1 1 520px;
  width: 100%;
}

.pk-hero__shot-img {
  width: 100%;
  display: block;
  border: 1px solid rgba(255, 255, 255, 0.12);
  box-shadow: 0 30px 70px -25px rgba(0, 0, 0, 0.6);
}

@media (max-width: 900px) {
  .pk-hero__layout {
    flex-direction: column;
    align-items: stretch;
  }

  .pk-hero__text,
  .pk-hero__shot {
    flex: 0 0 auto;
    max-width: none;
  }
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
  color: rgba(245, 246, 245, 0.88);
  margin-bottom: 0.6rem;
}

.pk-hero__lead {
  max-width: 32em;
  margin-bottom: 1.25rem;
  font-size: 0.9rem;
  line-height: 1.8;
  color: rgba(245, 246, 245, 0.7);
  text-wrap: pretty;
  word-break: auto-phrase;
}

/* ヒーローの「プラナ AI」の札。ヘッダーの琥珀の枠で、主役（ブランド）より控えめに */
.pk-hero__ai {
  display: inline-flex;
  align-items: center;
  gap: 0.65rem;
  max-width: 100%;
  margin-bottom: 2rem;
  padding: 0.4rem 0.75rem 0.4rem 0.4rem;
  font: inherit;
  font-size: 0.875rem;
  line-height: 1.5;
  text-align: left;
  color: rgba(245, 246, 245, 0.88);
  background: rgba(231, 183, 120, 0.08);
  border: 1px solid rgba(231, 183, 120, 0.45);
  cursor: pointer;
  transition: background-color 0.15s, border-color 0.15s;
}

.pk-hero__ai:hover {
  background: rgba(231, 183, 120, 0.16);
  border-color: #e7b778;
}

.pk-hero__ai:focus-visible {
  outline: 2px solid #e7b778;
  outline-offset: 3px;
}

.pk-hero__ai-text {
  min-width: 0;
  word-break: auto-phrase;
}

.pk-hero__ai-text strong {
  margin-right: 0.6em;
  font-weight: 700;
  color: #fff;
}

.pk-hero__ai-chevron {
  flex: 0 0 auto;
  opacity: 0.7;
}

.pk-hero__note {
  margin-top: 1rem;
  font-size: 0.8rem;
  color: rgba(245, 246, 245, 0.65);
}

.pk-plana {
  position: relative;
  overflow: hidden;
  color: #fff;
  /* 夕暮れのプラント。上はネイビー、地平線に向かって水色へ。右下の橙は、ロゴの橙 */
  background:
    radial-gradient(ellipse 60% 55% at 82% 104%, rgba(243, 163, 64, 0.55), transparent 70%),
    linear-gradient(180deg, #0d2450 0%, #1a4fa8 58%, #7fbfee 100%);
}

.pk-plana__skyline {
  position: absolute;
  inset: auto 0 0 0;
  width: 100%;
  height: min(46%, 190px);
  pointer-events: none;
}

.pk-plana__inner {
  position: relative;
  z-index: 1;
  display: grid;
  grid-template-columns: minmax(0, clamp(220px, 32%, 380px)) minmax(0, 1fr);
  align-items: end;
  column-gap: clamp(1.5rem, 4vw, 3.5rem);
  max-width: 1240px;
  margin: 0 auto;
  padding: 2.5rem clamp(1.5rem, 6vw, 3rem) 0 clamp(1.5rem, 7vw, 6.5rem);
}

/* キャラクターは帯の下端で切れる（元の画像が腰のあたりまでなので、そのまま立たせる） */
.pk-plana__figure {
  align-self: end;
}

.pk-plana__body {
  align-self: center;
  max-width: 640px;
  padding-bottom: 3rem;
}

.pk-plana__title {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin: 0 0 0.5rem;
  font-family: var(--pk-font-display);
  font-size: clamp(2.4rem, 6vw, 3.6rem);
  font-weight: 900;
  line-height: 1.1;
  letter-spacing: 0.02em;
}

.pk-plana__badge {
  padding: 0.05rem 0.7rem;
  font-size: 0.4em;
  font-weight: 900;
  letter-spacing: 0.04em;
  color: var(--pk-plana-navy);
  background: var(--pk-plana-glow);
  border-radius: 999px;
}

.pk-plana__tagline {
  margin: 0 0 0.75rem;
  font-family: var(--pk-font-display);
  font-size: clamp(1.15rem, 2.8vw, 1.5rem);
  font-weight: 700;
}

.pk-plana__lead {
  max-width: 34em;
  margin: 0 0 1.5rem;
  font-size: 0.9rem;
  line-height: 1.8;
  color: rgba(255, 255, 255, 0.9);
  text-wrap: pretty;
  word-break: auto-phrase;
}

.pk-plana__note {
  margin: 0.75rem 0 0;
  font-size: 0.8rem;
  font-weight: 500;
  color: var(--pk-plana-navy);
  word-break: auto-phrase;
}

@media (max-width: 720px) {
  .pk-plana__inner {
    grid-template-columns: minmax(0, 1fr);
    padding-top: 1.75rem;
    padding-right: 1.5rem;
  }

  .pk-plana__figure {
    width: min(58%, 200px);
    margin-bottom: -0.75rem;
  }

  .pk-plana__body {
    padding-bottom: 3rem;
  }
}

/* 設備から発注までの流れ。区切り線の上の山形が、次の業務へつながることを示す */
.pk-flow {
  display: grid;
  grid-template-columns: repeat(7, minmax(0, 1fr));
  margin: 0 0 2.5rem;
  padding: 0;
  list-style: none;
  background: #fff;
  border: 1px solid var(--pk-line);
}

.pk-flow__step {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 0.3rem;
  padding: 0.9rem 0.85rem 1rem;
  border-left: 1px solid var(--pk-line);
}

.pk-flow__step:first-child {
  border-left: none;
}

.pk-flow__step:not(:last-child)::after {
  content: '';
  position: absolute;
  top: 1.3rem;
  right: -6px;
  z-index: 1;
  width: 11px;
  height: 11px;
  background: #fff;
  border-top: 1px solid var(--pk-steel);
  border-right: 1px solid var(--pk-steel);
  transform: rotate(45deg);
}

.pk-flow__name {
  font-family: var(--pk-font-display);
  font-size: 0.95rem;
  font-weight: 700;
}

.pk-flow__note {
  font-size: 0.75rem;
  line-height: 1.55;
  color: #4a575c;
  word-break: auto-phrase;
}

@media (max-width: 900px) {
  .pk-flow {
    grid-template-columns: minmax(0, 1fr);
  }

  .pk-flow__step {
    flex-direction: row;
    align-items: baseline;
    gap: 0.75rem;
    padding: 0.7rem 1rem;
    border-left: none;
    border-top: 1px solid var(--pk-line);
  }

  .pk-flow__step:first-child {
    border-top: none;
  }

  .pk-flow__step .v-icon {
    align-self: center;
  }

  .pk-flow__name {
    flex: 0 0 4.5em;
  }

  .pk-flow__step:not(:last-child)::after {
    top: auto;
    right: auto;
    bottom: -6px;
    left: 1.5rem;
    transform: rotate(135deg);
  }
}

.pk-feature-rows {
  display: flex;
  flex-direction: column;
}

.pk-feature-row {
  scroll-margin-top: 5rem;
  display: flex;
  align-items: flex-start;
  gap: clamp(2rem, 5vw, 4rem);
  padding: 2.5rem 0;
  border-top: 1px solid var(--pk-line);
}

.pk-feature-row:first-child {
  padding-top: 0;
  border-top: none;
}

.pk-feature-row__text {
  flex: 0 0 300px;
  max-width: 300px;
  word-break: auto-phrase;
}

.pk-feature-row__heading {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  margin-bottom: 0.75rem;
}

.pk-feature-row__shot {
  flex: 1 1 auto;
  min-width: 0;
}

.pk-feature-row__points {
  margin: 0.9rem 0 0;
  padding: 0;
  list-style: none;
}

.pk-feature-row__points li {
  padding: 0.4rem 0;
  font-size: 0.8125rem;
  line-height: 1.7;
  color: #4a575c;
  border-top: 1px solid var(--pk-line);
}

@media (max-width: 900px) {
  .pk-feature-row {
    flex-direction: column;
  }

  .pk-feature-row__text {
    flex: 0 0 auto;
    max-width: none;
  }
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
  height: clamp(200px, 24vw, 320px);
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

/* 切り出した画面は、上だけを見せず、全体を見せる */
.pk-shot__frame--fit {
  height: auto;
}

.pk-shot__frame--fit .pk-shot__img {
  position: static;
}

.pk-shot__frame--fit .pk-shot__fade {
  display: none;
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

.pk-permissions {
  border-top: 1px solid var(--pk-line);
}

.pk-permissions__intro {
  max-width: 640px;
}

.pk-permissions__intro p {
  text-wrap: pretty;
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

</style>
