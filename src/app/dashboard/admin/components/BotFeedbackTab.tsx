'use client'

import { useCallback, useEffect, useMemo, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { ThumbsUp, ThumbsDown, Loader2, MessageSquare, BarChart3 } from 'lucide-react'

// Nur zur internen Verwendung — das Schema lebt in supabase/migrations/20260416_bot_feedback.sql
interface BotFeedbackRow {
  id: string
  created_at: string
  user_id: string | null
  message_id: string | null
  rating: 'up' | 'down'
  question: string | null
  answer: string | null
  route: string | null
}

function truncate(s: string | null, max: number): string {
  if (!s) return ''
  return s.length > max ? s.slice(0, max - 1).trimEnd() + '…' : s
}

function formatDate(iso: string): string {
  try {
    return new Date(iso).toLocaleString('de-DE', {
      day: '2-digit',
      month: '2-digit',
      year: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
    })
  } catch {
    return iso
  }
}

export default function BotFeedbackTab() {
  const [rows, setRows] = useState<BotFeedbackRow[]>([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState<'all' | 'up' | 'down'>('all')

  const load = useCallback(async () => {
    setLoading(true)
    const supabase = createClient()
    const { data, error } = await supabase
      .from('bot_feedback')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(200)
    if (error) {
      console.error('bot_feedback load failed:', error.message)
      setRows([])
    } else {
      setRows((data ?? []) as BotFeedbackRow[])
    }
    setLoading(false)
  }, [])

  useEffect(() => { load() }, [load])

  // ── Zusammenfassung (letzte 7 Tage + top-Routen) ──────────────────
  const summary = useMemo(() => {
    const now = Date.now()
    const weekAgo = now - 7 * 24 * 60 * 60 * 1000
    let up7 = 0
    let down7 = 0
    const byRoute = new Map<string, { up: number; down: number }>()
    for (const r of rows) {
      const t = new Date(r.created_at).getTime()
      if (t >= weekAgo) {
        if (r.rating === 'up') up7 += 1
        else if (r.rating === 'down') down7 += 1
      }
      const key = r.route || '(unbekannt)'
      const rec = byRoute.get(key) ?? { up: 0, down: 0 }
      if (r.rating === 'up') rec.up += 1
      else rec.down += 1
      byRoute.set(key, rec)
    }
    const topRoutes = Array.from(byRoute.entries())
      .map(([route, v]) => ({ route, total: v.up + v.down, up: v.up, down: v.down }))
      .sort((a, b) => b.total - a.total)
      .slice(0, 3)
    const total7 = up7 + down7
    const ratio7 = total7 > 0 ? Math.round((up7 / total7) * 100) : null
    return { total: rows.length, up7, down7, ratio7, topRoutes }
  }, [rows])

  const filtered = useMemo(
    () => rows.filter(r => filter === 'all' ? true : r.rating === filter),
    [rows, filter],
  )

  return (
    <div className="space-y-5">
      {/* ── Summary Cards ────────────────────────────────────────── */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
        <div className="bg-white rounded-2xl border border-stone-100 shadow-sm p-4">
          <div className="flex items-center gap-2 mb-1.5 text-ink-400">
            <MessageSquare className="w-3.5 h-3.5" />
            <span className="text-[10px] font-black uppercase tracking-wider">Gesamt</span>
          </div>
          <p className="text-2xl font-bold text-ink-900">{summary.total}</p>
          <p className="text-[11px] text-ink-500 mt-0.5">geladen (max. 200)</p>
        </div>
        <div className="bg-white rounded-2xl border border-stone-100 shadow-sm p-4">
          <div className="flex items-center gap-2 mb-1.5 text-ink-400">
            <BarChart3 className="w-3.5 h-3.5" />
            <span className="text-[10px] font-black uppercase tracking-wider">7 Tage Ratio</span>
          </div>
          <p className="text-2xl font-bold text-ink-900">
            {summary.ratio7 === null ? '—' : `${summary.ratio7}%`}
          </p>
          <p className="text-[11px] text-ink-500 mt-0.5">
            <span className="text-primary-700 font-semibold">{summary.up7} 👍</span>
            {' · '}
            <span className="text-red-600 font-semibold">{summary.down7} 👎</span>
          </p>
        </div>
        <div className="bg-white rounded-2xl border border-stone-100 shadow-sm p-4">
          <div className="flex items-center gap-2 mb-1.5 text-ink-400">
            <span className="text-[10px] font-black uppercase tracking-wider">Top-Routen</span>
          </div>
          {summary.topRoutes.length === 0 ? (
            <p className="text-sm text-ink-400">Noch keine Daten</p>
          ) : (
            <ul className="space-y-1">
              {summary.topRoutes.map(r => (
                <li key={r.route} className="flex items-center justify-between text-[11px]">
                  <span className="truncate text-ink-600 font-mono">{r.route}</span>
                  <span className="text-ink-400 flex-shrink-0 ml-2">
                    {r.total} <span className="text-primary-600">👍{r.up}</span>{' '}
                    <span className="text-red-500">👎{r.down}</span>
                  </span>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>

      {/* ── Filter + Table ───────────────────────────────────────── */}
      <div className="bg-white rounded-2xl border border-stone-100 shadow-sm overflow-hidden">
        <div className="flex items-center justify-between gap-3 px-4 py-3 border-b border-stone-100">
          <div className="flex items-center gap-1.5">
            {(['all', 'up', 'down'] as const).map(k => (
              <button
                key={k}
                onClick={() => setFilter(k)}
                className={`text-[11px] px-2.5 py-1 rounded-full font-medium transition-colors ${
                  filter === k
                    ? 'bg-primary-600 text-white'
                    : 'bg-stone-50 text-ink-500 hover:bg-stone-100'
                }`}
              >
                {k === 'all' ? 'Alle' : k === 'up' ? '👍 Positiv' : '👎 Negativ'}
              </button>
            ))}
          </div>
          <button
            onClick={load}
            className="text-[11px] text-ink-400 hover:text-primary-600 transition-colors"
          >
            Neu laden
          </button>
        </div>

        {loading ? (
          <div className="flex items-center justify-center py-16">
            <Loader2 className="w-6 h-6 text-primary-400 animate-spin" />
          </div>
        ) : filtered.length === 0 ? (
          <div className="py-16 text-center text-sm text-ink-400">
            Noch kein Feedback vorhanden.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-stone-50 border-b border-stone-100">
                <tr className="text-[10px] font-black uppercase tracking-wider text-ink-400">
                  <th className="px-4 py-2.5 text-left">Zeit</th>
                  <th className="px-4 py-2.5 text-left">Route</th>
                  <th className="px-4 py-2.5 text-left">Frage</th>
                  <th className="px-4 py-2.5 text-left">Antwort</th>
                  <th className="px-4 py-2.5 text-center">Bewertung</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-50">
                {filtered.map(r => (
                  <tr key={r.id} className="hover:bg-stone-50/50 transition-colors">
                    <td className="px-4 py-2.5 text-[11px] text-ink-500 whitespace-nowrap">
                      {formatDate(r.created_at)}
                    </td>
                    <td className="px-4 py-2.5 text-[11px] text-ink-500 font-mono whitespace-nowrap">
                      {r.route ?? '—'}
                    </td>
                    <td className="px-4 py-2.5 text-xs text-ink-700 max-w-[240px]">
                      {truncate(r.question, 80) || <span className="text-gray-300">—</span>}
                    </td>
                    <td className="px-4 py-2.5 text-xs text-ink-500 max-w-[320px]">
                      {truncate(r.answer, 120) || <span className="text-gray-300">—</span>}
                    </td>
                    <td className="px-4 py-2.5 text-center">
                      {r.rating === 'up' ? (
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-primary-50 text-primary-700 text-[11px] font-semibold">
                          <ThumbsUp className="w-3 h-3" /> positiv
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-red-50 text-red-600 text-[11px] font-semibold">
                          <ThumbsDown className="w-3 h-3" /> negativ
                        </span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  )
}
