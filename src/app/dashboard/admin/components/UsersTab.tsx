'use client'

import { useState, useCallback, useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import {
  Search, ChevronLeft, ChevronRight, Trash2,
  Shield, ShieldAlert, User, Crown
} from 'lucide-react'
import type { AdminUser } from './AdminTypes'

const PAGE_SIZE = 20
const ROLE_LABELS: Record<string, { label: string; color: string; icon: React.ReactNode }> = {
  admin:     { label: 'Admin',     color: 'bg-red-100 text-red-700',    icon: <Crown className="w-3 h-3" /> },
  moderator: { label: 'Moderator', color: 'bg-amber-100 text-amber-700', icon: <ShieldAlert className="w-3 h-3" /> },
  user:      { label: 'Nutzer',    color: 'bg-gray-100 text-gray-600',  icon: <User className="w-3 h-3" /> },
}

export default function UsersTab() {
  const [users, setUsers]     = useState<AdminUser[]>([])
  const [search, setSearch]   = useState('')
  const [roleFilter, setRoleFilter] = useState<string>('')
  const [loading, setLoading] = useState(true)
  const [page, setPage]       = useState(0)
  const [total, setTotal]     = useState(0)

  const load = useCallback(async () => {
    setLoading(true)
    const supabase = createClient()
    // Try RPC first
    const { data, error } = await supabase.rpc('admin_get_users', {
      p_search: search || null,
      p_role: roleFilter || null,
      p_limit: PAGE_SIZE,
      p_offset: page * PAGE_SIZE,
    })
    if (!error && data) {
      // RPC returns array of user objects
      const list = Array.isArray(data) ? data : []
      setUsers(list as AdminUser[])
      setTotal(list.length >= PAGE_SIZE ? (page + 2) * PAGE_SIZE : page * PAGE_SIZE + list.length)
    } else {
      // Fallback: direct query
      let query = supabase.from('profiles').select('id,name,nickname,email,role,trust_score,avatar_url,created_at,location_text', { count: 'exact' })
      if (search) query = query.or(`name.ilike.%${search}%,email.ilike.%${search}%,nickname.ilike.%${search}%`)
      if (roleFilter) query = query.eq('role', roleFilter)
      const { data: profiles, count } = await query
        .order('created_at', { ascending: false })
        .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1)
      setUsers((profiles ?? []) as AdminUser[])
      setTotal(count ?? 0)
    }
    setLoading(false)
  }, [search, roleFilter, page])

  useEffect(() => { load() }, [load])

  const handleChangeRole = async (userId: string, newRole: string) => {
    const supabase = createClient()
    const { error } = await supabase.rpc('admin_change_user_role', { p_user_id: userId, p_new_role: newRole })
    if (error) {
      // Fallback
      const { error: e2 } = await supabase.from('profiles').update({ role: newRole }).eq('id', userId)
      if (e2) { toast.error('Rollenaenderung fehlgeschlagen'); return }
    }
    toast.success(`Rolle geaendert zu ${newRole}`)
    setUsers(prev => prev.map(u => u.id === userId ? { ...u, role: newRole as AdminUser['role'] } : u))
  }

  const handleDeleteUser = async (userId: string, name: string | null) => {
    if (!confirm(`Nutzer "${name ?? userId}" wirklich loeschen? Alle Daten werden entfernt.`)) return
    const supabase = createClient()
    const { error } = await supabase.rpc('admin_delete_user', { p_user_id: userId })
    if (error) { toast.error('Loeschen fehlgeschlagen: ' + error.message); return }
    toast.success('Nutzer geloescht')
    setUsers(prev => prev.filter(u => u.id !== userId))
    setTotal(prev => prev - 1)
  }

  return (
    <div className="space-y-4">
      {/* Filters */}
      <div className="flex flex-wrap gap-3">
        <div className="relative flex-1 min-w-48">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input
            type="text" value={search}
            onChange={e => { setSearch(e.target.value); setPage(0) }}
            placeholder="Name, E-Mail oder Nickname suchen..."
            className="w-full pl-9 pr-4 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-green-300"
          />
        </div>
        <select
          value={roleFilter} onChange={e => { setRoleFilter(e.target.value); setPage(0) }}
          className="px-3 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-green-300"
        >
          <option value="">Alle Rollen</option>
          <option value="admin">Admin</option>
          <option value="moderator">Moderator</option>
          <option value="user">Nutzer</option>
        </select>
      </div>

      {loading ? (
        <div className="flex justify-center py-12">
          <div className="w-8 h-8 border-4 border-green-400 border-t-transparent rounded-full animate-spin" />
        </div>
      ) : (
        <>
          <p className="text-sm text-gray-500">{total} Nutzer gefunden</p>
          <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="bg-gray-50 border-b border-gray-100">
                  <tr>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">Name</th>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">E-Mail</th>
                    <th className="text-center px-4 py-3 font-semibold text-gray-700">Rolle</th>
                    <th className="text-center px-4 py-3 font-semibold text-gray-700">Trust</th>
                    <th className="text-left px-4 py-3 font-semibold text-gray-700">Registriert</th>
                    <th className="text-right px-4 py-3 font-semibold text-gray-700">Aktionen</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-50">
                  {users.map(u => {
                    const r = ROLE_LABELS[u.role] ?? ROLE_LABELS.user
                    return (
                      <tr key={u.id} className="hover:bg-gray-50 transition-colors">
                        <td className="px-4 py-3">
                          <div>
                            <p className="font-medium text-gray-900">{u.name ?? 'Unbekannt'}</p>
                            {u.nickname && <p className="text-xs text-gray-400">@{u.nickname}</p>}
                          </div>
                        </td>
                        <td className="px-4 py-3 text-gray-600 text-xs">{u.email ?? '-'}</td>
                        <td className="px-4 py-3 text-center">
                          <select
                            value={u.role}
                            onChange={e => handleChangeRole(u.id, e.target.value)}
                            className={`inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-semibold ${r.color} border-0 cursor-pointer`}
                          >
                            <option value="user">Nutzer</option>
                            <option value="moderator">Moderator</option>
                            <option value="admin">Admin</option>
                          </select>
                        </td>
                        <td className="px-4 py-3 text-center">
                          <span className="inline-flex items-center gap-1 text-xs font-medium text-gray-700">
                            <Shield className="w-3 h-3 text-green-500" />
                            {u.trust_score?.toFixed(1) ?? '0.0'}
                          </span>
                        </td>
                        <td className="px-4 py-3 text-gray-500 text-xs">
                          {new Date(u.created_at).toLocaleDateString('de-AT')}
                        </td>
                        <td className="px-4 py-3 text-right">
                          <button
                            onClick={() => handleDeleteUser(u.id, u.name)}
                            className="p-1.5 rounded-lg text-gray-400 hover:text-red-600 hover:bg-red-50 transition-colors"
                            title="Nutzer loeschen"
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </td>
                      </tr>
                    )
                  })}
                  {users.length === 0 && (
                    <tr><td colSpan={6} className="px-4 py-12 text-center text-gray-400">Keine Nutzer gefunden</td></tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>

          {/* Pagination */}
          <div className="flex items-center justify-between">
            <button
              onClick={() => setPage(p => Math.max(0, p - 1))}
              disabled={page === 0}
              className="flex items-center gap-1 px-3 py-2 text-sm text-gray-600 hover:text-gray-900 disabled:opacity-40"
            >
              <ChevronLeft className="w-4 h-4" /> Zurueck
            </button>
            <span className="text-sm text-gray-500">Seite {page + 1}</span>
            <button
              onClick={() => setPage(p => p + 1)}
              disabled={users.length < PAGE_SIZE}
              className="flex items-center gap-1 px-3 py-2 text-sm text-gray-600 hover:text-gray-900 disabled:opacity-40"
            >
              Weiter <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        </>
      )}
    </div>
  )
}
