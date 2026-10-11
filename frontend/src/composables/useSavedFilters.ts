import type { LocationQuery } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

// 一覧の検索条件を、ユーザ・ページごとにブラウザ（localStorage）へ保存して、開き直したときに戻す。
// 保存するのは、ユーザが絞り込みを操作したときだけ。初期表示・URL・リセットで入れた値は保存しない（`hold`）。
// 保存データが壊れている・型が違う・localStorage が使えないときは、保存がないものとして扱う（一覧は既定の条件で開く）

// 項目の型。ids=正の整数の配列、id=正の整数か null、boolean、strings/string=文字列（values を渡すとその値だけ、pattern を渡すとその形だけを認める。空文字は常に可）
export type FilterField =
  | 'ids'
  | 'id'
  | 'boolean'
  | { type: 'strings' | 'string'; values?: readonly string[]; pattern?: RegExp }
export type FilterSchema = Record<string, FilterField>

const VERSION = 'v1'

export function savedFiltersKey(userId: number, page: string): string {
  return `plant-keeper:list-filters:${VERSION}:${userId}:${page}`
}

const isId = (v: unknown): v is number => typeof v === 'number' && Number.isInteger(v) && v > 0

// 項目ごとに型を確かめ、通ったものだけを返す（通らない項目は既定の値のまま）。空の配列・空文字・false・null も有効な値（絞り込みなし）
export function sanitizeFilters(raw: unknown, schema: FilterSchema): Record<string, unknown> {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return {}
  const result: Record<string, unknown> = {}
  for (const [key, field] of Object.entries(schema)) {
    if (!(key in raw)) continue
    const value = (raw as Record<string, unknown>)[key]
    if (field === 'ids') {
      if (Array.isArray(value) && value.every(isId)) result[key] = [...new Set(value)]
    } else if (field === 'id') {
      if (value === null || isId(value)) result[key] = value
    } else if (field === 'boolean') {
      if (typeof value === 'boolean') result[key] = value
    } else {
      const allowed = (v: unknown) =>
        typeof v === 'string' && (v === '' || ((!field.values || field.values.includes(v)) && (!field.pattern || field.pattern.test(v))))
      if (field.type === 'strings' && Array.isArray(value) && value.every(allowed)) result[key] = [...new Set(value)]
      if (field.type === 'string' && (value === null || allowed(value))) result[key] = value
    }
  }
  return result
}

// URL に検索条件があるか（`view`・`tab` は表示の切り替えで、検索条件ではない）
const NON_CONDITION_KEYS = ['view', 'tab']
export function hasQueryConditions(query: LocationQuery): boolean {
  return Object.keys(query).some((key) => !NON_CONDITION_KEYS.includes(key))
}

// URL から検索条件を外したクエリ（リセットで使う。`view`・`tab` は残す）
export function withoutQueryConditions(query: LocationQuery): LocationQuery {
  return Object.fromEntries(Object.entries(query).filter(([key]) => NON_CONDITION_KEYS.includes(key)))
}

export function useSavedFilters<T extends object>(page: string, schema: FilterSchema) {
  const authStore = useAuthStore()
  // 保存しない値（初期表示・URL・リセットで入れた値）。同じ値の変更通知では保存しない
  let held: string | null = null

  // ユーザが確定する前は読み書きしない（別のユーザの条件と混ざらないように）
  const key = () => (authStore.user ? savedFiltersKey(authStore.user.id, page) : null)
  const pick = (values: T) => JSON.stringify(Object.fromEntries(Object.keys(schema).map((k) => [k, (values as Record<string, unknown>)[k]])))

  function load(): Partial<T> {
    const k = key()
    if (!k) return {}
    try {
      const text = localStorage.getItem(k)
      return text ? (sanitizeFilters(JSON.parse(text), schema) as Partial<T>) : {}
    } catch {
      return {}
    }
  }

  function save(values: T) {
    const json = pick(values)
    if (json === held) return
    held = null
    const k = key()
    if (!k) return
    try {
      localStorage.setItem(k, json)
    } catch {
      // 保存できなくても一覧は使える
    }
  }

  function hold(values: T) {
    held = pick(values)
  }

  function clear() {
    const k = key()
    if (!k) return
    try {
      localStorage.removeItem(k)
    } catch {
      // 同上
    }
  }

  return { load, save, hold, clear }
}
