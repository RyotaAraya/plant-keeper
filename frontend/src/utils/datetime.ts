// フォームの初期値用。toISOString() はUTCなので、日本時間の朝（0〜9時）に「前日」になってしまう。
// ブラウザのローカル時刻（日本のユーザなら日本時間）で組み立てる。
// datetime-local 入力の値は 'YYYY-MM-DDTHH:mm'、date 入力の値は 'YYYY-MM-DD'。
// サーバは日本時間として解釈し、日時は「+09:00」付きで返す（アプリのタイムゾーンが日本時間のため）

const pad = (n: number) => String(n).padStart(2, '0')

export function todayForInput(d: Date = new Date()): string {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
}

export function nowForInput(d: Date = new Date()): string {
  return `${todayForInput(d)}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}

// 期間の初期値用。n か月前の同じ日（月末をはみ出す場合はその月の末日）
export function monthsAgoForInput(months: number, d: Date = new Date()): string {
  const target = new Date(d.getFullYear(), d.getMonth() - months, 1)
  const lastDay = new Date(target.getFullYear(), target.getMonth() + 1, 0).getDate()
  target.setDate(Math.min(d.getDate(), lastDay))
  return todayForInput(target)
}

// 記録の表示用。端末の時刻帯にかかわらず、業務上の日本時間の日付で表示する。
export function formatDate(value: string | null | undefined): string {
  if (!value) return ''
  return new Date(value).toLocaleDateString('ja-JP', {
    timeZone: 'Asia/Tokyo', year: 'numeric', month: '2-digit', day: '2-digit',
  })
}

// 一覧・詳細の暦日の表示（YYYY/MM/DD。#166）。暦日の文字列（'YYYY-MM-DD'）は時刻帯で日付をずらさずに区切りだけ変え、
// 日時は formatDate と同じく日本時間の日付にする。空は「—」（0 や意味のある状態の文言は呼び出し側で扱う）
export function formatDay(value: string | null | undefined): string {
  if (!value) return '—'
  const day = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value)
  if (day) return `${day[1]}/${day[2]}/${day[3]}`
  return formatDate(value) || '—'
}
