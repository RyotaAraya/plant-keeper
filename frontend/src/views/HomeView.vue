<script setup lang="ts">
import { useAuthStore } from '@/stores/auth'
import PermissionMatrix from '@/components/PermissionMatrix.vue'
import PlanaAvatar from '@/components/plana/PlanaAvatar.vue'
import { planaCapabilities } from '@/constants/planaCapabilities'

const auth = useAuthStore()
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
      <div class="landing-hero-copy">
        <p class="landing-intro">保全の現場に、AIアシスタントのプラナを。</p>
        <h1 id="hero-title">現場のメモから、<br />次につながる記録へ。</h1>
        <p class="landing-lead">報告を整える。似た事例を探す。対応を残す。<br class="d-none d-sm-inline" />今日の保全を、ここから進めましょう。</p>
        <v-btn to="/plana" color="primary" size="x-large" class="landing-cta">{{ auth.isLoggedIn ? '仕事を始める' : 'プラナを試す' }}</v-btn>
        <p class="landing-caption">{{ auth.isLoggedIn ? '設備やトラブルを選んで、作業を始められます。' : '登録不要。5つの権限のデモアカウントで体験できます。' }}</p>
      </div>
      <div class="landing-scene" aria-label="プラナがメモを下書きに整える表示例">
        <div class="landing-character"><PlanaAvatar variant="full" alt="ヘルメットをかぶり、タブレットを持ったAIアシスタント、プラナ" /></div>
        <div class="landing-example">
          <p class="landing-example-label">現場メモ → 報告の下書き <span>表示例</span></p>
          <blockquote>流量の指示が低い。<br />導圧管のつまりが疑われる。</blockquote>
          <div class="landing-proposal"><PlanaAvatar :size="30" /><strong>報告の下書き</strong></div>
          <h2>流量指示低下・導圧管閉塞の疑い</h2>
          <p>流量の指示が低下している。現場では導圧管の閉塞が疑われている。</p>
          <p class="landing-review"><v-icon size="18" aria-hidden="true">mdi-check-circle-outline</v-icon>内容を確認してから、記録に反映</p>
        </div>
      </div>
    </section>

    <section class="landing-section" aria-labelledby="work-title">
      <div class="landing-section-heading"><h2 id="work-title">何から始めますか？</h2><p>いま必要な仕事から、そのまま始められます。</p></div>
      <div class="landing-work">
        <router-link v-for="task in planaCapabilities" :key="task.key" :to="task.to">
          <v-icon size="28" color="primary" aria-hidden="true">{{ task.icon }}</v-icon>
          <h3>{{ task.title }}</h3><p>{{ task.summary }}</p>
          <span>この仕事を始める <v-icon size="18" aria-hidden="true">mdi-chevron-right</v-icon></span>
        </router-link>
      </div>
      <p class="landing-caption">利用できる操作は権限によって異なります。AIが無効・利用上限に達した場合も、通常の記録入力は続けられます。</p>
    </section>

    <section class="landing-foundation">
      <div class="landing-section">
        <div class="landing-section-heading"><h2>支えになるのは、現場の記録。</h2><p>PlantKeeperは、設備から点検・対応・資材までをつなぐ保全管理アプリです。</p></div>
        <div class="landing-foundation-grid"><article v-for="item in foundations" :key="item.title"><v-icon size="24" color="primary" aria-hidden="true">{{ item.icon }}</v-icon><h3>{{ item.title }}</h3><p>{{ item.description }}</p></article></div>
      </div>
    </section>
    <section id="permissions" class="landing-section" aria-labelledby="permission-title">
      <div class="landing-section-heading"><h2 id="permission-title">自社も協力会社も、同じ記録で。</h2><p>所属と権限に合わせて、見られる情報・できる操作を分けています。</p></div>
      <PermissionMatrix />
    </section>
    <section class="landing-story landing-section">
      <div><h2>計装保全の現場から<br />生まれたPlantKeeper。</h2></div>
      <div><p>石油プラントの計装保全に10年間携わった経験から、紙やExcelに分かれていた情報をつなぐために作りました。</p><p>現場で見たことを、次の人が使える記録にする。プラナは、その記録づくりと過去の事例探しを手伝います。提案を採用するか、何を記録するかは、人が決めます。</p><a href="https://github.com/RyotaAraya/plant-keeper" target="_blank" rel="noopener">GitHubで開発の詳細を見る</a></div>
    </section>
    <footer class="landing-footer"><span>PlantKeeper</span><span>Developed by Ryota Araya</span><v-btn variant="text" to="/plana">仕事を始める</v-btn></footer>
  </v-main>
</template>

<style scoped>
.landing { background: #fff; }
.landing-brand { font-weight: 700; font-family: var(--pk-font-display); }
.landing-hero { display: grid; grid-template-columns: 1fr 1fr; gap: 40px; align-items: center; padding: 72px max(32px, calc((100vw - 1200px) / 2)) 80px; background: var(--pk-mist); }
.landing-intro { color: var(--pk-steel-dark); font-size: .9375rem; font-weight: 600; margin-bottom: 24px; }
.landing-hero h1 { font-size: clamp(2rem, 3.6vw, 3.3rem); line-height: 1.4; letter-spacing: .015em; color: var(--pk-plana-navy); }
.landing-lead { font-size: 1rem; line-height: 2; margin: 24px 0 28px; color: var(--pk-muted); }
.landing-caption { font-size: .75rem; line-height: 1.9; color: var(--pk-muted); margin-top: 16px; }
.landing-scene { position: relative; min-height: 470px; display: flex; align-items: flex-end; justify-content: flex-start; padding: 140px 38px 0 0; }
.landing-character { position: absolute; width: 190px; right: 0; top: -15px; }
.landing-example { position: relative; width: 100%; padding: 24px; border: 1px solid var(--pk-line); border-radius: 16px; background: #fff; box-shadow: 0 16px 40px -24px #12306b55; }
.landing-example-label { display: flex; flex-wrap: wrap; gap: 8px; justify-content: space-between; font-size: .75rem; font-weight: 600; color: var(--pk-muted); }
.landing-example-label span { font-weight: 400; }
.landing-example blockquote { margin: 16px 0 24px; border-left: 3px solid var(--pk-line); padding-left: 14px; font-size: .9375rem; line-height: 1.9; }
.landing-proposal { display: flex; align-items: center; gap: 8px; color: var(--pk-steel); font-size: .8125rem; }
.landing-example h2 { font-size: 1rem; margin: 14px 0 8px; }
.landing-example > p:not(.landing-example-label) { font-size: .8125rem; line-height: 1.9; color: var(--pk-muted); }
.landing-review { border-top: 1px solid var(--pk-line); padding-top: 14px; margin-top: 18px; display: flex; align-items: center; gap: 8px; }
.landing-section { max-width: 1264px; margin-inline: auto; padding: 64px 32px; }
.landing-section-heading { margin-bottom: 32px; }
.landing-section h2 { font-size: clamp(1.4rem, 2.5vw, 1.9rem); line-height: 1.5; }
.landing-section-heading p { font-size: .9375rem; color: var(--pk-muted); margin-top: 12px; line-height: 1.9; }
.landing-work { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 24px; }
.landing-work a { color: var(--pk-ink); text-decoration: none; border-top: 2px solid var(--pk-line); padding: 24px 8px 12px; }
.landing-work a:hover { border-color: var(--pk-steel); background: var(--pk-mist); }
.landing-work h3, .landing-foundation h3 { font-size: 1.125rem; margin: 16px 0 12px; }
.landing-work p, .landing-foundation p { font-size: .875rem; line-height: 1.9; color: var(--pk-muted); }
.landing-work a > span { display: block; margin-top: 24px; font-size: .875rem; color: var(--pk-steel); font-weight: 600; }
.landing-foundation { background: var(--pk-mist); }
.landing-foundation-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 40px; }
.landing-story { display: grid; grid-template-columns: 1fr 1.5fr; gap: 48px; border-top: 1px solid var(--pk-line); }
.landing-story p { color: var(--pk-muted); line-height: 2; margin-bottom: 16px; font-size: .9375rem; }
.landing-story a { color: var(--pk-steel); font-size: .875rem; }
.landing-footer { border-top: 1px solid var(--pk-line); display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 16px; padding: 24px 32px; font-size: .75rem; color: var(--pk-muted); }
@media (max-width: 960px) { .landing-hero { grid-template-columns: 1fr; gap: 8px; padding: 48px 32px; } .landing-scene { max-width: 580px; width: 100%; justify-self: center; min-height: 420px; } .landing-character { top: 0; } }
@media (max-width: 600px) { .landing-hero { padding: 32px 20px; } .landing-intro { font-size: .8125rem; margin-bottom: 16px; } .landing-lead { font-size: .875rem; } .landing-scene { padding: 128px 0 0; min-height: 0; } .landing-character { width: 150px; right: 8px; } .landing-example { padding: 20px; } .landing-section { padding: 40px 20px; } .landing-work, .landing-foundation-grid, .landing-story { grid-template-columns: 1fr; gap: 24px; } .landing-work a { padding: 20px 4px; } .landing-work a > span { margin-top: 16px; } .landing-footer { padding: 24px 20px; } }
</style>
