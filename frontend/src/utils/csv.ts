// CSV出力。Excelで文字化けしないよう UTF-8 の BOM を付ける。
// 「=」「+」「-」「@」で始まるセルは、Excelが数式として実行しないよう先頭に「'」を付ける（ユーザが入力した文字が入り得るため）
import { downloadBlob } from '@/utils/download'

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
  downloadBlob(filename, new Blob(['﻿', toCsv(rows)], { type: 'text/csv;charset=utf-8' }))
}
