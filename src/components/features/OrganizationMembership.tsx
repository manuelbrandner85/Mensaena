'use client'

import { useCallback, useEffect, useState } from 'react'
import { Users, KeyRound, Copy, Check, Plus, Trash2, Loader2, UserMinus, Shield } from 'lucide-react'
import toast from 'react-hot-toast'
import { createClient } from '@/lib/supabase/client'
import { handleSupabaseError } from '@/lib/errors'

interface Member {
  id: string
  user_id: string
  role: string
  joined_at: string
  profile?: { name: string | null; display_name: string | null; avatar_url: string | null } | null
}

interface Invite {
  id: string
  code: string
  role: string
  max_uses: number
  use_count: number
  expires_at: string
}

interface Props {
  organizationId: string
  currentUserId?: string
}

function generateCode(): string {
  // 8-char readable code
  const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'
  let out = ''
  for (let i = 0; i < 8; i++) out += chars[Math.floor(Math.random() * chars.length)]
  return out
}

/**
 * OrganizationMembership – verbindet Nutzer mit einer Organisation
 * über Mitglieds-Rolle + Einladungs-Codes. Admins sehen zusätzlich
 * einen Code-Generator; neue Nutzer können einen Code einlösen.
 */
export default function OrganizationMembership({ organizationId, currentUserId }: Props) {
  const [members, setMembers] = useState<Member[]>([])
  const [invites, setInvites] = useState<Invite[]>([])
  const [myRole, setMyRole] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)
  const [creating, setCreating] = useState(false)
  const [redeeming, setRedeeming] = useState(false)
  const [redeemCode, setRedeemCode] = useState('')
  const [copied, setCopied] = useState<string | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    const supabase = createClient()
    const { data: memberData, error: memberErr } = await supabase
      .from('organization_members')
      .select('id, user_id, role, joined_at, profile:profiles(name, display_name, avatar_url)')
      .eq('organization_id', organizationId)
      .order('joined_at', { ascending: false })
    if (memberErr) console.error('org members load failed:', memberErr.message)
    const normalized: Member[] = (memberData ?? []).map((m: Record<string, unknown>) => ({
      id: String(m.id),
      user_id: String(m.user_id),
      role: String(m.role),
      joined_at: String(m.joined_at),
      profile: Array.isArray(m.profile) ? (m.profile[0] as Member['profile']) : (m.profile as Member['profile']),
    }))
    setMembers(normalized)

    const mine = normalized.find(m => m.user_id === currentUserId)
    setMyRole(mine?.role ?? null)

    // If admin, also load invites (RLS handles visibility)
    const { data: invitesData } = await supabase
      .from('organization_invites')
      .select('id, code, role, max_uses, use_count, expires_at')
      .eq('organization_id', organizationId)
      .order('created_at', { ascending: false })
    setInvites(invitesData ?? [])

    setLoading(false)
  }, [organizationId, currentUserId])

  useEffect(() => { load() }, [load])

  const createInvite = async (role: 'member' | 'admin') => {
    if (!currentUserId) return
    setCreating(true)
    const supabase = createClient()
    const code = generateCode()
    const { error } = await supabase.from('organization_invites').insert({
      organization_id: organizationId,
      created_by: currentUserId,
      code,
      role,
      max_uses: 10,
    })
    setCreating(false)
    if (handleSupabaseError(error)) return
    toast.success('Einladungscode erstellt')
    load()
  }

  const deleteInvite = async (id: string) => {
    if (!confirm('Code wirklich löschen? Vorhandene Nutzungen bleiben bestehen.')) return
    const supabase = createClient()
    const { error } = await supabase.from('organization_invites').delete().eq('id', id)
    if (handleSupabaseError(error)) return
    toast.success('Code gelöscht')
    load()
  }

  const redeem = async () => {
    const code = redeemCode.trim().toUpperCase()
    if (code.length < 6) { toast.error('Code zu kurz'); return }
    setRedeeming(true)
    const supabase = createClient()
    const { error } = await supabase.rpc('redeem_org_invite', { p_code: code })
    setRedeeming(false)
    if (error) {
      const msg = error.message?.includes('expired') ? 'Code abgelaufen'
        : error.message?.includes('exhausted') ? 'Code erschöpft'
        : error.message?.includes('invalid') ? 'Code ungültig'
        : 'Fehler beim Einlösen'
      toast.error(msg)
      return
    }
    toast.success('Du bist jetzt Mitglied')
    setRedeemCode('')
    load()
  }

  const leave = async () => {
    if (!currentUserId || !confirm('Mitgliedschaft wirklich beenden?')) return
    const supabase = createClient()
    const { error } = await supabase
      .from('organization_members')
      .delete()
      .eq('organization_id', organizationId)
      .eq('user_id', currentUserId)
    if (handleSupabaseError(error)) return
    toast.success('Mitgliedschaft beendet')
    load()
  }

  const copyCode = async (code: string) => {
    await navigator.clipboard.writeText(code)
    setCopied(code)
    setTimeout(() => setCopied(null), 1500)
  }

  const isAdmin = myRole === 'admin'
  const isMember = !!myRole
  const hasNoMembers = members.length === 0

  if (loading) {
    return (
      <div className="bg-white rounded-2xl border border-stone-100 p-5 animate-pulse">
        <div className="h-4 w-36 bg-stone-200 rounded mb-3" />
        <div className="h-10 bg-stone-100 rounded-lg" />
      </div>
    )
  }

  return (
    <div className="bg-white rounded-2xl border border-stone-100 p-5">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <div className="p-2 rounded-lg bg-primary-50">
            <Users className="w-4 h-4 text-primary-700" />
          </div>
          <div>
            <h3 className="text-sm font-bold text-ink-900">Mitglieder</h3>
            <p className="text-xs text-ink-500">{members.length} {members.length === 1 ? 'Mitglied' : 'Mitglieder'}</p>
          </div>
        </div>
        {isMember && !isAdmin && (
          <button
            type="button"
            onClick={leave}
            className="inline-flex items-center gap-1 h-8 px-2.5 text-[11px] font-semibold border border-stone-200 text-ink-600 rounded-lg hover:bg-stone-50"
          >
            <UserMinus className="w-3 h-3" /> Verlassen
          </button>
        )}
      </div>

      {/* Members list */}
      {members.length > 0 && (
        <ul className="mb-4 space-y-1">
          {members.slice(0, 8).map(m => {
            const name = m.profile?.display_name || m.profile?.name || 'Nachbar'
            return (
              <li key={m.id} className="flex items-center gap-2 px-2 py-1.5 rounded-lg">
                {m.profile?.avatar_url ? (
                  <img src={m.profile.avatar_url} alt="" className="w-7 h-7 rounded-full object-cover" />
                ) : (
                  <div className="w-7 h-7 rounded-full bg-stone-200 flex items-center justify-center text-[11px] font-semibold text-ink-600">
                    {name.charAt(0).toUpperCase()}
                  </div>
                )}
                <span className="text-xs font-medium text-ink-800 truncate flex-1">{name}</span>
                {m.role === 'admin' && (
                  <span className="inline-flex items-center gap-1 px-2 py-0.5 text-xs font-semibold bg-amber-50 text-amber-800 border border-amber-200 rounded-full">
                    <Shield className="w-2.5 h-2.5" /> Admin
                  </span>
                )}
              </li>
            )
          })}
          {members.length > 8 && (
            <li className="text-[11px] text-ink-400 text-center pt-1">+ {members.length - 8} weitere</li>
          )}
        </ul>
      )}

      {/* Non-member: redeem code OR claim ownership if no members yet */}
      {!isMember && currentUserId && (
        <div className="border border-primary-100 rounded-xl p-3 bg-primary-50/40 mb-3">
          <div className="flex items-center gap-2 mb-2">
            <KeyRound className="w-3.5 h-3.5 text-primary-700" />
            <h4 className="text-xs font-bold text-primary-900">
              {hasNoMembers ? 'Organisation beanspruchen' : 'Einladungscode einlösen'}
            </h4>
          </div>
          <p className="text-[11px] text-ink-600 mb-2">
            {hasNoMembers
              ? 'Wenn du diese Organisation vertrittst, kannst du sie mit einem Einladungs-Code beanspruchen. Den Code erhältst du vom Mensaena-Team.'
              : 'Du hast einen 8-stelligen Code erhalten? Hier einlösen:'}
          </p>
          <div className="flex gap-2">
            <input
              type="text"
              value={redeemCode}
              onChange={e => setRedeemCode(e.target.value.toUpperCase())}
              placeholder="ABCDEFGH"
              maxLength={12}
              className="flex-1 h-9 px-3 border border-stone-200 rounded-lg text-sm font-mono uppercase"
              onKeyDown={e => { if (e.key === 'Enter') { e.preventDefault(); redeem() } }}
            />
            <button
              type="button"
              disabled={redeeming || redeemCode.trim().length < 6}
              onClick={redeem}
              className="inline-flex items-center gap-1 h-9 px-3 text-xs font-semibold bg-primary-600 text-white rounded-lg hover:bg-primary-700 disabled:opacity-60"
            >
              {redeeming && <Loader2 className="w-3 h-3 animate-spin" />}
              Einlösen
            </button>
          </div>
        </div>
      )}

      {/* Admin: create invite codes */}
      {isAdmin && (
        <div className="border-t border-stone-100 pt-4">
          <div className="flex items-center justify-between mb-2">
            <h4 className="text-xs font-bold text-ink-800 flex items-center gap-1">
              <KeyRound className="w-3.5 h-3.5" /> Einladungs-Codes
            </h4>
            <div className="flex gap-1">
              <button
                type="button"
                disabled={creating}
                onClick={() => createInvite('member')}
                className="inline-flex items-center gap-1 h-7 px-2 text-[11px] font-semibold border border-primary-200 text-primary-700 rounded-lg hover:bg-primary-50 disabled:opacity-60"
              >
                <Plus className="w-2.5 h-2.5" /> Mitglied
              </button>
              <button
                type="button"
                disabled={creating}
                onClick={() => createInvite('admin')}
                className="inline-flex items-center gap-1 h-7 px-2 text-[11px] font-semibold border border-amber-200 text-amber-800 rounded-lg hover:bg-amber-50 disabled:opacity-60"
              >
                <Plus className="w-2.5 h-2.5" /> Admin
              </button>
            </div>
          </div>
          {invites.length === 0 ? (
            <p className="text-[11px] text-ink-400 italic">Noch keine aktiven Codes.</p>
          ) : (
            <ul className="space-y-1">
              {invites.map(inv => {
                const exp = new Date(inv.expires_at)
                const isExpired = exp < new Date()
                return (
                  <li key={inv.id} className="flex items-center gap-2 px-2 py-1.5 rounded-lg border border-stone-100 bg-stone-50/60">
                    <code className="flex-1 text-xs font-mono text-ink-800 truncate">{inv.code}</code>
                    <span className="text-xs text-ink-500">
                      {inv.use_count}/{inv.max_uses}
                    </span>
                    {inv.role === 'admin' && (
                      <span className="text-xs text-amber-700 font-semibold">Admin</span>
                    )}
                    {isExpired && (
                      <span className="text-xs text-red-600 font-semibold">Abgelaufen</span>
                    )}
                    <button
                      type="button"
                      onClick={() => copyCode(inv.code)}
                      className="p-1 text-ink-400 hover:text-primary-700"
                      aria-label="Code kopieren"
                    >
                      {copied === inv.code ? <Check className="w-3 h-3 text-green-600" /> : <Copy className="w-3 h-3" />}
                    </button>
                    <button
                      type="button"
                      onClick={() => deleteInvite(inv.id)}
                      className="p-1 text-ink-400 hover:text-red-600"
                      aria-label="Code löschen"
                    >
                      <Trash2 className="w-3 h-3" />
                    </button>
                  </li>
                )
              })}
            </ul>
          )}
        </div>
      )}
    </div>
  )
}
