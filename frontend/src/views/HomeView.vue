<script setup lang="ts">
import { computed, ref } from 'vue'
import { useAuthStore } from '@/stores/auth'
import PermissionMatrix from '@/components/PermissionMatrix.vue'
import troubleScreenshot from '@/assets/screenshots/trouble-detail.png'
import PlanaAvatar from '@/components/plana/PlanaAvatar.vue'
import { planaCapabilities } from '@/constants/planaCapabilities'

const auth = useAuthStore()
const selectedExample = ref(0)
// tab 0（不具合）の routineChecks は backend/app/models/instrument_troubleshooting_catalog.rb の
// CHECKS['flow_transmitter'] と同じ内容（表示例。実際の値は計器種別ごとにアプリが確定的に出す）
const examples = [
  {
    label: '不具合を相談する', input: '点検で気づいたこと',
    memo: '朝の巡回でFT-301の指示が低め。\n昨日も同じだった。いつからかは不明。\n現場の流量はまだ確認していない。',
    routineChecks: [
      '導圧管の閉塞（固形物の堆積・凍結・気体/液体の溜まり）。ブロー・貫通棒での貫通でOKになるか',
      'ゼロ点ズレの確認',
      'バルブマニホールド（元弁・平衡弁）が誤って閉止・半開になっていないか',
      '配線・端子の緩み、電源の確認',
      'オリフィス・絞り部の詰まり・付着',
    ],
    output: '報告の下書き', title: 'FT-301 流量指示の低下', detail: '朝の巡回時にFT-301の指示低下を確認。前日も同様の状態だった。発生時期は不明で、現場の流量は未確認。',
    checkPoint: '現場の流量と、FT-301の指示は一致しているか？',
    note: '内容を確認してから、点検の記録に反映します。',
  },
  { label: '似た事例を探す', input: 'いま起きている症状', memo: '流量計の指示がゼロになった。\n現場では流れているように見える。', output: '過去の事例の提示', title: '流量計の信号途絶', detail: '似た症状の記録：流量計の指示がゼロになり、配線の断線を確認。配線を補修して指示が復旧。', note: '元のトラブル記録を開いて、症状や対応を確認できます。' },
  { label: '対応を記録する', input: '作業後のメモ', memo: '端子のゆるみを確認。\n増し締めして、指示が戻った。', output: '対応記録の下書き', title: '端子の増し締め・指示の復旧確認', detail: '端子のゆるみを確認し、増し締めを実施。作業後、指示が復旧したことを確認した。', note: '下書きを確認・編集してから、対応記録として保存します。' },
]
const example = computed(() => examples[selectedExample.value]!)
const steps = [
  '設備・計器を選ぶ → 点検の不具合欄を開く → メモを入力して下書きを作る',
  '設備・計器を選ぶ → 症状を入力する → 類似トラブルを検索する',
  '対応したトラブルを選ぶ → 対応メモを入力する → 下書きを作る',
]
const capability = computed(() => planaCapabilities[selectedExample.value]!)
const foundations = [
  { title: '設備と記録をつなぐ', description: '設備台帳・計器・点検・トラブルをひとつにつなぎ、過去の記録をたどれます。', icon: 'mdi-factory' },
  { title: '保全の仕事を進める', description: '点検計画から承認、定期整備まで。現場と管理者が同じ記録を見ながら進められます。', icon: 'mdi-clipboard-check-outline' },
  { title: '資材まで見渡す', description: '型番・在庫・修理・発注を管理。必要な資材を、拠点をまたいで確認できます。', icon: 'mdi-package-variant-closed' },
]
</script>

<template>
  <v-app-bar color="surface" class="landing-nav px-2 px-sm-6">
    <v-icon color="primary" size="24" class="mr-2" aria-hidden="true">mdi-gauge-full</v-icon>
    <span class="landing-brand">PlantKeeper</span>
    <v-spacer />
    <v-btn variant="text" :to="auth.isLoggedIn ? '/plana' : '/login'">{{ auth.isLoggedIn ? 'ホーム' : 'ログイン' }}</v-btn>
  </v-app-bar>
  <v-main class="landing">
    <section id="plana" class="landing-hero" aria-labelledby="hero-title">
      <div class="landing-hero-inner">
        <div class="landing-hero-copy">
          <p class="landing-intro">PlantKeeper の保全アシスタント</p>
          <h1 id="hero-title">プラナと進める、<br />設備保全。</h1>
          <p class="landing-lead">現場のメモを、伝わる記録に。<br />過去のトラブルを、次の手がかりに。</p>
          <v-btn to="/plana" color="primary" size="x-large" class="landing-cta">{{ auth.isLoggedIn ? '仕事を始める' : 'プラナを試す' }}</v-btn>
          <p class="landing-caption">{{ auth.isLoggedIn ? '設備やトラブルを選んで、作業を始められます。' : '登録不要。ログイン画面でデモアカウントを選び、対象の設備や記録を指定します。' }}</p>
          <a class="landing-guide-link" href="#try-guide">体験の手順・利用条件を見る</a>
        </div>
        <figure class="landing-character">
          <PlanaAvatar variant="full" alt="ヘルメットをかぶり、タブレットを持ったAIアシスタント、プラナ" />
          <figcaption>設備保全のAIアシスタント <strong>プラナ</strong></figcaption>
        </figure>
      </div>
    </section>

    <section class="landing-section landing-demo" aria-labelledby="work-title">
      <div class="landing-section-heading"><h2 id="work-title">現場で気づいたことを、プラナに相談する。</h2><p>計器の一次点検の定石とプラナの整理。似た事例の検索、対応記録の下書きも。3つの仕事をタブでご紹介します。</p></div>
      <v-tabs v-model="selectedExample" color="primary" class="landing-work" aria-label="プラナの仕事の表示例">
        <v-tab v-for="(item, index) in examples" :id="`example-tab-${index}`" :key="item.label" :value="index" aria-controls="example-panel">{{ item.label }}</v-tab>
      </v-tabs>
      <div id="example-panel" class="landing-example" role="tabpanel" :aria-labelledby="`example-tab-${selectedExample}`" tabindex="0">
        <div class="landing-example-meta"><span>{{ capability.title }}</span><span>架空のメモ・記録による表示例</span></div>
        <div class="landing-comparison">
          <div class="landing-input">
            <h3>{{ example.input }}</h3>
            <p>{{ example.memo }}</p>
          </div>
          <div class="landing-output">
            <div v-if="example.routineChecks" class="landing-routine-checks">
              <h4>この計器（流量伝送器）の一次点検の定型項目<span>参考。計器種別ごとにアプリが確定的に表示</span></h4>
              <ul><li v-for="c in example.routineChecks" :key="c">{{ c }}</li></ul>
            </div>
            <h3><v-icon size="20" aria-hidden="true">mdi-auto-fix</v-icon>{{ example.output }}</h3>
            <h4>{{ example.title }}</h4>
            <p>{{ example.detail }}</p>
            <div v-if="example.checkPoint" class="landing-check-points"><h4>プラナが挙げた確認したい点<span>このメモ特有。定型項目とは重複させない</span></h4><p>{{ example.checkPoint }}</p></div>
          </div>
        </div>
        <div class="landing-example-footer">
          <div><p>{{ example.note }}</p><p class="landing-steps">{{ steps[selectedExample] }}</p></div>
          <v-btn :to="capability.to" variant="outlined" color="primary">この仕事を試す</v-btn>
        </div>
      </div>
      <p class="landing-caption">プラナは提案まで。内容の確認と保存は人が行います。利用できる操作はアカウントの権限によって異なります。</p>
    </section>

    <section id="try-guide" class="landing-section landing-guide" aria-labelledby="try-title">
      <h2 id="try-title">体験を始めるには</h2>
      <ol><li>ログイン画面でデモアカウントを選びます。3つの仕事を試すなら、自社の「一般」が使えます。</li><li>仕事を選び、デモデータの設備やトラブルを指定して、自分でメモを入力します。上の表示例は自動入力されません。</li><li>AIの提案を確認します。記録に反映・保存するかは、自分で決められます。</li></ol>
      <p>AIが無効、または1日の利用上限に達している場合は、AIによる下書き・検索は使えません。通常の記録入力や過去の記録の閲覧は利用できます。利用状況はログイン後に確認できます。</p>
    </section>

    <section class="landing-foundation">
      <div class="landing-section">
        <div class="landing-section-heading"><h2>支えになるのは、現場の記録。</h2><p>PlantKeeperは、設備から点検・対応・資材までをつなぐ保全管理アプリです。</p></div>
        <figure class="landing-product">
          <a :href="troubleScreenshot" target="_blank" rel="noopener" aria-label="トラブル詳細の画面を拡大する（新しいタブ）"><img :src="troubleScreenshot" width="1144" height="584" loading="lazy" alt="トラブル詳細画面。対象設備の常圧蒸留装置、計器PV-201、発生元点検と最近の点検履歴を同じ画面で確認できる。" /></a>
          <figcaption>デモデータを表示した実際のトラブル詳細画面。設備・計器・発生元の点検と、過去の点検履歴をたどれます。画像を選ぶと拡大できます。</figcaption>
        </figure>
        <div class="landing-foundation-grid"><article v-for="item in foundations" :key="item.title"><v-icon size="24" color="primary" aria-hidden="true">{{ item.icon }}</v-icon><h3>{{ item.title }}</h3><p>{{ item.description }}</p></article></div>
      </div>
    </section>
    <section id="permissions" class="landing-section" aria-labelledby="permission-title">
      <div class="landing-section-heading"><h2 id="permission-title">自社も協力会社も、同じ記録で。</h2><p>所属と権限に合わせて、見られる情報・できる操作を分けています。</p></div>
      <p class="landing-permissions-summary">不具合報告の下書き・類似トラブルの検索は、5種類すべてのデモ権限で利用できます。対応記録の下書きは、協力会社の「技能員」を除く4種類で利用できます。</p>
      <details class="landing-permissions"><summary>業務機能の詳しい権限を見る</summary><PermissionMatrix /></details>
    </section>
    <section class="landing-story landing-section">
      <div><h2>計装保全の現場から<br />生まれたPlantKeeper。</h2></div>
      <div><p>石油プラントの計装保全に10年間携わった経験から、紙やExcelに分かれていた情報をつなぐために作りました。</p><a href="https://github.com/RyotaAraya/plant-keeper" target="_blank" rel="noopener">GitHubで開発の詳細を見る</a></div>
    </section>
    <section class="landing-section landing-final" aria-labelledby="final-title">
      <div><h2 id="final-title">デモデータで、仕事の流れを試す。</h2><p>設備を選び、メモを入力するところから始められます。</p></div>
      <v-btn to="/plana" color="primary" size="large">{{ auth.isLoggedIn ? '作業ホームを開く' : 'デモアカウントで始める' }}</v-btn>
    </section>
    <footer class="landing-footer"><span>PlantKeeper</span><span>Developed by Ryota Araya</span></footer>
  </v-main>
</template>

<style scoped>
.landing { background: #fff; color: var(--pk-ink); }
.landing-brand { font-weight: 700; font-family: var(--pk-font-display); }
.landing-hero { background: var(--pk-mist); }
.landing-hero-inner { max-width: 1200px; margin: auto; display: grid; grid-template-columns: 1.15fr 1fr; gap: 64px; align-items: center; padding: 64px 32px; }
.landing-intro { font-size: .9375rem; color: var(--pk-steel-dark); margin-bottom: 24px; }
.landing-hero h1 { font-size: clamp(2.5rem, 4.2vw, 4rem); line-height: 1.4; text-wrap: balance; color: var(--pk-plana-navy); }
.landing-lead { font-size: 1.125rem; line-height: 2; margin: 24px 0 32px; color: var(--pk-muted); }
.landing-caption { font-size: .75rem; line-height: 1.9; color: var(--pk-muted); margin-top: 16px; }
.landing-character { margin: 0; display: flex; flex-direction: column; align-items: center; }
.landing-character :deep(.pk-plana-full) { width: 380px; max-width: 100%; transform: scaleX(-1); }
.landing-character figcaption { display: flex; align-items: center; gap: 12px; margin-top: 16px; font-size: .8125rem; color: var(--pk-muted); }
.landing-character strong { color: var(--pk-ink); font-size: 1.125rem; }
.landing-section { max-width: 1200px; margin-inline: auto; padding: 64px 32px; }
.landing-section-heading { margin-bottom: 32px; }
.landing-section h2 { font-size: 1.875rem; line-height: 1.5; text-wrap: balance; }
.landing-section-heading p { font-size: .9375rem; color: var(--pk-muted); margin-top: 12px; line-height: 1.9; }
.landing-work { border-bottom: 1px solid var(--pk-line); }
.landing-work :deep(.v-tab) { font-size: 1rem; padding-inline: 28px; }
.landing-example { border: 1px solid var(--pk-line); border-top: 0; border-radius: 0 0 12px 12px; padding: 28px 32px; }
.landing-example:focus-visible { outline: 2px solid var(--pk-steel); outline-offset: 4px; }
.landing-example-meta { display: flex; justify-content: space-between; flex-wrap: wrap; gap: 8px; font-size: .75rem; color: var(--pk-muted); margin-bottom: 24px; }
.landing-comparison { display: grid; grid-template-columns: 1fr 1.2fr; gap: 32px; }
.landing-comparison h3 { display: flex; align-items: center; gap: 8px; font-size: .8125rem; margin-bottom: 20px; }
.landing-input { background: var(--pk-mist); border-radius: 8px; padding: 24px; }
.landing-input h3 { color: var(--pk-muted); }
.landing-input p { white-space: pre-line; font-size: 1.125rem; line-height: 2; }
.landing-output { padding: 24px 0; }
.landing-output h3 { color: var(--pk-steel); }
.landing-output h4 { font-size: 1.125rem; line-height: 1.6; margin-bottom: 12px; }
.landing-output p { font-size: .9375rem; line-height: 1.9; color: var(--pk-muted); }
.landing-example-footer { border-top: 1px solid var(--pk-line); padding-top: 24px; margin-top: 24px; display: flex; justify-content: space-between; align-items: center; gap: 24px; }
.landing-example-footer p { font-size: .8125rem; line-height: 1.8; color: var(--pk-muted); }
.landing-guide-link { display: inline-block; color: var(--pk-steel); font-size: .8125rem; margin-top: 8px; }
.landing-check-points { border-top: 1px solid var(--pk-line); margin-top: 20px; padding-top: 16px; }
.landing-check-points h4, .landing-routine-checks h4 { font-size: .8125rem; margin-bottom: 8px; display: flex; flex-wrap: wrap; align-items: baseline; gap: 8px; }
.landing-check-points h4 span, .landing-routine-checks h4 span { font-size: .6875rem; font-weight: 400; color: var(--pk-muted); }
.landing-routine-checks { background: var(--pk-mist); border-radius: 8px; padding: 16px 20px; margin-bottom: 20px; }
.landing-routine-checks ul { margin: 0; padding-left: 20px; font-size: .8125rem; line-height: 1.9; color: var(--pk-muted); }
.landing-example-footer .landing-steps { margin-top: 8px; color: var(--pk-ink); }
.landing-guide { border-top: 1px solid var(--pk-line); padding-block: 32px 48px; scroll-margin-top: 80px; }
.landing-guide h2 { font-size: 1.25rem; }
.landing-guide ol { padding-left: 24px; margin: 20px 0; font-size: .875rem; line-height: 2; }
.landing-guide > p, .landing-permissions-summary { color: var(--pk-muted); font-size: .875rem; line-height: 1.9; max-width: 70em; }
.landing-product { margin: 0 0 40px; }
.landing-product img { display: block; width: 100%; height: auto; border: 1px solid var(--pk-line); border-radius: 12px; }
.landing-product figcaption { font-size: .8125rem; color: var(--pk-muted); line-height: 1.8; margin-top: 12px; }
.landing-permissions { margin-top: 24px; border-block: 1px solid var(--pk-line); }
.landing-permissions summary { cursor: pointer; padding: 20px 0; color: var(--pk-steel); font-weight: 600; }
.landing-permissions[open] { padding-bottom: 24px; }
.landing-final { border-top: 1px solid var(--pk-line); display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 24px; }
.landing-final h2 { font-size: 1.5rem; }
.landing-final p { margin-top: 12px; color: var(--pk-muted); font-size: .875rem; }
.landing-foundation { background: var(--pk-mist); }
.landing-foundation-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 40px; }
.landing-foundation h3 { font-size: 1.125rem; margin: 16px 0 12px; }
.landing-foundation p { font-size: .875rem; line-height: 1.9; color: var(--pk-muted); }
.landing-story { display: grid; grid-template-columns: 1fr 1.5fr; gap: 48px; border-top: 1px solid var(--pk-line); }
.landing-story p { color: var(--pk-muted); line-height: 2; margin-bottom: 16px; font-size: .9375rem; }
.landing-story a { color: var(--pk-steel); font-size: .875rem; }
.landing-footer { border-top: 1px solid var(--pk-line); display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 16px; padding: 24px 32px; font-size: .75rem; color: var(--pk-muted); }
@media (max-width: 700px) {
  .landing-hero-inner { grid-template-columns: 1fr; gap: 32px; padding: 40px 20px; }
  .landing-character :deep(.pk-plana-full) { width: 240px; }
  .landing-section { padding: 40px 20px; }
  .landing-comparison, .landing-foundation-grid, .landing-story { grid-template-columns: 1fr; gap: 24px; }
  .landing-example { padding: 20px; }
  .landing-example-footer { align-items: start; flex-direction: column; }
}
</style>
