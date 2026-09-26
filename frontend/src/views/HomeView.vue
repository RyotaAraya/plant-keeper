<script setup lang="ts">
import { useAuthStore } from '@/stores/auth'
import PermissionMatrix from '@/components/PermissionMatrix.vue'
import troubleScreenshot from '@/assets/screenshots/trouble-detail.png'
import bypassScreenshot from '@/assets/screenshots/interlock-bypass.png'
import calibrationScreenshot from '@/assets/screenshots/calibration-trend.png'
import meetingBoardScreenshot from '@/assets/screenshots/meeting-board.png'
import diagnosticsScreenshot from '@/assets/screenshots/device-diagnostics.png'
import PlanaAvatar from '@/components/plana/PlanaAvatar.vue'
import PlanaNote from '@/components/plana/PlanaNote.vue'
import DiagnosticChip from '@/components/DiagnosticChip.vue'
import { planaCapabilities } from '@/constants/planaCapabilities'
import type { DiagnosticStatus } from '@/constants/diagnostics'

const auth = useAuthStore()

// 上から「PlantKeeperとは何か」（保全業務の流れ・インターロックのバイパス・校正と周期の見直し・日々の確認）→「その記録の上で働くプラナとは何か」→「1件のトラブルでのプラナの仕事」の順に見せる

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
// インターロックのバイパス: 申請から復帰の確認まで。本人以外が承認・確認する段階を示す
const bypassSteps = [
  { title: '申請', note: '理由と代替措置' },
  { title: '承認', note: '申請者以外' },
  { title: 'バイパス', note: '' },
  { title: '復帰', note: '' },
  { title: '復帰の確認', note: '復帰した人以外' },
]
// 5点校正 → 校正の傾向 → 周期の見直し。見直しはルールで出し、AIは使わない（要求仕様書 2.3）
const calibrationPoints = [
  { icon: 'mdi-tune-vertical', title: '5点校正', text: '上昇・下降の出力とDCSの表示を入れると、誤差と合否を計算します。' },
  { icon: 'mdi-chart-line', title: '校正の傾向', text: '調整前の最大誤差を、許容差と並べて年ごとに見られます。' },
  { icon: 'mdi-calendar-sync-outline', title: '周期の見直しの候補', text: '決まったルールで出します（AIは使いません）。法令で周期が決まる計器は、延長の候補にしません。' },
]
const diagnosticStates: DiagnosticStatus[] = ['failure', 'function_check', 'out_of_specification', 'maintenance_required']

// 3つの仕事を、同じ1件のトラブル（FT-301の指示低下）の流れで見せる。架空のメモ・記録による表示例。
// 1の routineChecks は backend/app/models/instrument_troubleshooting_catalog.rb の
// CHECKS['flow_transmitter'] と同じ内容（実際の値は計器種別ごとにアプリが確定的に出す）
const capability = (key: string) => planaCapabilities.find((c) => c.key === key)!
const story = [
  {
    key: 'defect-draft',
    scene: '点検で気づく',
    lead: '巡回中に指示の低さに気づいた。メモを書けば、トラブル報告の形に整えます。',
    input: '点検で気づいたこと',
    memo: '朝の巡回でFT-301の指示が低め。\n昨日も同じだった。いつからかは不明。\n現場の流量はまだ確認していない。',
    routineChecks: [
      '導圧管の閉塞（固形物の堆積・凍結・気体/液体の溜まり）。ブロー・貫通棒での貫通でOKになるか',
      'ゼロ点ズレの確認',
      'バルブマニホールド（元弁・平衡弁）が誤って閉止・半開になっていないか',
      '配線・端子の緩み、電源の確認',
      'オリフィス・絞り部の詰まり・付着',
    ],
    planaNote: 'プラナが整理しました。保存する前に確認・修正してください。',
    title: 'FT-301 流量指示の低下',
    meta: '優先度 中',
    detail: '朝の巡回時にFT-301の指示低下を確認。前日も同様の状態だった。発生時期は不明で、現場の流量は未確認。',
    possibleCauses: [
      'オリフィス・絞り部の詰まりの可能性（指示の低下が緩やかで、前日から変わっていないため）',
      '導圧管の閉塞の可能性（急な変化ではなく、進行中の閉塞と考えられるため）',
    ],
    checkPoint: '現場の流量と、FT-301の指示は一致しているか？',
    result: '確認して点検を保存すると、トラブルとして登録されます。',
  },
  {
    key: 'similar-troubles',
    scene: '過去の事例を見る',
    lead: '同じ計器や同じ種類の計器の過去のトラブルから、症状が同じものを探します。',
    input: '1と同じメモで探します',
    memo: '',
    planaNote: 'プラナが選んだ候補です（過去のトラブル9件から）。開いて記録を確かめてください。',
    title: 'FT-301 流量指示の緩やかな低下',
    meta: '完了・優先度 中・2年前',
    similarity: '同じ計器で、指示が低めの状態が続いた点が一致',
    howHandled: '導圧管にスラッジの堆積を確認し、ブローして指示が復旧した',
    result: 'まず導圧管から確かめればよい、と分かります。',
  },
  {
    key: 'response-draft',
    scene: '対応を記録する',
    lead: '作業後のメモを、対応記録の形に整えます。',
    input: '作業後のメモ',
    memo: '導圧管ブローしたら黒いスラッジが出た。\nブロー後は指示が戻った。\n現場の流量計と合ってる。',
    planaNote: 'プラナが整理しました。保存する前に確認・修正してください。',
    title: 'FT-301 導圧管のブロー・指示の復旧確認',
    meta: '対応種別: 修理',
    detail: '導圧管をブローしたところ、黒色のスラッジが排出された。ブロー後に指示の復旧を確認し、現場流量計の指示とも一致した。',
    usedMaterials: 'なし',
    checkPoint: 'スラッジの出どころ（原油の性状の変化など）は分かっているか？',
    result: '保存すると、トラブルの対応記録として残ります。次に同じ症状が出たとき、2の検索で見つかるようになります。',
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
          <p class="landing-lead">石油プラントの保全業務のためのWebアプリです。設備台帳、点検、トラブル、修理、資材の在庫と発注を、同じデータで管理します。</p>
          <a href="#plana" class="landing-hero-plana">
            <PlanaAvatar :size="30" />
            <span><strong>AIアシスタント「プラナ」</strong>点検のメモから報告を作り、過去のトラブルを探します</span>
            <v-icon size="18" aria-hidden="true">mdi-chevron-down</v-icon>
          </a>
          <div>
            <v-btn to="/plana" color="primary" size="x-large">{{ auth.isLoggedIn ? '作業ホームを開く' : 'デモアカウントで試す' }}</v-btn>
          </div>
          <p class="landing-caption">{{ auth.isLoggedIn ? '設備やトラブルを選んで、作業を始められます。' : '登録不要。ログイン画面でデモアカウントを選ぶだけで試せます。' }}</p>
        </div>
        <figure class="landing-hero-shot">
          <a :href="troubleScreenshot" target="_blank" rel="noopener" aria-label="トラブル詳細の画面を拡大する（新しいタブ）"><img :src="troubleScreenshot" width="1144" height="584" alt="トラブル詳細画面。対象設備の常圧蒸留装置、計器PV-201、発生元点検と最近の点検履歴を同じ画面で確認できる。" /></a>
        </figure>
      </div>
    </section>

    <section id="features" class="landing-section" aria-labelledby="features-title">
      <div class="landing-section-heading"><p class="landing-eyebrow">PlantKeeperの機能</p><h2 id="features-title">設備台帳から発注まで</h2><p>点検で見つけた不具合はトラブルになり、修理や資材の手配まで、同じ設備にひもづけて記録します。</p></div>
      <ol class="landing-flow" aria-label="PlantKeeperで管理する保全業務の流れ">
        <li v-for="step in flowSteps" :key="step.title">
          <v-icon size="22" color="primary" aria-hidden="true">{{ step.icon }}</v-icon>
          <strong>{{ step.title }}</strong>
          <span>{{ step.note }}</span>
        </li>
      </ol>
    </section>

    <section id="safety" class="landing-section landing-divided landing-safety" aria-labelledby="safety-title">
      <div class="landing-section-heading">
        <h2 id="safety-title">インターロックのバイパス管理</h2>
        <p>点検や故障対応で一時的に外すインターロックを、申請から復帰の確認まで記録します。外している間は、プラントを守る仕組みがひとつ欠けた状態です。</p>
      </div>
      <div class="landing-safety-body">
        <figure class="landing-hero-shot">
          <a :href="bypassScreenshot" target="_blank" rel="noopener" aria-label="インターロックの詳細の画面を拡大する（新しいタブ）"><img :src="bypassScreenshot" width="1144" height="423" alt="インターロックI-701の詳細画面。予定の復帰を過ぎたバイパスが赤く表示され、理由・代替措置と、申請・承認・バイパス実施の担当者と日時が並ぶ。" /></a>
        </figure>
        <div>
          <ol class="landing-bypass-steps" aria-label="バイパスの流れ">
            <li v-for="step in bypassSteps" :key="step.title"><strong>{{ step.title }}</strong><span v-if="step.note">{{ step.note }}</span></li>
          </ol>
          <p class="landing-body-text">予定の時刻を過ぎても戻っていないバイパスは「復帰期限超過」として目立たせます。定期整備は、対象設備のバイパスがすべて戻るまで検収へ進めません。</p>
        </div>
      </div>
    </section>

    <section id="calibration" class="landing-section landing-divided" aria-labelledby="calibration-title">
      <div class="landing-section-heading">
        <h2 id="calibration-title">校正の記録と点検周期の見直し</h2>
        <p>5点校正の結果を点検で記録し、回ごとの誤差の推移から、点検周期の延長・短縮の候補を出します。</p>
      </div>
      <div class="landing-feature-body">
        <figure class="landing-hero-shot">
          <a :href="calibrationScreenshot" target="_blank" rel="noopener" aria-label="校正の傾向の画面を拡大する（新しいタブ）"><img :src="calibrationScreenshot" width="1120" height="633" alt="計器FT-301の校正の傾向。調整前の最大誤差が0.12、0.25、0.41と年々大きくなり、2026年に0.72%で許容差0.5%を超えて不合格になり、調整後は0.12%に戻っている。" /></a>
          <figcaption>FT-301の校正の傾向。調整前の誤差が年々増え、今年は許容差を超えたため、周期の短縮の候補になります。</figcaption>
        </figure>
        <ul class="landing-points">
          <li v-for="point in calibrationPoints" :key="point.title"><v-icon size="22" color="primary" aria-hidden="true">{{ point.icon }}</v-icon><div><h3>{{ point.title }}</h3><p>{{ point.text }}</p></div></li>
        </ul>
      </div>
    </section>

    <section id="daily" class="landing-section landing-divided" aria-labelledby="daily-title">
      <div class="landing-section-heading">
        <h2 id="daily-title">日々の確認</h2>
        <p>朝会の資料をExcelで作り直したり、機器の異常を別のシステムまで見に行ったりしなくて済むようにしました。</p>
      </div>
      <div class="landing-daily-grid">
        <article>
          <figure class="landing-hero-shot">
            <a :href="meetingBoardScreenshot" target="_blank" rel="noopener" aria-label="朝会・夕会ボードの画面を拡大する（新しいタブ）"><img :src="meetingBoardScreenshot" width="1120" height="1022" alt="朝会・夕会ボードの朝会の画面。川崎製油所 計装保全課の、インターロックのバイパス3件、期限超過・今日・明日が期限の点検計画、実施中の定期整備の作業と進み具合が1枚に並ぶ。" /></a>
          </figure>
          <h3 class="landing-feature-title">朝会・夕会ボード</h3>
          <p class="landing-body-text">点検計画、実施中の定期整備の作業、トラブル、インターロックのバイパスを、部署ごとに1枚で出します。夕会では、今日の実績と、下書きのまま残った点検（積み残し）を分けて出します。A4でそのまま印刷できます。</p>
        </article>
        <article>
          <figure class="landing-hero-shot">
            <a :href="diagnosticsScreenshot" target="_blank" rel="noopener" aria-label="機器の診断で絞り込んだ計器一覧の画面を拡大する（新しいタブ）"><img :src="diagnosticsScreenshot" width="1120" height="427" alt="計器の一覧を機器の診断で絞り込んだ画面。LT-701が仕様外、PT-502が保守要求、TV-602が故障として並ぶ。" /></a>
          </figure>
          <h3 class="landing-feature-title">機器の自己診断（NAMUR NE 107）</h3>
          <p class="landing-body-text">スマート機器の自己診断を、機器管理システム（AMS Device Manager など）から受け取り、計器の一覧と詳細に出します。</p>
          <ul class="landing-diagnostic-states" aria-label="NE 107の状態">
            <li v-for="state in diagnosticStates" :key="state"><DiagnosticChip :status="state" /></li>
          </ul>
        </article>
      </div>
    </section>

    <!-- 2. プラナとは。紹介と仕事を1つの色の帯にまとめ、ここからがプラナだと分かるようにする -->
    <div class="landing-plana-zone">
      <section id="plana" class="landing-plana" aria-labelledby="plana-title">
        <div class="landing-plana-inner">
          <div>
            <p class="landing-eyebrow">PlantKeeperのAIアシスタント</p>
            <h2 id="plana-title">プラナ</h2>
            <p class="landing-plana-tagline">報告を書く手間と、過去の事例を探す手間を減らします。</p>
            <p class="landing-plana-lead">ここまでの機能は、決まったルールで判定し、記録します。プラナはAIで、その記録を読んで、不具合報告や対応記録の文章を整え、似た過去のトラブルを探します。</p>
          </div>
          <figure class="landing-character">
            <PlanaAvatar variant="full" alt="ヘルメットをかぶり、タブレットを持ったAIアシスタント、プラナ" />
          </figure>
        </div>
      </section>

      <!-- 3. 1件のトラブルでたどるプラナの仕事 -->
      <section id="plana-work" class="landing-section" aria-labelledby="plana-work-title">
        <div class="landing-section-heading">
          <h2 id="plana-work-title">1件のトラブルでの使い方</h2>
          <p>流量計FT-301の指示が低い。気づいてから対応を記録するまでに、プラナを使う場面は3つです。<span class="landing-note-inline">メモと記録は架空の例です</span></p>
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
                  <p v-if="step.memo">{{ step.memo }}</p>
                </div>
                <div>
                  <details v-if="step.routineChecks" class="pk-reference">
                    <summary><v-icon size="16" aria-hidden="true">mdi-clipboard-text-outline</v-icon>流量伝送器の一次点検の定型項目（{{ step.routineChecks.length }}件）</summary>
                    <p class="pk-reference-meta">AIではなく、計器の種類ごとに決まった項目です</p>
                    <ul><li v-for="c in step.routineChecks" :key="c">{{ c }}</li></ul>
                  </details>
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
    </div>

    <section id="try-guide" class="landing-section landing-guide" aria-labelledby="try-title">
      <h2 id="try-title">試し方</h2>
      <ol><li>ログイン画面でデモアカウントを選びます。3つとも試すなら、自社の「一般」を選んでください。</li><li>仕事を選び、設備やトラブルを指定して、メモを自分で入力します（上の例は自動では入りません）。</li><li>プラナの案を確認し、保存するかを決めます。</li></ol>
      <p>プラナには1日の利用上限があり、上限に達すると使えなくなります（ほかの機能はそのまま使えます）。</p>
    </section>

    <section id="permissions" class="landing-section" aria-labelledby="permission-title">
      <div class="landing-section-heading"><h2 id="permission-title">自社と協力会社の権限</h2><p>所属と権限によって、見られる情報とできる操作が変わります。デモアカウントは5つの権限に1人ずつあります。対応記録の整理は、協力会社の技能員は使えません。</p></div>
      <details class="landing-permissions"><summary>業務機能の詳しい権限を見る</summary><PermissionMatrix /></details>
    </section>
    <section class="landing-story landing-section">
      <div><h2>開発の背景</h2></div>
      <div><p>石油プラントの計装保全を10年担当していました。紙やExcelに散らばっていた保全の情報を、1か所で扱えるように作ったのがPlantKeeperです。</p><a href="https://github.com/RyotaAraya/plant-keeper" target="_blank" rel="noopener">GitHubで開発の詳細を見る</a></div>
    </section>
    <section class="landing-section landing-final" aria-labelledby="final-title">
      <div><h2 id="final-title">デモを試す</h2></div>
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
.landing-divided { border-top: 1px solid var(--pk-line); }
.landing-section h2 { font-size: 1.875rem; line-height: 1.5; text-wrap: balance; word-break: auto-phrase; }
.landing-section-heading p { font-size: .9375rem; color: var(--pk-muted); margin-top: 12px; line-height: 1.9; }
.landing-note-inline { display: inline-block; margin-left: 8px; padding: 0 8px; font-size: .75rem; border: 1px solid var(--pk-line); border-radius: 999px; }

/* 設備から発注までの流れ。区切り線の上の山形が、次の業務へつながることを示す */
.landing-flow { display: grid; grid-template-columns: repeat(7, minmax(0, 1fr)); margin: 0; padding: 0; list-style: none; border: 1px solid var(--pk-line); border-radius: 12px; }
.landing-flow li { position: relative; display: flex; flex-direction: column; gap: 4px; padding: 14px 14px 16px; border-left: 1px solid var(--pk-line); }
.landing-flow li:first-child { border-left: none; }
.landing-flow li:not(:last-child)::after { content: ''; position: absolute; top: 20px; right: -6px; z-index: 1; width: 11px; height: 11px; background: #fff; border-top: 1px solid var(--pk-steel); border-right: 1px solid var(--pk-steel); transform: rotate(45deg); }
.landing-flow strong { font-family: var(--pk-font-display); font-size: .9375rem; }
.landing-flow span { font-size: .75rem; line-height: 1.55; color: var(--pk-muted); word-break: auto-phrase; }
.landing-safety-body, .landing-feature-body { display: grid; grid-template-columns: minmax(0, 1.25fr) minmax(0, 1fr); gap: 40px; align-items: start; }
.landing-bypass-steps { margin: 0 0 24px; padding: 0; list-style: none; counter-reset: bypass; }
.landing-bypass-steps li { counter-increment: bypass; display: grid; grid-template-columns: 2em 6.5em minmax(0, 1fr); align-items: baseline; gap: 8px; padding: 10px 0; border-bottom: 1px solid var(--pk-line); }
.landing-bypass-steps li::before { content: counter(bypass); color: var(--pk-steel); font-weight: 700; font-variant-numeric: tabular-nums; }
.landing-bypass-steps strong { font-family: var(--pk-font-display); font-size: .9375rem; }
.landing-bypass-steps span { font-size: .8125rem; line-height: 1.7; color: var(--pk-muted); }
.landing-daily-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 48px; align-items: start; }
.landing-daily-grid .landing-feature-title { margin-top: 24px; }
.landing-points { margin: 0; padding: 0; list-style: none; display: grid; gap: 24px; }
.landing-points li { display: flex; gap: 14px; align-items: flex-start; }
.landing-points h3 { font-size: 1rem; margin-bottom: 4px; }
.landing-points p, .landing-body-text { font-size: .875rem; line-height: 1.8; color: var(--pk-muted); }
.landing-feature-title { font-size: 1.125rem; margin-bottom: 8px; }
.landing-diagnostic-states { margin: 16px 0 0; padding: 0; list-style: none; display: flex; flex-wrap: wrap; gap: 8px; }

/* プラナとは。表示は左向きなので、画像を右に置いて文章のほうを向かせる */
.landing-plana-zone { background: var(--pk-soft-blue); }
.landing-plana { background: #dfeefd; overflow: hidden; }
/* 帯の上では、メモと定型項目の面を白にして背景と分ける */
.landing-plana-zone .landing-input, .landing-plana-zone .pk-reference { background: #fff; }
.landing-plana-inner { max-width: 1200px; margin: auto; display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 320px); gap: 56px; align-items: end; padding: 40px 32px 0; }
.landing-plana-inner > div { align-self: center; padding-bottom: 40px; }
.landing-character { margin: 0; }
.landing-character :deep(.pk-plana-full) { display: block; width: 100%; max-width: 320px; transform: scaleX(-1); }
.landing-eyebrow { font-size: .8125rem; color: var(--pk-steel-dark); font-weight: 600; }
.landing-plana h2 { font-family: var(--pk-font-display); font-size: clamp(2.25rem, 5vw, 3.25rem); font-weight: 900; color: var(--pk-plana-navy); line-height: 1.2; margin-top: 4px; }
.landing-plana-tagline { font-family: var(--pk-font-display); font-size: 1.25rem; font-weight: 700; color: var(--pk-plana-navy); margin-top: 8px; }
.landing-plana-lead { font-size: .9375rem; line-height: 1.9; color: var(--pk-muted); margin-top: 12px; max-width: 36em; word-break: auto-phrase; }

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
.pk-reference { border-left: 3px solid var(--pk-steel); background: var(--pk-mist); border-radius: 0 10px 10px 0; padding: 12px 20px; margin-bottom: 16px; }
.pk-reference summary { display: flex; align-items: center; gap: 8px; font-size: .8125rem; font-weight: 700; color: var(--pk-ink); cursor: pointer; }
.pk-reference summary::after { content: '▾'; margin-left: auto; color: var(--pk-steel); }
.pk-reference[open] summary::after { content: '▴'; }
.pk-reference-meta { font-size: .6875rem; color: var(--pk-muted); margin: 8px 0 12px 24px; }
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

.landing-guide { border-top: 1px solid var(--pk-line); padding-block: 32px 48px; scroll-margin-top: 80px; }
.landing-guide h2 { font-size: 1.25rem; }
.landing-guide ol { padding-left: 24px; margin: 20px 0; font-size: .875rem; line-height: 2; }
.landing-guide > p { color: var(--pk-muted); font-size: .875rem; line-height: 1.9; max-width: 70em; }
.landing-permissions { border-block: 1px solid var(--pk-line); }
.landing-permissions summary { cursor: pointer; padding: 20px 0; color: var(--pk-steel); font-weight: 600; }
.landing-permissions[open] { padding-bottom: 24px; }
.landing-final { border-top: 1px solid var(--pk-line); display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 24px; }
.landing-final h2 { font-size: 1.5rem; }
.landing-story { display: grid; grid-template-columns: 1fr 1.5fr; gap: 48px; border-top: 1px solid var(--pk-line); }
.landing-story p { color: var(--pk-muted); line-height: 2; margin-bottom: 16px; font-size: .9375rem; }
.landing-story a { color: var(--pk-steel); font-size: .875rem; }
.landing-footer { border-top: 1px solid var(--pk-line); display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 16px; padding: 24px 32px; font-size: .75rem; color: var(--pk-muted); }
#plana, #plana-work, #features, #safety, #calibration, #daily { scroll-margin-top: 64px; }

@media (max-width: 900px) {
  .landing-hero-inner { grid-template-columns: 1fr; gap: 32px; }
  .landing-safety-body, .landing-feature-body { grid-template-columns: 1fr; gap: 24px; }
  .landing-flow { grid-template-columns: 1fr; }
  .landing-flow li { flex-direction: row; align-items: baseline; gap: 12px; padding: 10px 16px; border-left: none; border-top: 1px solid var(--pk-line); }
  .landing-flow li:first-child { border-top: none; }
  .landing-flow .v-icon { align-self: center; }
  .landing-flow strong { flex: 0 0 4.5em; }
  .landing-flow li:not(:last-child)::after { top: auto; right: auto; bottom: -6px; left: 24px; transform: rotate(135deg); }
  .landing-comparison { grid-template-columns: 1fr; gap: 20px; }
  .landing-daily-grid { grid-template-columns: 1fr; gap: 40px; }
}
@media (max-width: 700px) {
  .landing-hero-inner { padding: 40px 16px; }
  .landing-section { padding: 40px 16px; }
  .landing-plana-inner { grid-template-columns: 1fr; gap: 16px; padding: 32px 16px 0; }
  .landing-character :deep(.pk-plana-full) { width: 200px; margin-inline: auto; }
  .landing-plana-inner > div { padding-bottom: 0; }
  .landing-story, .pk-plana-card-grid { grid-template-columns: 1fr; gap: 24px; }
  .landing-bypass-steps li { grid-template-columns: 1.5em 5.5em minmax(0, 1fr); }
  .landing-step { grid-template-columns: 1fr; gap: 12px; }
  .landing-step:not(:last-child)::before { display: none; }
  .landing-step-marker { width: 32px; height: 32px; }
  .landing-step-footer { align-items: start; flex-direction: column; }
}
</style>
