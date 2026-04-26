'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { Plus, Lock, Globe, Shield, ArrowLeft, Loader2 } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { cn } from '@/lib/utils'
import toast from 'react-hot-toast'
import { checkRateLimit } from '@/lib/rate-limit'

const GROUP_CATEGORIES = [
  { value: 'nachbarschaft', label: 'Nachbarschaft',            emoji: '🏘️' },
  { value: 'hobby',         label: 'Hobby & Freizeit',         emoji: '🎨' },
  { value: 'sport',         label: 'Sport & Fitness',          emoji: '⚽' },
  { value: 'eltern',        label: 'Eltern & Familie',         emoji: '👶' },
  { value: 'senioren',      label: 'Senioren',                 emoji: '🧓' },
  { value: 'umwelt',        label: 'Umwelt & Nachhaltigkeit',  emoji: '🌿' },
  { value: 'bildung',       label: 'Bildung & Lernen',         emoji: '📚' },
  { value: 'tiere',         label: 'Tiere',                    emoji: '🐾' },
  { value: 'handwerk',      label: 'Handwerk & DIY',           emoji: '🔧' },
  { value: 'sonstiges',     label: 'Sonstiges',                emoji: '💬' },
]

export default function CreateGroupPage() {
  const router = useRouter()
  const [name, setName] = useState('')
  const [description, setDescription] = useState('')
  const [category, setCategory] = useState('sonstiges')
  const [isPrivate, setIsPrivate] = useState(false)
  const [saving, setSaving] = useState(false)

  const selectedCat = GROUP_CATEGORIES.find(c => c.value === category) ?? GROUP_CATEGORIES[GROUP_CATEGORIES.length - 1]

  const handleCreate = async () => {
    if (name.trim().length < 3) { toast.error('Name mindestens 3 Zeichen'); return }
    if (description.trim().length > 500) { toast.error('Beschreibung max. 500 Zeichen'); return }
    setSaving(true)
    try {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) { toast.error('Bitte einloggen'); setSaving(false); return }

      const allowed = await checkRateLimit(user.id, 'create_group', 2, 60)
      if (!allowed) { toast.error('Zu viele Gruppen in kurzer Zeit. Bitte warte etwas.'); setSaving(false); return }

      const baseSlug = name.trim().toLowerCase().replace(/[^a-z0-9äöüß]+/g, '-').replace(/^-|-$/g, '')
      const slug = `${baseSlug}-${Date.now().toString(36)}`

      const insertData: Record<string, unknown> = {
        name: name.trim(),
        slug,
        description: description.trim() || null,
        category,
        is_private: isPrivate,
        is_public: !isPrivate,
        creator_id: user.id,
        created_by: user.id,
        member_count: 1,
        post_count: 0,
      }

      let result = await supabase.from('groups').insert(insertData).select('id').single()

      for (let attempt = 0; attempt < 5 && result.error?.message?.includes('column'); attempt++) {
        const colMatch = result.error.message.match(/column\s+["']?(\w+)["']?.*does not exist/i)
          || result.error.message.match(/Could not find.*column\s+["']?(\w+)["']?/i)
        if (!colMatch) break
        delete insertData[colMatch[1]]
        result = await supabase.from('groups').insert(insertData).select('id').single()
      }

      if (result.error) throw result.error

      const groupId = result.data?.id
      if (groupId) {
        await supabase.from('group_members').insert({ group_id: groupId, user_id: user.id, role: 'admin' })
      }

      toast.success('Gruppe erstellt!')
      router.push(`/dashboard/groups/${groupId}`)
    } catch (err: unknown) {
      const e = err as { message?: string; code?: string }
      if (e?.code === '23505') toast.error('Gruppenname existiert bereits')
      else if (e?.code === '42501') toast.error('Keine Berechtigung. Bitte neu einloggen.')
      else toast.error('Fehler beim Erstellen: ' + (e?.message ?? 'Unbekannter Fehler'))
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="max-w-lg mx-auto px-4 py-6">
      {/* Back button */}
      <button
        onClick={() => router.back()}
        className="flex items-center gap-2 text-sm text-ink-500 hover:text-ink-800 transition-colors mb-6"
      >
        <ArrowLeft className="w-4 h-4" />
        Zurück zu Gruppen
      </button>

      <div className="bg-white rounded-2xl border border-stone-100 shadow-soft overflow-hidden">
        {/* Header */}
        <div className="flex items-center gap-3 px-6 py-5 border-b border-stone-100">
          <div className="w-9 h-9 rounded-xl bg-primary-100 flex items-center justify-center flex-shrink-0">
            <span className="text-xl leading-none">{selectedCat.emoji}</span>
          </div>
          <div>
            <h1 className="text-base font-semibold text-ink-900">Neue Gruppe erstellen</h1>
            <p className="text-xs text-ink-400 mt-0.5">Bringe deine Nachbarschaft zusammen</p>
          </div>
        </div>

        <div className="p-6 space-y-4">
          <div className="flex items-center gap-2 bg-primary-50 border border-primary-200 rounded-xl px-3 py-2">
            <Shield className="w-4 h-4 text-primary-500 flex-shrink-0" />
            <p className="text-xs text-primary-700">Max. <strong>2 Gruppen pro Stunde</strong> – Gruppen werden sofort sichtbar.</p>
          </div>

          <div>
            <label className="label">Gruppenname *</label>
            <input
              value={name}
              onChange={e => setName(e.target.value)}
              maxLength={60}
              className="input"
              placeholder="z.B. Nachbarschaftshilfe Mitte"
              autoFocus
            />
            {name.trim().length > 0 && name.trim().length < 3 && (
              <p className="text-xs text-red-500 mt-1">Mindestens 3 Zeichen nötig</p>
            )}
          </div>

          <div>
            <label className="label">
              Beschreibung <span className="font-normal text-ink-400">({description.length}/500)</span>
            </label>
            <textarea
              value={description}
              onChange={e => setDescription(e.target.value)}
              rows={3}
              maxLength={500}
              className="input resize-none"
              placeholder="Worum geht es in der Gruppe?"
            />
          </div>

          <div>
            <label className="label">Kategorie</label>
            <select value={category} onChange={e => setCategory(e.target.value)} className="input">
              {GROUP_CATEGORIES.map(c => (
                <option key={c.value} value={c.value}>{c.emoji} {c.label}</option>
              ))}
            </select>
          </div>

          <div className="flex items-center gap-3">
            <button
              onClick={() => setIsPrivate(!isPrivate)}
              className={cn(
                'flex items-center gap-2 px-4 py-2 rounded-xl border transition-all text-sm font-medium',
                isPrivate
                  ? 'bg-amber-50 border-amber-300 text-amber-700'
                  : 'bg-green-50 border-green-300 text-green-700',
              )}
            >
              {isPrivate ? <Lock className="w-4 h-4" /> : <Globe className="w-4 h-4" />}
              {isPrivate ? 'Privat' : 'Öffentlich'}
            </button>
            <span className="text-xs text-ink-500">
              {isPrivate ? 'Nur auf Einladung' : 'Jeder kann beitreten'}
            </span>
          </div>

          <button
            onClick={handleCreate}
            disabled={saving || name.trim().length < 3}
            className="btn-primary w-full disabled:opacity-50 disabled:pointer-events-none"
          >
            {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Plus className="w-4 h-4" />}
            Gruppe erstellen
          </button>
        </div>
      </div>
    </div>
  )
}
