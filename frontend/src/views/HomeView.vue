<script setup lang="ts">
import { useAuthStore } from '@/stores/auth'
import PermissionMatrix from '@/components/PermissionMatrix.vue'
import troubleScreenshot from '@/assets/screenshots/trouble-detail.png'
import bypassScreenshot from '@/assets/screenshots/interlock-bypass.png'
import PlanaAvatar from '@/components/plana/PlanaAvatar.vue'
import PlanaNote from '@/components/plana/PlanaNote.vue'
import { planaCapabilities } from '@/constants/planaCapabilities'

const auth = useAuthStore()

// 上から「PlantKeeperとは何か」（保全の記録の流れ・インターロックのバイパス）→「その記録の上で働くプラナとは何か」→「1件のトラブルでのプラナの仕事」の順に見せる

// 保全業務でデータがつながる順。説明は、実装済みの動作だけを書く
const flowSteps = [
  { icon: 'mdi-factory', title: '設備', note: '設備台帳・計器・タグ番号' },
  { icon: 'mdi-clipboard-check-outline', title: '点検', note: 'チェックリストと承認' },
  { icon: 'mdi-alert-circle-outline', title: 'トラブル', note: '不具合から自動で登録' },
  { icon: 'mdi-hammer-wrench', title: '修理', note: '対応記録と修理の依頼' },
  { icon: 'mdi-package-variant', title: '資材', note: '型番の表記ゆれも検索' },
  { icon: 'mdi-warehouse', title: '在庫', note: '拠点をまたいで確認' },
  { icon: 'mdi-cart-outline', title: '発注', note: '受領すると在庫へ入庫' },
]
const foundations = [
  { title: '設備と記録をつなぐ', description: '設備台帳・計器・点検・トラブルをひとつにつなぎ、過去の記録をたどれます。', icon: 'mdi-factory' },
  { title: '保全の仕事を進める', description: '点検計画から承認、定期整備まで。現場と管理者が同じ記録を見ながら進められます。', icon: 'mdi-clipboard-check-outline' },
  { title: '資材まで見渡す', description: '型番・在庫・修理・発注を管理。必要な資材を、拠点をまたいで確認できます。', icon: 'mdi-package-variant-closed' },
]
// インターロックのバイパス: 申請から復帰の確認まで。本人以外が承認・確認する段階を示す
const bypassSteps = [
  { title: '申請', note: '理由と、バイパス中の代替措置（誰が何を見て、どうなったら止めるか）' },
  { title: '承認', note: '申請した本人以外' },
  { title: 'バイパス', note: '現場で実施した人と日時' },
  { title: '復帰', note: '作業のあとで戻す' },
  { title: '復帰の確認', note: '復帰した本人以外' },
]
const bypassGuards = [
  { icon: 'mdi-clock-alert-outline', text: '予定の復帰を過ぎても戻っていないものは「復帰期限超過」として、ダッシュボードと台帳で目立たせます。' },
  { icon: 'mdi-wrench-clock', text: '定期整備は、対象設備のバイパスがすべて戻り、確認が済むまで検収へ進めません（運転を再開する前の確認）。' },
]
const planaPrinciples = [
  'プラナは提案まで。記録に反映・保存するかは、人が決めます',
  '応急処置の手順や、運転を続けてよいかの判断は出しません',
  '呼び出しは記録され、AIの案と確定した内容を突き合わせられます',
]

// 3つの仕事を、同じ1件のトラブル（FT-301の指示低下）の流れで見せる。架空のメモ・記録による表示例。
// 1の routineChecks は backend/app/models/instrument_troubleshooting_catalog.rb の
// CHECKS['flow_transmitter'] と同じ内容（実際の値は計器種別ごとにアプリが確定的に出す）
const capability = (key: string) => planaCapabilities.find((c) => c.key === key)!
const story = [
  {
    key: 'defect-draft',
    scene: '点検で気づく',
    lead: '巡回で指示の低さに気づいた。メモのまま、トラブル報告に整えてもらう。',
    input: '点検で気づいたこと',
    memo: '朝の巡回でFT-301の指示が低め。\n昨日も同じだった。いつからかは不明。\n現場の流量はまだ確認していない。',
    routineChecks: [
      '導圧管の閉塞（固形物の堆積・凍結・気体/液体の溜まり）。ブロー・貫通棒での貫通でOKになるか',
      'ゼロ点ズレの確認',
      'バルブマニホールド（元弁・平衡弁）が誤って閉止・半開になっていないか',
      '配線・端子の緩み、電源の確認',
      'オリフィス・絞り部の詰まり・付着',
    ],
    planaNote: 'プラナが整理しました。まだ保存されていません。内容を確認して、必要なら直してください。',
    title: 'FT-301 流量指示の低下',
    meta: '優先度 中',
    detail: '朝の巡回時にFT-301の指示低下を確認。前日も同様の状態だった。発生時期は不明で、現場の流量は未確認。',
    possibleCauses: [
      'オリフィス・絞り部の詰まりの可能性（指示の低下が緩やかで、前日から変わっていないため）',
      '導圧管の閉塞の可能性（急な変化ではなく、進行中の閉塞と考えられるため）',
    ],
    checkPoint: '現場の流量と、FT-301の指示は一致しているか？',
    caption: '見立ては可能性であり断定ではありません。定型項目とは重複させません。',
    result: '確認して点検を保存すると、トラブルとして登録されます。',
  },
  {
    key: 'similar-troubles',
    scene: '過去の事例を見る',
    lead: '同じ計器・同じ種類の計器の過去のトラブルから、症状が同じものを探してもらう。',
    input: 'いま起きている症状（1と同じメモ）',
    memo: '朝の巡回でFT-301の指示が低め。\n昨日も同じだった。いつからかは不明。\n現場の流量はまだ確認していない。',
    planaNote: 'プラナが選んだ候補です（過去のトラブル9件と比べました）。似ているかどうかは、開いて記録を見て判断してください。',
    title: 'FT-301 流量指示の緩やかな低下',
    meta: '完了・優先度 中・2年前',
    similarity: '同じ計器で、指示が低めの状態が続いた点が一致',
    howHandled: '導圧管にスラッジの堆積を確認し、ブローして指示が復旧した',
    caption: 'タイトル・状態は記録の値です。プラナが書くのは「似ている点」と「過去の対応」だけです。',
    result: '見立ての2つのうち、まず導圧管から確かめる手がかりになります。',
  },
  {
    key: 'response-draft',
    scene: '対応を記録する',
    lead: '対応を終えたら、作業後のメモを対応記録に整えてもらう。',
    input: '作業後のメモ',
    memo: '導圧管ブローしたら黒いスラッジが出た。\nブロー後は指示が戻った。\n現場の流量計と合ってる。',
    planaNote: 'プラナが整理しました。まだ保存されていません。内容を確認して、必要なら直してください。',
    title: 'FT-301 導圧管のブロー・指示の復旧確認',
    meta: '対応種別: 修理',
    detail: '導圧管をブローしたところ、黒色のスラッジが排出された。ブロー後に指示の復旧を確認し、現場流量計の指示とも一致した。',
    usedMaterials: 'なし',
    checkPoint: 'スラッジの出どころ（原油の性状の変化など）は分かっているか？',
    caption: '確認したい点は記録には反映されません。',
    result: '確認して保存すると、トラブルの対応記録として残ります。次に同じ症状が出たとき、2の手がかりになります。',
  },
].map((step) => ({ ...step, to: capability(step.key).to, task: capability(step.key).title }))
</script>

<template>
  <v-app-bar color="surface" class="landing-nav px-2 px-sm-6">
    <v-icon color="primary" size="24" class="mr-2" aria-hidden="true">mdi-gauge-full</v-icon>
    <span class="landing-brand">PlantKeeper</span>
    <v-spacer />
    <v-btn variant="text" :to="auth.isLoggedIn ? '/plana' : '/login'">{{ auth.isLoggedIn ? 'ホーム' : 'ログイン' }}</v-btn>
  </v-app-bar>
  <v-main class="landing">
    <!-- 1. PlantKeeperとは -->
    <section class="landing-hero" aria-labelledby="hero-title">
      <div class="landing-hero-inner">
        <div class="landing-hero-copy">
          <h1 id="hero-title" class="landing-hero-brand">PlantKeeper</h1>
          <p class="landing-hero-tagline">設備保全に必要な情報を、ひとつの場所へ。</p>
          <p class="landing-lead">石油プラントの保全業務のためのWebアプリです。設備・点検・トラブル・修理・資材・在庫・発注までを、ひとつの記録としてつなぎます。</p>
          <a href="#plana" class="landing-hero-plana">
            <PlanaAvatar :size="30" />
            <span><strong>AIアシスタント「プラナ」</strong>記録をもとに、現場の報告と調べものを手伝います</span>
            <v-icon size="18" aria-hidden="true">mdi-chevron-down</v-icon>
          </a>
          <div>
            <v-btn to="/plana" color="primary" size="x-large">{{ auth.isLoggedIn ? '作業ホームを開く' : 'デモアカウントで試す' }}</v-btn>
          </div>
          <p class="landing-caption">{{ auth.isLoggedIn ? '設備やトラブルを選んで、作業を始められます。' : '登録不要。ログイン画面でデモアカウントを選ぶだけで試せます。' }}</p>
        </div>
        <figure class="landing-hero-shot">
          <a :href="troubleScreenshot" target="_blank" rel="noopener" aria-label="トラブル詳細の画面を拡大する（新しいタブ）"><img :src="troubleScreenshot" width="1144" height="584" alt="トラブル詳細画面。対象設備の常圧蒸留装置、計器PV-201、発生元点検と最近の点検履歴を同じ画面で確認できる。" /></a>
          <figcaption>デモデータを表示した実際のトラブル詳細画面。設備・計器・発生元の点検と、過去の点検履歴を同じ画面でたどれます。</figcaption>
        </figure>
      </div>
    </section>

    <section id="features" class="landing-section" aria-labelledby="features-title">
      <div class="landing-section-heading"><h2 id="features-title">保全の記録が、ひとつの流れでつながる。</h2><p>設備から発注まで、保全の仕事で生まれる記録を順にたどれます。</p></div>
      <ol class="landing-flow" aria-label="PlantKeeperで管理する保全業務の流れ">
        <li v-for="step in flowSteps" :key="step.title">
          <v-icon size="22" color="primary" aria-hidden="true">{{ step.icon }}</v-icon>
          <strong>{{ step.title }}</strong>
          <span>{{ step.note }}</span>
        </li>
      </ol>
      <div class="landing-foundation-grid"><article v-for="item in foundations" :key="item.title"><v-icon size="24" color="primary" aria-hidden="true">{{ item.icon }}</v-icon><h3>{{ item.title }}</h3><p>{{ item.description }}</p></article></div>
    </section>

    <section id="safety" class="landing-section landing-safety" aria-labelledby="safety-title">
      <div class="landing-section-heading">
        <h2 id="safety-title">インターロックのバイパスを、戻し忘れない。</h2>
        <p>点検や故障のときに一時的に外す安全計装（インターロック）を、申請から復帰の確認まで記録します。外れている間は、プラントを守る仕組みがひとつ欠けているからです。</p>
      </div>
      <div class="landing-safety-body">
        <figure class="landing-hero-shot">
          <a :href="bypassScreenshot" target="_blank" rel="noopener" aria-label="インターロックの詳細の画面を拡大する（新しいタブ）"><img :src="bypassScreenshot" width="1144" height="423" alt="インターロックI-701の詳細画面。予定の復帰を過ぎたバイパスが赤く表示され、理由・代替措置と、申請・承認・バイパス実施の担当者と日時が並ぶ。" /></a>
          <figcaption>デモデータの実際の画面。LT-701の調査でバイパスしたまま、予定の復帰を過ぎたI-701です。</figcaption>
        </figure>
        <div>
          <ol class="landing-bypass-steps" aria-label="バイパスの流れ">
            <li v-for="step in bypassSteps" :key="step.title"><strong>{{ step.title }}</strong><span>{{ step.note }}</span></li>
          </ol>
          <ul class="landing-bypass-guards">
            <li v-for="guard in bypassGuards" :key="guard.icon"><v-icon size="20" color="error" aria-hidden="true">{{ guard.icon }}</v-icon><span>{{ guard.text }}</span></li>
          </ul>
        </div>
      </div>
    </section>

    <!-- 2. プラナとは -->
    <section id="plana" class="landing-plana" aria-labelledby="plana-title">
      <div class="landing-plana-inner">
        <figure class="landing-character">
          <PlanaAvatar variant="full" alt="ヘルメットをかぶり、タブレットを持ったAIアシスタント、プラナ" />
        </figure>
        <div>
          <p class="landing-eyebrow">PlantKeeperのAIアシスタント</p>
          <h2 id="plana-title">プラナ</h2>
          <p class="landing-plana-tagline">記録をもとに、現場の判断を支える。</p>
          <p class="landing-plana-lead">PlantKeeperに蓄積された設備・計器・トラブルの記録をもとに、不具合報告の整理、過去の類似トラブルの検索、対応記録の整理を手伝います。判断するのは人です。</p>
          <ul class="landing-principles"><li v-for="p in planaPrinciples" :key="p"><v-icon size="16" color="primary" aria-hidden="true">mdi-check</v-icon>{{ p }}</li></ul>
        </div>
      </div>
    </section>

    <!-- 3. 1件のトラブルでたどるプラナの仕事 -->
    <section id="plana-work" class="landing-section" aria-labelledby="plana-work-title">
      <div class="landing-section-heading">
        <h2 id="plana-work-title">1件のトラブルで見る、プラナの仕事。</h2>
        <p>流量計FT-301の指示が低い。気づいてから対応を記録するまでに、プラナが手伝う3つの場面です。<span class="landing-note-inline">架空のメモ・記録による表示例</span></p>
      </div>
      <ol class="landing-story-steps">
        <li v-for="(step, index) in story" :key="step.key" class="landing-step" :data-task="step.key">
          <div class="landing-step-marker" aria-hidden="true">{{ index + 1 }}</div>
          <div class="landing-step-body">
            <header class="landing-step-header">
              <p class="landing-step-task">{{ step.task }}</p>
              <h3>{{ step.scene }}</h3>
              <p>{{ step.lead }}</p>
            </header>
            <div class="landing-comparison">
              <div class="landing-input">
                <h4>{{ step.input }}</h4>
                <p>{{ step.memo }}</p>
              </div>
              <div>
                <div v-if="step.routineChecks" class="pk-reference">
                  <h4><v-icon size="16" aria-hidden="true">mdi-clipboard-text-outline</v-icon>この計器（流量伝送器）の一次点検の定型項目</h4>
                  <p class="pk-reference-meta">参考。計器種別ごとにアプリが確定的に表示</p>
                  <ul><li v-for="c in step.routineChecks" :key="c">{{ c }}</li></ul>
                </div>
                <div class="pk-plana-card">
                  <div class="pk-plana-card-body">
                    <PlanaNote>{{ step.planaNote }}</PlanaNote>
                    <div class="pk-plana-card-title-row">
                      <p class="pk-plana-card-title">{{ step.title }}</p>
                      <span class="pk-plana-card-meta">{{ step.meta }}</span>
                    </div>
                    <p v-if="step.detail">{{ step.detail }}</p>
                    <p v-if="step.similarity"><strong>似ている点:</strong> {{ step.similarity }}</p>
                    <p v-if="step.howHandled"><strong>過去の対応:</strong> {{ step.howHandled }}</p>
                    <p v-if="step.usedMaterials"><strong>使用資材:</strong> {{ step.usedMaterials }}</p>
                    <div v-if="step.possibleCauses || step.checkPoint" class="pk-plana-card-grid" :class="{ 'pk-plana-card-grid-single': !step.possibleCauses || !step.checkPoint }">
                      <div v-if="step.possibleCauses">
                        <h5><v-icon size="15" aria-hidden="true">mdi-lightbulb-on-outline</v-icon>見立て</h5>
                        <ul><li v-for="c in step.possibleCauses" :key="c">{{ c }}</li></ul>
                      </div>
                      <div v-if="step.checkPoint">
                        <h5><v-icon size="15" aria-hidden="true">mdi-help-circle-outline</v-icon>確認したい点</h5>
                        <p>{{ step.checkPoint }}</p>
                      </div>
                    </div>
                  </div>
                  <p class="pk-plana-card-caption">{{ step.caption }}</p>
                </div>
              </div>
            </div>
            <footer class="landing-step-footer">
              <p>{{ step.result }}</p>
              <v-btn :to="step.to" variant="outlined" color="primary">{{ step.task }}を試す</v-btn>
            </footer>
          </div>
        </li>
      </ol>
    </section>

    <section id="try-guide" class="landing-section landing-guide" aria-labelledby="try-title">
      <h2 id="try-title">体験を始めるには</h2>
      <ol><li>ログイン画面でデモアカウントを選びます。3つの仕事を試すなら、自社の「一般」が使えます。</li><li>仕事を選び、デモデータの設備やトラブルを指定して、自分でメモを入力します。上の表示例は自動入力されません。</li><li>AIの提案を確認します。記録に反映・保存するかは、自分で決められます。</li></ol>
      <p>AIが無効、または1日の利用上限に達している場合は、プラナによる整理・検索は使えません。通常の記録入力や過去の記録の閲覧は利用できます。利用状況はログイン後に確認できます。</p>
    </section>

    <section id="permissions" class="landing-section" aria-labelledby="permission-title">
      <div class="landing-section-heading"><h2 id="permission-title">自社も協力会社も、同じ記録で。</h2><p>所属と権限に合わせて、見られる情報・できる操作を分けています。デモアカウントは5つの権限に1人ずつ用意しています。</p></div>
      <p class="landing-permissions-summary">不具合報告の整理・類似トラブルの検索は、5種類すべてのデモ権限で利用できます。対応記録の整理は、協力会社の「技能員」を除く4種類で利用できます。</p>
      <details class="landing-permissions"><summary>業務機能の詳しい権限を見る</summary><PermissionMatrix /></details>
    </section>
    <section class="landing-story landing-section">
      <div><h2>計装保全の現場から<br />生まれたPlantKeeper。</h2></div>
      <div><p>石油プラントの計装保全に10年間携わった経験から、紙やExcelに分かれていた情報をつなぐために作りました。</p><a href="https://github.com/RyotaAraya/plant-keeper" target="_blank" rel="noopener">GitHubで開発の詳細を見る</a></div>
    </section>
    <section class="landing-section landing-final" aria-labelledby="final-title">
      <div><h2 id="final-title">デモデータで、保全の流れを試す。</h2><p>設備やトラブルを選び、メモを入力するところから始められます。</p></div>
      <v-btn to="/plana" color="primary" size="large">{{ auth.isLoggedIn ? '作業ホームを開く' : 'デモアカウントで始める' }}</v-btn>
    </section>
    <footer class="landing-footer"><span>PlantKeeper</span><span>Developed by Ryota Araya</span></footer>
  </v-main>
</template>

<style scoped>
.landing { background: #fff; color: var(--pk-ink); }
.landing-brand { font-weight: 700; font-family: var(--pk-font-display); }
.landing-caption { font-size: .75rem; line-height: 1.9; color: var(--pk-muted); margin-top: 16px; }

/* ヒーロー: 何のシステムかを先に言う */
.landing-hero { background: var(--pk-mist); }
.landing-hero-inner { max-width: 1200px; margin: auto; display: grid; grid-template-columns: 1fr 1.1fr; gap: 56px; align-items: center; padding: 64px 32px; }
.landing-hero-copy { min-width: 0; }
.landing-hero-brand { font-family: var(--pk-font-display); font-weight: 900; color: var(--pk-plana-navy); font-size: clamp(2.5rem, 5vw, 4rem); line-height: 1; margin-bottom: 16px; }
.landing-hero-tagline { font-family: var(--pk-font-display); font-weight: 700; font-size: clamp(1.25rem, 2.6vw, 1.75rem); line-height: 1.5; word-break: auto-phrase; }
.landing-lead { font-size: 1rem; line-height: 1.9; margin: 16px 0 24px; color: var(--pk-muted); word-break: auto-phrase; }
.landing-hero-plana { display: inline-flex; align-items: center; gap: 10px; max-width: 100%; margin-bottom: 28px; padding: 6px 12px 6px 6px; border: 1px solid var(--pk-line); border-radius: 12px; background: #fff; color: var(--pk-muted); font-size: .8125rem; line-height: 1.5; text-decoration: none; transition: background-color .15s, border-color .15s; }
.landing-hero-plana:hover { background: var(--pk-soft-blue); border-color: var(--pk-steel); }
.landing-hero-plana:focus-visible { outline: 2px solid var(--pk-steel); outline-offset: 3px; }
.landing-hero-plana span { min-width: 0; word-break: auto-phrase; }
.landing-hero-plana strong { display: block; color: var(--pk-plana-navy); font-weight: 700; }
.landing-hero-shot { margin: 0; min-width: 0; }
.landing-hero-shot img { display: block; width: 100%; height: auto; border: 1px solid var(--pk-line); border-radius: 12px; box-shadow: 0 16px 40px -16px rgba(35, 100, 196, .25); }
.landing-hero-shot figcaption { font-size: .75rem; color: var(--pk-muted); line-height: 1.8; margin-top: 12px; }

.landing-section { max-width: 1200px; margin-inline: auto; padding: 64px 32px; }
.landing-section-heading { margin-bottom: 32px; }
.landing-section h2 { font-size: 1.875rem; line-height: 1.5; text-wrap: balance; word-break: auto-phrase; }
.landing-section-heading p { font-size: .9375rem; color: var(--pk-muted); margin-top: 12px; line-height: 1.9; }
.landing-note-inline { display: inline-block; margin-left: 8px; padding: 0 8px; font-size: .75rem; border: 1px solid var(--pk-line); border-radius: 999px; }

/* 設備から発注までの流れ。区切り線の上の山形が、次の業務へつながることを示す */
.landing-flow { display: grid; grid-template-columns: repeat(7, minmax(0, 1fr)); margin: 0 0 48px; padding: 0; list-style: none; border: 1px solid var(--pk-line); border-radius: 12px; }
.landing-flow li { position: relative; display: flex; flex-direction: column; gap: 4px; padding: 14px 14px 16px; border-left: 1px solid var(--pk-line); }
.landing-flow li:first-child { border-left: none; }
.landing-flow li:not(:last-child)::after { content: ''; position: absolute; top: 20px; right: -6px; z-index: 1; width: 11px; height: 11px; background: #fff; border-top: 1px solid var(--pk-steel); border-right: 1px solid var(--pk-steel); transform: rotate(45deg); }
.landing-flow strong { font-family: var(--pk-font-display); font-size: .9375rem; }
.landing-flow span { font-size: .75rem; line-height: 1.55; color: var(--pk-muted); word-break: auto-phrase; }
.landing-safety-body { display: grid; grid-template-columns: minmax(0, 1.25fr) minmax(0, 1fr); gap: 40px; align-items: start; }
.landing-bypass-steps { margin: 0 0 24px; padding: 0; list-style: none; counter-reset: bypass; }
.landing-bypass-steps li { counter-increment: bypass; display: grid; grid-template-columns: 2em 6.5em minmax(0, 1fr); align-items: baseline; gap: 8px; padding: 10px 0; border-bottom: 1px solid var(--pk-line); }
.landing-bypass-steps li::before { content: counter(bypass); color: var(--pk-steel); font-weight: 700; font-variant-numeric: tabular-nums; }
.landing-bypass-steps strong { font-family: var(--pk-font-display); font-size: .9375rem; }
.landing-bypass-steps span { font-size: .8125rem; line-height: 1.7; color: var(--pk-muted); }
.landing-bypass-guards { margin: 0; padding: 0; list-style: none; display: grid; gap: 14px; }
.landing-bypass-guards li { display: flex; gap: 10px; align-items: flex-start; font-size: .875rem; line-height: 1.8; }
.landing-foundation-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 40px; }
.landing-foundation-grid h3 { font-size: 1.125rem; margin: 16px 0 12px; }
.landing-foundation-grid p { font-size: .875rem; line-height: 1.9; color: var(--pk-muted); }

/* プラナとは */
.landing-plana { background: #dfeefd; overflow: hidden; }
.landing-plana-inner { max-width: 1200px; margin: auto; display: grid; grid-template-columns: minmax(0, 320px) minmax(0, 1fr); gap: 56px; align-items: end; padding: 40px 32px 0; }
.landing-plana-inner > div { align-self: center; padding-bottom: 40px; }
.landing-character { margin: 0; }
.landing-character :deep(.pk-plana-full) { display: block; width: 100%; max-width: 320px; transform: scaleX(-1); }
.landing-eyebrow { font-size: .8125rem; color: var(--pk-steel-dark); font-weight: 600; }
.landing-plana h2 { font-family: var(--pk-font-display); font-size: clamp(2.25rem, 5vw, 3.25rem); font-weight: 900; color: var(--pk-plana-navy); line-height: 1.2; margin-top: 4px; }
.landing-plana-tagline { font-family: var(--pk-font-display); font-size: 1.25rem; font-weight: 700; color: var(--pk-plana-navy); margin-top: 8px; }
.landing-plana-lead { font-size: .9375rem; line-height: 1.9; color: var(--pk-muted); margin-top: 12px; max-width: 36em; word-break: auto-phrase; }
.landing-principles { list-style: none; padding: 0; margin: 20px 0 0; display: grid; gap: 8px; }
.landing-principles li { display: flex; align-items: flex-start; gap: 8px; font-size: .875rem; line-height: 1.7; }
.landing-principles .v-icon { margin-top: 3px; }

/* 1件のトラブルの流れ。番号の縦線で、3つの場面が続いていることを示す */
.landing-story-steps { list-style: none; margin: 0; padding: 0; }
.landing-step { display: grid; grid-template-columns: 40px minmax(0, 1fr); gap: 24px; position: relative; padding-bottom: 48px; }
.landing-step:not(:last-child)::before { content: ''; position: absolute; left: 19px; top: 44px; bottom: 4px; width: 2px; background: var(--pk-line); }
.landing-step:last-child { padding-bottom: 0; }
.landing-step-marker { width: 40px; height: 40px; border-radius: 50%; display: grid; place-items: center; background: var(--pk-steel); color: #fff; font-weight: 700; font-family: var(--pk-font-display); }
.landing-step-body { min-width: 0; }
.landing-step-header { margin-bottom: 20px; }
.landing-step-task { font-size: .75rem; font-weight: 700; color: var(--pk-steel); }
.landing-step-header h3 { font-size: 1.375rem; margin: 2px 0 6px; }
.landing-step-header p:last-child { font-size: .9375rem; color: var(--pk-muted); line-height: 1.8; }
.landing-comparison { display: grid; grid-template-columns: 1fr 1.3fr; gap: 28px; align-items: start; }
.landing-input { background: var(--pk-mist); border-radius: 8px; padding: 20px 24px; }
.landing-input h4 { font-size: .8125rem; color: var(--pk-muted); margin-bottom: 12px; }
.landing-input p { white-space: pre-line; font-size: 1.0625rem; line-height: 2; }
.landing-step-footer { display: flex; justify-content: space-between; align-items: center; gap: 24px; margin-top: 20px; padding-top: 16px; border-top: 1px dashed var(--pk-line); }
.landing-step-footer p { font-size: .875rem; line-height: 1.8; }

/* 参考知識（計器種別ごとの一次点検の定型項目）。プラナの提案とは別の見え方にする：
   ニュートラルな鋼色のアクセント罫＋薄い背景で「AIの発言ではない」ことを色で示す */
.pk-reference { border-left: 3px solid var(--pk-steel); background: var(--pk-mist); border-radius: 0 10px 10px 0; padding: 16px 20px; margin-bottom: 20px; }
.pk-reference h4 { display: flex; align-items: center; gap: 8px; font-size: .8125rem; font-weight: 700; color: var(--pk-ink); margin: 0; }
.pk-reference-meta { font-size: .6875rem; color: var(--pk-muted); margin: 4px 0 12px 24px; }
.pk-reference ul { list-style: none; margin: 0; padding: 0; display: grid; gap: 7px; }
.pk-reference li { position: relative; padding-left: 15px; font-size: .8125rem; line-height: 1.8; color: var(--pk-muted); }
.pk-reference li::before { content: ''; position: absolute; left: 1px; top: .65em; width: 5px; height: 5px; background: var(--pk-steel); transform: rotate(45deg); }

/* プラナの提案は1枚のカードにまとめ、「プラナ」を名乗るのは見出し1箇所だけにする */
.pk-plana-card { border: 1px solid var(--pk-steel); border-radius: 12px; overflow: hidden; background: #fff; }
.pk-plana-card-body { padding: 20px; }
.pk-plana-card-body :deep(.pk-plana-note) { margin-bottom: 16px; }
.pk-plana-card-title-row { display: flex; flex-wrap: wrap; align-items: baseline; gap: 10px; }
.pk-plana-card-title { font-size: 1.125rem; font-weight: 700; color: var(--pk-ink); }
.pk-plana-card-meta { font-size: .75rem; color: var(--pk-muted); }
.pk-plana-card-body > p { font-size: .9375rem; line-height: 1.9; color: var(--pk-muted); margin-top: 8px; }
.pk-plana-card-body > p strong { color: var(--pk-ink); font-weight: 700; }
.pk-plana-card-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; margin-top: 18px; padding-top: 18px; border-top: 1px solid var(--pk-line); }
.pk-plana-card-grid-single { grid-template-columns: 1fr; }
.pk-plana-card-grid h5 { display: flex; align-items: center; gap: 6px; font-size: .75rem; font-weight: 700; color: var(--pk-steel); margin-bottom: 8px; }
.pk-plana-card-grid ul { margin: 0; padding-left: 18px; }
.pk-plana-card-grid li, .pk-plana-card-grid p { font-size: .8125rem; line-height: 1.8; color: var(--pk-muted); }
.pk-plana-card-caption { padding: 0 20px 16px; font-size: .6875rem; color: var(--pk-muted); }

.landing-guide { border-top: 1px solid var(--pk-line); padding-block: 32px 48px; scroll-margin-top: 80px; }
.landing-guide h2 { font-size: 1.25rem; }
.landing-guide ol { padding-left: 24px; margin: 20px 0; font-size: .875rem; line-height: 2; }
.landing-guide > p, .landing-permissions-summary { color: var(--pk-muted); font-size: .875rem; line-height: 1.9; max-width: 70em; }
.landing-permissions { margin-top: 24px; border-block: 1px solid var(--pk-line); }
.landing-permissions summary { cursor: pointer; padding: 20px 0; color: var(--pk-steel); font-weight: 600; }
.landing-permissions[open] { padding-bottom: 24px; }
.landing-final { border-top: 1px solid var(--pk-line); display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 24px; }
.landing-final h2 { font-size: 1.5rem; }
.landing-final p { margin-top: 12px; color: var(--pk-muted); font-size: .875rem; }
.landing-story { display: grid; grid-template-columns: 1fr 1.5fr; gap: 48px; border-top: 1px solid var(--pk-line); }
.landing-story p { color: var(--pk-muted); line-height: 2; margin-bottom: 16px; font-size: .9375rem; }
.landing-story a { color: var(--pk-steel); font-size: .875rem; }
.landing-footer { border-top: 1px solid var(--pk-line); display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 16px; padding: 24px 32px; font-size: .75rem; color: var(--pk-muted); }
#plana, #plana-work, #features { scroll-margin-top: 64px; }

@media (max-width: 900px) {
  .landing-hero-inner { grid-template-columns: 1fr; gap: 32px; }
  .landing-safety-body { grid-template-columns: 1fr; gap: 24px; }
  .landing-flow { grid-template-columns: 1fr; }
  .landing-flow li { flex-direction: row; align-items: baseline; gap: 12px; padding: 10px 16px; border-left: none; border-top: 1px solid var(--pk-line); }
  .landing-flow li:first-child { border-top: none; }
  .landing-flow .v-icon { align-self: center; }
  .landing-flow strong { flex: 0 0 4.5em; }
  .landing-flow li:not(:last-child)::after { top: auto; right: auto; bottom: -6px; left: 24px; transform: rotate(135deg); }
  .landing-comparison { grid-template-columns: 1fr; gap: 20px; }
}
@media (max-width: 700px) {
  .landing-hero-inner { padding: 40px 16px; }
  .landing-section { padding: 40px 16px; }
  .landing-plana-inner { grid-template-columns: 1fr; gap: 16px; padding: 32px 16px 0; }
  .landing-character { order: 2; }
  .landing-character :deep(.pk-plana-full) { width: 200px; margin-inline: auto; }
  .landing-plana-inner > div { padding-bottom: 0; }
  .landing-foundation-grid, .landing-story, .pk-plana-card-grid { grid-template-columns: 1fr; gap: 24px; }
  .landing-bypass-steps li { grid-template-columns: 1.5em 5.5em minmax(0, 1fr); }
  .landing-step { grid-template-columns: 1fr; gap: 12px; }
  .landing-step:not(:last-child)::before { display: none; }
  .landing-step-marker { width: 32px; height: 32px; }
  .landing-step-footer { align-items: start; flex-direction: column; }
}
</style>
