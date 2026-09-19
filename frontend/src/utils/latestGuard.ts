// 続けて呼ばれる取得（拠点や絞り込みを続けて変えたとき）は、応答の順序が入れ替わることがある。
// 古い取得の応答が後から返って新しい結果を上書きしないよう、取得の開始時に guard() を呼び、
// 応答を受け取ったら返り値（isLatest）が true のときだけ反映する
export function latestGuard() {
  let current = 0
  return () => {
    const mine = ++current
    return () => mine === current
  }
}
