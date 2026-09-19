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
