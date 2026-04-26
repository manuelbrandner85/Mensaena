'use client'

import { useState, useEffect, useCallback } from 'react'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import {
  Sparkles, Database, RefreshCw, Clock, CheckCircle2,
  AlertTriangle, Wrench, ScrollText
} from 'lucide-react'

interface CleanupResult {
  expired_posts?: number
  expired_board_posts?: number
  old_notifications?: number
  orphaned_messages?: number
  [key: string]: number | string | undefined
}

export default function SystemTab() {
  const [cleanupResult, setCleanupResult] = useState<CleanupResult | null>(null)
  const [running, setRunning]             = useState(false)
  const [lastRun, setLastRun]             = useState<string | null>(null)

  const runCleanup = async () => {
    setRunning(true)
    const supabase = createClient()
    const { data, error } = await supabase.rpc('run_scheduled_cleanup')
    if (error) {
      toast.error('Cleanup fehlgeschlagen: ' + error.message)
      setRunning(false)
      return
    }
    setCleanupResult(data as CleanupResult)
    setLastRun(new Date().toLocaleString('de-AT'))
    toast.success('Cleanup abgeschlossen')
    setRunning(false)
  }

  return (
    <div className="space-y-6">
      {/* Cleanup Section */}
      <div className="bg-white rounded-2xl border border-stone-100 shadow-sm p-6">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h3 className="font-bold text-ink-900 flex items-center gap-2">
              <Sparkles className="w-5 h-5 text-amber-500" /> System-Cleanup
            </h3>
            <p className="text-sm text-ink-500 mt-1">
              Bereinigt abgelaufene Beiträge, alte Benachrichtigungen und verwaiste Daten.
            </p>
          </div>
          <button onClick={runCleanup} disabled={running}
            className="flex items-center gap-2 px-5 py-2.5 bg-amber-500 text-white rounded-xl text-sm font-semibold hover:bg-amber-600 transition-colors disabled:opacity-50">
            {running ? (
              <><div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" /> Läuft...</>
            ) : (
              <><Sparkles className="w-4 h-4" /> Cleanup starten</>
            )}
          </button>
        </div>

        {lastRun && (
          <p className="text-xs text-ink-400 flex items-center gap-1 mb-4">
            <Clock className="w-3 h-3" /> Letzter Lauf: {lastRun}
          </p>
        )}

        {cleanupResult && (
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
            {Object.entries(cleanupResult).map(([key, value]) => (
              <div key={key} className="bg-stone-50 rounded-xl p-4">
                <p className="text-xs text-ink-500 mb-1 capitalize">{key.replace(/_/g, ' ')}</p>
                <p className="text-xl font-bold text-ink-900">{String(value)}</p>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* System Info */}
      <div className="bg-white rounded-2xl border border-stone-100 shadow-sm p-6">
        <h3 className="font-bold text-ink-900 flex items-center gap-2 mb-4">
          <Database className="w-5 h-5 text-blue-500" /> System-Info
        </h3>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <InfoCard icon={<Wrench className="w-4 h-4 text-ink-400" />} label="Version" value="1.0.0-beta" />
          <InfoCard icon={<Database className="w-4 h-4 text-ink-400" />} label="Supabase" value="huaqldjkgyosefzfhjnf" />
          <InfoCard icon={<CheckCircle2 className="w-4 h-4 text-green-500" />} label="Deploy" value="Cloudflare Pages" />
          <InfoCard icon={<AlertTriangle className="w-4 h-4 text-amber-500" />} label="Stack" value="Next.js 15.3 + React 19" />
        </div>
      </div>

      {/* Audit Logs */}
      <AuditLogViewer />

      {/* Quick Links */}
      <div className="bg-white rounded-2xl border border-stone-100 shadow-sm p-6">
        <h3 className="font-bold text-ink-900 flex items-center gap-2 mb-4">
          <RefreshCw className="w-5 h-5 text-green-500" /> Quick Links
        </h3>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          {[
            { label: 'Supabase Dashboard', url: 'https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf' },
            { label: 'Supabase SQL Editor', url: 'https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/sql/new' },
            { label: 'Cloudflare Dashboard', url: 'https://dash.cloudflare.com' },
            { label: 'GitHub Repository', url: 'https://github.com/manuelbrandner85/Mensaena' },
          ].map(link => (
            <a key={link.label} href={link.url} target="_blank" rel="noopener noreferrer"
              className="flex items-center gap-2 px-4 py-3 bg-stone-50 rounded-xl text-sm text-ink-700 hover:bg-stone-100 hover:text-ink-900 transition-colors">
              <span className="text-green-500">&#8599;</span> {link.label}
            </a>
          ))}
        </div>
      </div>
    </div>
  )
}

interface AuditLog {
  id: string
  actor_id: string
  action: string
  target_type: string | null
  target_id: string | null
  details: Record<string, unknown>
  created_at: string
  profiles?: { name: string | null }
}

function AuditLogViewer() {
  const [logs, setLogs] = useState<AuditLog[]>([])
  const [loading, setLoading] = useState(true)

  const load = useCallback(async () => {
    setLoading(true)
    const supabase = createClient()
    const { data } = await supabase
      .from('audit_logs')
      .select('*, profiles!audit_logs_actor_id_fkey(name)')
      .order('created_at', { ascending: false })
      .limit(50)
    if (data) setLogs(data as AuditLog[])
    setLoading(false)
  }, [])

  useEffect(() => { load() }, [load])

  const ACTION_LABELS: Record<string, string> = {
    ban_user: 'Nutzer gesperrt',
    unban_user: 'Nutzer entsperrt',
    delete_user: 'Nutzer gelöscht',
    change_role: 'Rolle geändert',
    delete_post: 'Beitrag gelöscht',
    delete_event: 'Event gelöscht',
    delete_crisis: 'Krise gelöscht',
    resolve_report: 'Meldung bearbeitet',
    system_cleanup: 'System-Cleanup',
  }

  return (
    <div className="bg-white rounded-2xl border border-stone-100 shadow-sm p-6">
      <div className="flex items-center justify-between mb-4">
        <h3 className="font-bold text-ink-900 flex items-center gap-2">
          <ScrollText className="w-5 h-5 text-purple-500" /> Audit-Log
        </h3>
        <button onClick={load} className="text-xs text-ink-400 hover:text-ink-600 flex items-center gap-1">
          <RefreshCw className="w-3 h-3" /> Aktualisieren
        </button>
      </div>

      {loading ? (
        <div className="flex justify-center py-6">
          <div className="w-6 h-6 border-2 border-purple-400 border-t-transparent rounded-full animate-spin" />
        </div>
      ) : logs.length === 0 ? (
        <p className="text-sm text-ink-400 text-center py-6">Noch keine Audit-Einträge vorhanden.</p>
      ) : (
        <div className="space-y-2 max-h-80 overflow-y-auto">
          {logs.map(log => (
            <div key={log.id} className="flex items-start gap-3 px-3 py-2.5 bg-stone-50 rounded-xl text-xs">
              <div className="flex-shrink-0 w-8 h-8 bg-purple-100 rounded-full flex items-center justify-center">
                <ScrollText className="w-3.5 h-3.5 text-purple-600" />
              </div>
              <div className="flex-1 min-w-0">
                <p className="font-medium text-ink-900">
                  {ACTION_LABELS[log.action] ?? log.action}
                </p>
                <p className="text-ink-500">
                  von {log.profiles?.name ?? 'System'}
                  {log.target_type && ` • ${log.target_type}`}
                </p>
                {log.details && Object.keys(log.details).length > 0 && (
                  <p className="text-ink-400 truncate mt-0.5">
                    {JSON.stringify(log.details).slice(0, 80)}
                  </p>
                )}
              </div>
              <span className="text-ink-400 whitespace-nowrap">
                {new Date(log.created_at).toLocaleString('de-AT', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' })}
              </span>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

function InfoCard({ icon, label, value }: { icon: React.ReactNode; label: string; value: string }) {
  return (
    <div className="flex items-center gap-3 px-4 py-3 bg-stone-50 rounded-xl">
      {icon}
      <div>
        <p className="text-xs text-ink-500">{label}</p>
        <p className="text-sm font-medium text-ink-900">{value}</p>
      </div>
    </div>
  )
}
