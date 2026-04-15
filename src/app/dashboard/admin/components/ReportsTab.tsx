'use client'

import { useState, useCallback, useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import {
  Search, ChevronLeft, ChevronRight, Trash2, CheckCircle2, Eye, X, Loader2, Flag
} from 'lucide-react'
import type { AdminReport } from './AdminTypes'

const PAGE_SIZE = 20
const STATUS_COLORS: Record<string, string> = {
  pending: 'bg-amber-100 text-amber-700',
  reviewed: 'bg-blue-100 text-blue-700',
  resolved: 'bg-green-100 text-green-700',
  dismissed: 'bg-gray-100 text-gray-600',
}

const CONTENT_TYPE_LABELS: Record<string, string> = {
  post: 'Beitrag',
  comment: 'Kommentar',
  message: 'Nachricht',
  profile: 'Profil',
  board_post: 'Brett-Beitrag',
  event: 'Veranstaltung',
  organization: 'Organisation',
}

export default function ReportsTab() {
  const [reports, setReports] = useState<AdminReport[]>([])
  const [search, setSearch] = useState('')
  const [statusFilter, setStatus] = useState<string>('')
  const [loading, setLoading] = useState(true)
  const [page, setPage] = useState(0)
  const [total, setTotal] = useState(0)

  const load = useCallback(async () => {
    setLoading(true)
    const supabase = createClient()
    // Escape ilike wildcards so `%` / `_` / `\` in the search string are literal
    const searchTerm = search
      ? search.replace(/\\/g, '\\\\').replace(/%/g, '\\%').replace(/_/g, '\\_')
      : ''
    let query = supabase.from('content_reports')
      .select('id,reporter_id,content_type,content_id,reason,status,created_at,profiles!content_reports_reporter_id_fkey(name,email)', { count: 'exact' })
    if (searchTerm) query = query.ilike('reason', `%${searchTerm}%`)
    if (statusFilter) query = query.eq('status', statusFilter)
    const { data, count, error } = await query
      .order('created_at', { ascending: false })
      .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1)

    if (error) {
      // Table might not have FK yet – try without join. Reassign chained results!
      let fallbackQuery = supabase.from('content_reports')
        .select('id,reporter_id,content_type,content_id,reason,status,created_at', { count: 'exact' })
      if (searchTerm) fallbackQuery = fallbackQuery.ilike('reason', `%${searchTerm}%`)
      if (statusFilter) fallbackQuery = fallbackQuery.eq('status', statusFilter)
      const { data: fbData, count: fbCount, error: fbError } = await fallbackQuery
        .order('created_at', { ascending: false })
        .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1)
      if (fbError) console.error('reports fallback query failed:', fbError.message)
      setReports((fbData ?? []) as AdminReport[])
      setTotal(fbCount ?? 0)
    } else {
      setReports((data ?? []) as AdminReport[])
      setTotal(count ?? 0)
    }
    setLoading(false)
  }, [search, statusFilter, page])

  useEffect(() => { load() }, [load])

  // ── Detail Modal ──
  const [viewReport, setViewReport] = useState<AdminReport | null>(null)
  const [saving, setSaving] = useState(false)

  const handleUpdateStatus = async (id: string, newStatus: string) => {
    setSaving(true)
    const supabase = createClient()
    const { error } = await supabase.from('content_reports').update({ status: newStatus }).eq('id', id)
    if (error) {
      toast.error('Status-Änderung fehlgeschlagen: ' + error.message)
    } else {
      toast.success(`Meldung als "${newStatus}" markiert`)
      setReports(prev => prev.map(r => r.id === id ? { ...r, status: newStatus } : r))
      if (viewReport?.id === id) setViewReport(prev => prev ? { ...prev, status: newStatus } : null)
    }
    setSaving(false)
  }

  const handleDelete = async (id: string) => {
    if (!confirm('Meldung endgültig löschen?')) return
    const supabase = createClient()
    const { error } = await supabase.from('content_reports').delete().eq('id', id)
    if (error) { toast.error('Löschen fehlgeschlagen'); return }
    toast.success('Meldung gelöscht')
    setReports(prev => prev.filter(r => r.id !== id))
    setTotal(prev => prev - 1)
    if (viewReport?.id === id) setViewReport(null)
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap gap-3">
        <div className="relative flex-1 min-w-48">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input type="text" value={search}
            onChange={e => { setSearch(e.target.value); setPage(0) }}
            placeholder="Grund suchen..."
            className="w-full pl-9 pr-4 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-green-300"
          />
        </div>
        <select value={statusFilter} onChange={e => { setStatus(e.target.value); setPage(0) }}
          className="px-3 py-2.5 border border-gray-200 rounded-xl text-sm">
          <option value="">Alle Status</option>
          <option value="pending">Ausstehend</option>
          <option value="reviewed">Geprüft</option>
          <option value="resolved">Gelöst</option>
          <option value="dismissed">Abgelehnt</option>
        </select>
      </div>

      {loading ? (
        <div className="flex justify-center py-12">
          <div className="w-8 h-8 border-4 border-green-400 border-t-transparent rounded-full animate-spin" />
        </div>
      ) : (
        <>
          <p className="text-sm text-gray-500">{total} Meldungen</p>
          <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="bg-gray-50 border-b border-gray-100">
                  <tr>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">Typ</th>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">Grund</th>
                    <th className="text-center px-4 py-3 font-semibold text-gray-700">Status</th>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">Melder</th>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">Datum</th>
                    <th className="text-right px-4 py-3 font-semibold text-gray-700">Aktionen</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-50">
                  {reports.map(r => (
                    <tr key={r.id} className="hover:bg-gray-50 transition-colors">
                      <td className="px-4 py-3 text-gray-600 text-xs">
                        <span className="inline-flex px-2 py-0.5 bg-gray-100 rounded-full text-xs font-medium">
                          {CONTENT_TYPE_LABELS[r.content_type] ?? r.content_type}
                        </span>
                      </td>
                      <td className="px-4 py-3 font-medium text-gray-900 max-w-56 truncate">{r.reason}</td>
                      <td className="px-4 py-3 text-center">
                        <span className={`inline-flex px-2 py-0.5 rounded-full text-xs font-semibold ${STATUS_COLORS[r.status] ?? 'bg-gray-100 text-gray-600'}`}>
                          {r.status}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-gray-500 text-xs">{(r.reporter as any)?.name ?? r.reporter_id?.slice(0, 8)}</td>
                      <td className="px-4 py-3 text-gray-500 text-xs">{new Date(r.created_at).toLocaleDateString('de-AT')}</td>
                      <td className="px-4 py-3 text-right">
                        <div className="flex items-center gap-1 justify-end">
                          <button onClick={() => setViewReport(r)}
                            className="p-1.5 rounded-lg text-gray-400 hover:text-blue-600 hover:bg-blue-50 transition-colors" title="Details">
                            <Eye className="w-4 h-4" />
                          </button>
                          {r.status === 'pending' && (
                            <button onClick={() => handleUpdateStatus(r.id, 'reviewed')}
                              className="p-1.5 rounded-lg text-gray-400 hover:text-green-600 hover:bg-green-50 transition-colors" title="Als geprüft markieren">
                              <CheckCircle2 className="w-4 h-4" />
                            </button>
                          )}
                          <button onClick={() => handleDelete(r.id)}
                            className="p-1.5 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 transition-colors" title="Löschen">
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                  {reports.length === 0 && (
                    <tr>
                      <td colSpan={6} className="px-4 py-12 text-center text-gray-400">
                        <Flag className="w-8 h-8 mx-auto mb-2 text-gray-300" />
                        Keine Meldungen gefunden
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>

          <div className="flex items-center justify-between">
            <button onClick={() => setPage(p => Math.max(0, p - 1))} disabled={page === 0}
              className="flex items-center gap-1 px-3 py-2 text-sm text-gray-600 hover:text-gray-900 disabled:opacity-40">
              <ChevronLeft className="w-4 h-4" /> Zurück
            </button>
            <span className="text-sm text-gray-500">Seite {page + 1} von {Math.max(1, Math.ceil(total / PAGE_SIZE))}</span>
            <button onClick={() => setPage(p => p + 1)} disabled={reports.length < PAGE_SIZE}
              className="flex items-center gap-1 px-3 py-2 text-sm text-gray-600 hover:text-gray-900 disabled:opacity-40">
              Weiter <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        </>
      )}

      {/* ── Detail Modal ── */}
      {viewReport && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md p-6 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-gray-900 text-lg flex items-center gap-2">
                <Flag className="w-5 h-5 text-red-500" /> Meldung Details
              </h3>
              <button onClick={() => setViewReport(null)} className="p-1.5 rounded-lg hover:bg-gray-100 text-gray-500">
                <X className="w-4 h-4" />
              </button>
            </div>
            <div className="space-y-3">
              <div>
                <label className="block text-xs font-semibold text-gray-500 mb-1">Typ</label>
                <p className="text-sm text-gray-900">{CONTENT_TYPE_LABELS[viewReport.content_type] ?? viewReport.content_type}</p>
              </div>
              <div>
                <label className="block text-xs font-semibold text-gray-500 mb-1">Inhalt-ID</label>
                <p className="text-sm text-gray-700 font-mono text-xs break-all">{viewReport.content_id}</p>
              </div>
              <div>
                <label className="block text-xs font-semibold text-gray-500 mb-1">Grund</label>
                <p className="text-sm text-gray-900">{viewReport.reason}</p>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-semibold text-gray-500 mb-1">Status</label>
                  <span className={`inline-flex px-2 py-0.5 rounded-full text-xs font-semibold ${STATUS_COLORS[viewReport.status] ?? 'bg-gray-100'}`}>
                    {viewReport.status}
                  </span>
                </div>
                <div>
                  <label className="block text-xs font-semibold text-gray-500 mb-1">Datum</label>
                  <p className="text-sm text-gray-700">{new Date(viewReport.created_at).toLocaleDateString('de-AT')}</p>
                </div>
              </div>
            </div>
            <div className="flex gap-2 pt-2">
              {viewReport.status === 'pending' && (
                <button onClick={() => handleUpdateStatus(viewReport.id, 'reviewed')} disabled={saving}
                  className="flex-1 flex items-center justify-center gap-2 px-3 py-2.5 bg-blue-600 text-white rounded-xl text-sm font-semibold hover:bg-blue-700 transition-colors disabled:opacity-50">
                  {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <CheckCircle2 className="w-4 h-4" />}
                  Geprüft
                </button>
              )}
              {viewReport.status !== 'resolved' && (
                <button onClick={() => handleUpdateStatus(viewReport.id, 'resolved')} disabled={saving}
                  className="flex-1 flex items-center justify-center gap-2 px-3 py-2.5 bg-green-600 text-white rounded-xl text-sm font-semibold hover:bg-green-700 transition-colors disabled:opacity-50">
                  {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <CheckCircle2 className="w-4 h-4" />}
                  Gelöst
                </button>
              )}
              {viewReport.status !== 'dismissed' && (
                <button onClick={() => handleUpdateStatus(viewReport.id, 'dismissed')} disabled={saving}
                  className="flex-1 flex items-center justify-center gap-2 px-3 py-2.5 bg-gray-500 text-white rounded-xl text-sm font-semibold hover:bg-gray-600 transition-colors disabled:opacity-50">
                  Ablehnen
                </button>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
