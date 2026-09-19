// CSV出力。Excelで文字化けしないよう UTF-8 の BOM を付ける。
// 「=」「+」「-」「@」で始まるセルは、Excelが数式として実行しないよう先頭に「'」を付ける（ユーザが入力した文字が入り得るため）

const FORMULA_START = /^[=+\-@\t\r]/

function cell(value: unknown): string {
  let s = value == null ? '' : String(value)
  if (FORMULA_START.test(s)) s = `'${s}`
  return /[",\r\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s
}

export function toCsv(rows: unknown[][]): string {
  return rows.map((row) => row.map(cell).join(',')).join('\r\n') + '\r\n'
}

export function downloadCsv(filename: string, rows: unknown[][]) {
  const blob = new Blob(['﻿', toCsv(rows)], { type: 'text/csv;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  document.body.appendChild(link)
  link.click()
  link.remove()
  URL.revokeObjectURL(url)
}
