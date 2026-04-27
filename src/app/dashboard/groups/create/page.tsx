'use client'

import { useState, useRef } from 'react'
import { useRouter } from 'next/navigation'
import { Plus, Lock, Globe, Shield, ArrowLeft, Loader2, Camera, X } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { cn } from '@/lib/utils'
import toast from 'react-hot-toast'
import { checkRateLimit } from '@/lib/rate-limit'

const GROUP_CATEGORIES = [
  { value: 'nachbarschaft', label: 'Nachbarschaft',            emoji: '🏘️', color: 'from-blue-400 to-blue-600',     accent: '#3B82F6' },
  { value: 'hobby',         label: 'Hobby & Freizeit',         emoji: '🎨', color: 'from-pink-400 to-rose-500',     accent: '#EC4899' },
  { value: 'sport',         label: 'Sport & Fitness',          emoji: '⚽', color: 'from-orange-400 to-orange-600', accent: '#F97316' },
  { value: 'eltern',        label: 'Eltern & Familie',         emoji: '👶', color: 'from-yellow-400 to-amber-500',  accent: '#F59E0B' },
  { value: 'senioren',      label: 'Senioren',                 emoji: '🧓', color: 'from-purple-400 to-purple-600', accent: '#8B5CF6' },
  { value: 'umwelt',        label: 'Umwelt & Nachhaltigkeit',  emoji: '🌿', color: 'from-primary-400 to-primary-600', accent: '#10B981' },
  { value: 'bildung',       label: 'Bildung & Lernen',         emoji: '📚', color: 'from-indigo-400 to-indigo-600', accent: '#6366F1' },
  { value: 'tiere',         label: 'Tiere',                    emoji: '🐾', color: 'from-amber-400 to-yellow-600',  accent: '#D97706' },
  { value: 'handwerk',      label: 'Handwerk & DIY',           emoji: '🔧', color: 'from-slate-400 to-slate-600',   accent: '#64748B' },
  { value: 'sonstiges',     label: 'Sonstiges',                emoji: '💬', color: 'from-primary-400 to-teal-600',  accent: '#1EAAA6' },
]

export default function CreateGroupPage() {
  const router = useRouter()
  const [name, setName] = useState('')
  const [description, setDescription] = useState('')
  const [category, setCategory] = useState('sonstiges')
  const [isPrivate, setIsPrivate] = useState(false)
  const [saving, setSaving] = useState(false)
  const [avatarFile, setAvatarFile] = useState<File | null>(null)
  const [avatarPreview, setAvatarPreview] = useState<string | null>(null)
  const [bannerFile, setBannerFile] = useState<File | null>(null)
  const [bannerPreview, setBannerPreview] = useState<string | null>(null)
  const avatarInputRef = useRef<HTMLInputElement>(null)
  const bannerInputRef = useRef<HTMLInputElement>(null)

  const selectedCat = GROUP_CATEGORIES.find(c => c.value === category) ?? GROUP_CATEGORIES[GROUP_CATEGORIES.length - 1]

  const handleImageSelect = (
    e: React.ChangeEvent<HTMLInputElement>,
    type: 'avatar' | 'banner',
  ) => {
    const file = e.target.files?.[0]
    if (!file) return
    if (file.size > 8 * 1024 * 1024) { toast.error('Bild max. 8 MB'); return }
    const preview = URL.createObjectURL(file)
    if (type === 'avatar') { setAvatarFile(file); setAvatarPreview(preview) }
    else { setBannerFile(file); setBannerPreview(preview) }
    e.target.value = ''
  }

  const uploadImage = async (
    supabase: ReturnType<typeof createClient>,
    file: File,
    groupId: string,
    type: 'avatar' | 'banner',
  ): Promise<string | null> => {
    const ext = file.name.split('.').pop() || 'jpg'
    const path = `groups/${groupId}/${type}.${ext}`
    const { error } = await supabase.storage
      .from('post-images')
      .upload(path, file, { cacheControl: '3600', upsert: true })
    if (error) return null
    return supabase.storage.from('post-images').getPublicUrl(path).data.publicUrl
  }

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
      if (!groupId) throw new Error('Keine Gruppen-ID erhalten')

      await supabase.from('group_members').insert({ group_id: groupId, user_id: user.id, role: 'admin' })

      // Upload images after group is created
      const imageUpdates: Record<string, string> = {}
      if (avatarFile) {
        const url = await uploadImage(supabase, avatarFile, groupId, 'avatar')
        if (url) imageUpdates.avatar_url = url
      }
      if (bannerFile) {
        const url = await uploadImage(supabase, bannerFile, groupId, 'banner')
        if (url) imageUpdates.banner_url = url
      }
      if (Object.keys(imageUpdates).length > 0) {
        await supabase.from('groups').update(imageUpdates).eq('id', groupId)
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
    <div className="max-w-4xl mx-auto px-4 py-6">
      {/* Back button */}
      <button
        onClick={() => router.back()}
        className="flex items-center gap-2 text-sm text-ink-500 hover:text-ink-800 transition-colors mb-6"
      >
        <ArrowLeft className="w-4 h-4" />
        Zurück zu Gruppen
      </button>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 items-start">
        {/* ── Form ─────────────────────────────────────────────── */}
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
              <div className="grid grid-cols-2 gap-2">
                {GROUP_CATEGORIES.map(c => (
                  <button
                    key={c.value}
                    type="button"
                    onClick={() => setCategory(c.value)}
                    className={cn(
                      'flex items-center gap-2 px-3 py-2.5 rounded-xl border text-xs font-medium text-left transition-all',
                      category === c.value
                        ? 'border-transparent text-white'
                        : 'bg-white text-ink-700 border-stone-200 hover:border-stone-300',
                    )}
                    style={category === c.value ? { backgroundColor: c.accent, borderColor: c.accent } : undefined}
                  >
                    <span className="text-base leading-none">{c.emoji}</span>
                    {c.label}
                  </button>
                ))}
              </div>
            </div>

            {/* Images */}
            <input ref={avatarInputRef} type="file" accept="image/jpeg,image/png,image/webp" className="hidden" onChange={e => handleImageSelect(e, 'avatar')} />
            <input ref={bannerInputRef} type="file" accept="image/jpeg,image/png,image/webp" className="hidden" onChange={e => handleImageSelect(e, 'banner')} />

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="label">Avatar</label>
                {avatarPreview ? (
                  <div className="relative w-20 h-20">
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img src={avatarPreview} alt="" className="w-20 h-20 rounded-xl object-cover border border-stone-200" />
                    <button type="button" onClick={() => { setAvatarFile(null); setAvatarPreview(null) }}
                      className="absolute -top-1.5 -right-1.5 w-5 h-5 bg-ink-700 rounded-full flex items-center justify-center hover:bg-red-500 transition-colors">
                      <X className="w-3 h-3 text-white" />
                    </button>
                  </div>
                ) : (
                  <button type="button" onClick={() => avatarInputRef.current?.click()}
                    className="flex items-center gap-1.5 px-3 py-2 border border-dashed border-stone-300 hover:border-primary-400 rounded-xl text-xs text-ink-500 hover:text-primary-600 transition-colors">
                    <Camera className="w-3.5 h-3.5" /> Hochladen
                  </button>
                )}
              </div>
              <div>
                <label className="label">Banner</label>
                {bannerPreview ? (
                  <div className="relative">
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img src={bannerPreview} alt="" className="w-full h-16 rounded-xl object-cover border border-stone-200" />
                    <button type="button" onClick={() => { setBannerFile(null); setBannerPreview(null) }}
                      className="absolute -top-1.5 -right-1.5 w-5 h-5 bg-ink-700 rounded-full flex items-center justify-center hover:bg-red-500 transition-colors">
                      <X className="w-3 h-3 text-white" />
                    </button>
                  </div>
                ) : (
                  <button type="button" onClick={() => bannerInputRef.current?.click()}
                    className="flex items-center gap-1.5 px-3 py-2 border border-dashed border-stone-300 hover:border-primary-400 rounded-xl text-xs text-ink-500 hover:text-primary-600 transition-colors w-full">
                    <Camera className="w-3.5 h-3.5" /> Hochladen
                  </button>
                )}
              </div>
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
              {saving ? 'Wird erstellt…' : 'Gruppe erstellen'}
            </button>
          </div>
        </div>

        {/* ── Live Preview ──────────────────────────────────────── */}
        <div className="sticky top-6">
          <p className="text-xs font-bold uppercase tracking-widest text-ink-400 mb-3 px-1">Vorschau</p>
          <div className="bg-white rounded-2xl border border-stone-100 shadow-soft overflow-hidden">
            {/* Card header */}
            <div className={cn('relative h-32 bg-gradient-to-br flex items-center justify-center overflow-hidden', selectedCat.color)}>
              {bannerPreview && (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={bannerPreview} alt="" className="absolute inset-0 w-full h-full object-cover" />
              )}
              <div className="absolute inset-0 bg-gradient-to-t from-black/50 via-black/10 to-transparent" />
              {!bannerPreview && <div className="bg-noise absolute inset-0 opacity-20 pointer-events-none" />}

              {avatarPreview ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={avatarPreview} alt="" className="relative z-10 w-14 h-14 rounded-xl object-cover border-2 border-white/60 shadow-lg" />
              ) : (
                <span className="relative z-10 text-5xl drop-shadow-sm select-none">{selectedCat.emoji}</span>
              )}

              {isPrivate && (
                <span className="absolute top-3 right-3 z-10 inline-flex items-center gap-1 px-2 py-0.5 bg-black/40 backdrop-blur-sm rounded-full text-xs font-semibold text-white">
                  <Lock className="w-2.5 h-2.5" /> Privat
                </span>
              )}
              <span className="absolute bottom-3 left-3 z-10 inline-flex items-center gap-1 px-2 py-0.5 bg-black/40 backdrop-blur-sm rounded-full text-xs font-medium text-white">
                {selectedCat.emoji} {selectedCat.label}
              </span>
            </div>

            {/* Card body */}
            <div className="p-4">
              <h3 className="font-bold text-ink-900 text-sm leading-snug line-clamp-1 mb-1">
                {name.trim() || <span className="text-ink-300 font-normal italic">Gruppenname…</span>}
              </h3>
              {description.trim() ? (
                <p className="text-xs text-ink-500 line-clamp-2 mb-3">{description}</p>
              ) : (
                <p className="text-xs text-ink-300 italic mb-3">Keine Beschreibung</p>
              )}
              <div className="flex items-center gap-3 text-xs text-ink-400 mb-3">
                <span className="flex items-center gap-1">
                  <span style={{ color: selectedCat.accent }}>👥</span>
                  <span className="font-semibold text-ink-700">1</span>
                  <span>Mitglied</span>
                </span>
                <span className="flex items-center gap-1">
                  <span style={{ color: selectedCat.accent }}>💬</span>
                  <span className="font-semibold text-ink-700">0</span>
                  <span>Beiträge</span>
                </span>
              </div>
              <div
                className="w-full py-2 rounded-xl text-xs font-semibold text-center text-white"
                style={{ background: `linear-gradient(135deg, ${selectedCat.accent}, ${selectedCat.accent}dd)` }}
              >
                Beitreten
              </div>
            </div>
          </div>
          <p className="text-[11px] text-ink-400 mt-2 px-1">So sieht deine Gruppe in der Übersicht aus.</p>
        </div>
      </div>
    </div>
  )
}
