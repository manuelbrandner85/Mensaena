'use client'

import { useEffect, useRef, useState } from 'react'
import { AtSign, Camera, Eye, EyeOff, Loader2, X, Check, User, MapPin, Phone, Globe } from 'lucide-react'
import toast from 'react-hot-toast'
import { createClient } from '@/lib/supabase/client'
import { compressImage } from '@/lib/image-utils'
import { handleSupabaseError } from '@/lib/errors'
import { cn } from '@/lib/utils'
import type { ProfileHeaderData } from './ProfileHeader'

export interface EditableProfile extends ProfileHeaderData {
  phone?: string | null
  homepage?: string | null
  privacy_public?: boolean | null
}

interface Props {
  profile: EditableProfile
  onClose: () => void
  onSaved: (updated: EditableProfile) => void
}

const NAME_MAX = 60
const NICKNAME_MAX = 30
const BIO_MAX = 300
const LOCATION_MAX = 80
const PHONE_MAX = 30
const HOMEPAGE_MAX = 200

const NICKNAME_REGEX = /^[a-z0-9_.-]*$/i

function isValidUrl(value: string): boolean {
  if (!value) return true
  try {
    const withProto = value.match(/^https?:\/\//i) ? value : `https://${value}`
    const u = new URL(withProto)
    return !!u.hostname && u.hostname.includes('.')
  } catch {
    return false
  }
}

export default function ProfileEditModal({ profile, onClose, onSaved }: Props) {
  const [name, setName] = useState(profile.name ?? '')
  const [nickname, setNickname] = useState(profile.nickname ?? '')
  const [bio, setBio] = useState(profile.bio ?? '')
  const [location, setLocation] = useState(profile.location ?? '')
  const [phone, setPhone] = useState(profile.phone ?? '')
  const [homepage, setHomepage] = useState(profile.homepage ?? '')
  const [privacyPublic, setPrivacyPublic] = useState<boolean>(profile.privacy_public !== false)
  const [avatarUrl, setAvatarUrl] = useState(profile.avatar_url ?? null)
  const [coverUrl, setCoverUrl] = useState(profile.cover_url ?? null)
  const [avatarUploading, setAvatarUploading] = useState(false)
  const [coverUploading, setCoverUploading] = useState(false)
  const [saving, setSaving] = useState(false)
  const fileInputRef = useRef<HTMLInputElement>(null)
  const coverInputRef = useRef<HTMLInputElement>(null)
  const dialogRef = useRef<HTMLDivElement>(null)
  const titleId = 'profile-edit-modal-title'

  // Dirty-Tracking: verhindert Datenverlust bei Backdrop-Click / Escape
  const isDirty =
    (profile.name ?? '') !== name ||
    (profile.nickname ?? '') !== nickname ||
    (profile.bio ?? '') !== bio ||
    (profile.location ?? '') !== location ||
    (profile.phone ?? '') !== phone ||
    (profile.homepage ?? '') !== homepage ||
    (profile.privacy_public !== false) !== privacyPublic ||
    (profile.avatar_url ?? null) !== avatarUrl ||
    (profile.cover_url ?? null) !== coverUrl

  const handleCoverChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    if (file.size > 8 * 1024 * 1024) { toast.error('Bild zu groß (max. 8 MB)'); return }
    if (!file.type.startsWith('image/')) { toast.error('Nur Bilddateien erlaubt'); return }
    setCoverUploading(true)
    try {
      const compressed = await compressImage(file, 1600, 0.85)
      const supabase = createClient()
      const filePath = `${profile.id}/cover.webp`
      await supabase.storage.from('avatars').remove([filePath])
      const { error: upErr } = await supabase.storage.from('avatars').upload(filePath, compressed, {
        upsert: true, contentType: 'image/webp', cacheControl: '3600',
      })
      if (upErr) { toast.error(`Upload fehlgeschlagen: ${upErr.message}`); return }
      const { data: urlData } = supabase.storage.from('avatars').getPublicUrl(filePath)
      setCoverUrl(`${urlData.publicUrl}?t=${Date.now()}`)
      toast.success('Titelbild geladen')
    } catch { toast.error('Bildverarbeitung fehlgeschlagen') }
    finally { setCoverUploading(false); if (coverInputRef.current) coverInputRef.current.value = '' }
  }

  const requestClose = () => {
    if (saving || avatarUploading || coverUploading) return
    if (isDirty) {
      const ok = window.confirm('Du hast ungespeicherte Änderungen. Wirklich verwerfen?')
      if (!ok) return
    }
    onClose()
  }

  // Escape + Body-Scroll-Lock + Fokus
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') requestClose()
    }
    window.addEventListener('keydown', onKey)
    const prev = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    dialogRef.current?.focus()
    return () => {
      window.removeEventListener('keydown', onKey)
      document.body.style.overflow = prev
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [saving, avatarUploading, isDirty])

  const nameError = name.trim().length === 0
    ? 'Name darf nicht leer sein'
    : name.length > NAME_MAX
      ? `Name zu lang (max. ${NAME_MAX})`
      : null

  const nicknameError = nickname && !NICKNAME_REGEX.test(nickname)
    ? 'Nur Buchstaben, Zahlen, _ . - erlaubt'
    : null

  const homepageError = homepage && !isValidUrl(homepage)
    ? 'Ungültige URL'
    : null

  const canSave = !nameError && !nicknameError && !homepageError && !saving && !avatarUploading && !coverUploading

  const initials = (name || 'N')
    .split(' ')
    .map((n) => n[0])
    .filter(Boolean)
    .join('')
    .toUpperCase()
    .slice(0, 2)

  const handleAvatarClick = () => {
    if (!avatarUploading) fileInputRef.current?.click()
  }

  const handleAvatarChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    if (file.size > 5 * 1024 * 1024) {
      toast.error('Bild zu groß (max. 5 MB)')
      return
    }
    if (!file.type.startsWith('image/')) {
      toast.error('Nur Bilddateien erlaubt')
      return
    }

    setAvatarUploading(true)
    try {
      const compressed = await compressImage(file, 400, 0.85)
      const supabase = createClient()
      const filePath = `${profile.id}/avatar.webp`

      await supabase.storage.from('avatars').remove([filePath])
      await supabase.storage.from('avatars').remove([`${profile.id}.webp`])

      const { error: upErr } = await supabase.storage
        .from('avatars')
        .upload(filePath, compressed, {
          upsert: true,
          contentType: 'image/webp',
          cacheControl: '3600',
        })

      if (upErr) {
        console.error('[Avatar Upload]', upErr)
        toast.error(`Upload fehlgeschlagen: ${upErr.message}`)
        return
      }

      const { data: urlData } = supabase.storage.from('avatars').getPublicUrl(filePath)
      const publicUrl = `${urlData.publicUrl}?t=${Date.now()}`
      setAvatarUrl(publicUrl)
      toast.success('Profilbild geladen')
    } catch (err) {
      console.error('[Avatar Error]', err)
      toast.error('Bildverarbeitung fehlgeschlagen')
    } finally {
      setAvatarUploading(false)
      if (fileInputRef.current) fileInputRef.current.value = ''
    }
  }

  const handleSave = async () => {
    if (!canSave) return
    setSaving(true)
    try {
      const supabase = createClient()
      const payload = {
        name: name.trim(),
        nickname: nickname.trim() || null,
        bio: bio.trim() || null,
        location: location.trim() || null,
        phone: phone.trim() || null,
        homepage: homepage.trim() || null,
        privacy_public: privacyPublic,
        avatar_url: avatarUrl,
        cover_url: coverUrl,
        updated_at: new Date().toISOString(),
      }

      let { error } = await supabase
        .from('profiles')
        .update(payload)
        .eq('id', profile.id)

      // cover_url column may not exist yet (migration pending) – retry without it
      if (error?.message?.includes('cover_url')) {
        // eslint-disable-next-line @typescript-eslint/no-unused-vars
        const { cover_url: _cv, ...payloadWithoutCover } = payload
        ;({ error } = await supabase
          .from('profiles')
          .update(payloadWithoutCover)
          .eq('id', profile.id))
      }

      if (handleSupabaseError(error)) {
        setSaving(false)
        return
      }

      toast.success('Profil gespeichert')
      onSaved({
        ...profile,
        ...payload,
      })
    } catch (err) {
      console.error('[Profile Save]', err)
      toast.error('Speichern fehlgeschlagen')
      setSaving(false)
    }
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4 bg-black/50 backdrop-blur-sm animate-in fade-in duration-200"
      onClick={requestClose}
    >
      <div
        ref={dialogRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        tabIndex={-1}
        className={cn(
          'w-full sm:max-w-lg bg-white sm:rounded-3xl rounded-t-3xl shadow-2xl',
          'max-h-[92vh] flex flex-col outline-none',
        )}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
          <h2 id={titleId} className="text-lg font-bold text-gray-900">Profil bearbeiten</h2>
          <button
            onClick={requestClose}
            disabled={saving || avatarUploading}
            className="p-1.5 rounded-lg hover:bg-gray-100 transition-colors disabled:opacity-50"
            aria-label="Schließen"
          >
            <X className="w-5 h-5 text-gray-500" />
          </button>
        </div>

        {/* Body */}
        <div className="flex-1 overflow-y-auto px-6 py-6 space-y-5">
          {/* Cover-Foto */}
          <div className="relative w-full h-24 rounded-2xl overflow-hidden bg-gradient-to-br from-primary-400 to-primary-700 cursor-pointer group"
            onClick={() => !coverUploading && coverInputRef.current?.click()}
          >
            {coverUrl && <img src={coverUrl} alt="" className="absolute inset-0 w-full h-full object-cover" />}
            {/* Always-visible overlay on mobile (no hover), fade-in on desktop hover */}
            <div className="absolute inset-0 bg-black/40 md:bg-black/30 md:opacity-0 md:group-hover:opacity-100 transition-opacity flex items-center justify-center gap-2 text-white text-xs font-medium">
              {coverUploading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Camera className="w-4 h-4" />}
              {coverUploading ? 'Wird hochgeladen…' : 'Titelbild ändern'}
            </div>
          </div>
          <input ref={coverInputRef} type="file" accept="image/*" className="hidden" onChange={handleCoverChange} />

          {/* Avatar */}
          <div className="flex flex-col items-center">
            <button
              type="button"
              onClick={handleAvatarClick}
              disabled={avatarUploading}
              className="relative group"
            >
              <div className="h-28 w-28 rounded-full bg-white p-1.5 shadow-card ring-1 ring-gray-100">
                <div className="h-full w-full overflow-hidden rounded-full bg-primary-100 flex items-center justify-center">
                  {avatarUrl ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={avatarUrl}
                      alt="Avatar"
                      className="h-full w-full object-cover"
                    />
                  ) : (
                    <span className="text-2xl font-bold text-primary-700">
                      {initials}
                    </span>
                  )}
                </div>
              </div>
              <div
                className={cn(
                  'absolute inset-0 rounded-full flex items-center justify-center',
                  'bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity',
                )}
              >
                {avatarUploading ? (
                  <Loader2 className="w-6 h-6 text-white animate-spin" />
                ) : (
                  <Camera className="w-6 h-6 text-white" />
                )}
              </div>
              <div className="absolute bottom-1 right-1 h-9 w-9 rounded-full bg-primary-600 text-white flex items-center justify-center shadow-lg ring-2 ring-white">
                {avatarUploading ? (
                  <Loader2 className="w-4 h-4 animate-spin" />
                ) : (
                  <Camera className="w-4 h-4" />
                )}
              </div>
            </button>
            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              className="hidden"
              onChange={handleAvatarChange}
            />
            <p className="mt-3 text-xs text-gray-400">
              Klicke auf das Bild zum Ändern
            </p>
          </div>

          {/* Name */}
          <Field
            icon={User}
            label="Name"
            required
            error={nameError && name.length > 0 ? nameError : null}
          >
            <input
              value={name}
              onChange={(e) => setName(e.target.value.slice(0, NAME_MAX))}
              placeholder="Dein Name"
              className="input text-sm w-full"
              maxLength={NAME_MAX}
            />
            <Counter current={name.length} max={NAME_MAX} />
          </Field>

          {/* Nickname */}
          <Field icon={AtSign} label="Nickname" error={nicknameError}>
            <input
              value={nickname}
              onChange={(e) => setNickname(e.target.value.slice(0, NICKNAME_MAX))}
              placeholder="z.B. maxi_berlin"
              className="input text-sm w-full"
              maxLength={NICKNAME_MAX}
            />
            <Counter current={nickname.length} max={NICKNAME_MAX} />
          </Field>

          {/* Bio */}
          <Field label="Über dich">
            <textarea
              value={bio}
              onChange={(e) => setBio(e.target.value.slice(0, BIO_MAX))}
              placeholder="Erzähle deinen Nachbarn etwas über dich..."
              rows={3}
              className="input text-sm w-full resize-none"
              maxLength={BIO_MAX}
            />
            <Counter current={bio.length} max={BIO_MAX} />
          </Field>

          {/* Location */}
          <Field icon={MapPin} label="Standort">
            <input
              value={location}
              onChange={(e) => setLocation(e.target.value.slice(0, LOCATION_MAX))}
              placeholder="z.B. Berlin-Kreuzberg"
              className="input text-sm w-full"
              maxLength={LOCATION_MAX}
            />
          </Field>

          {/* Phone */}
          <Field icon={Phone} label="Telefon (optional)">
            <input
              value={phone}
              onChange={(e) => setPhone(e.target.value.slice(0, PHONE_MAX))}
              placeholder="+49 …"
              type="tel"
              className="input text-sm w-full"
              maxLength={PHONE_MAX}
            />
          </Field>

          {/* Homepage */}
          <Field
            icon={Globe}
            label="Website (optional)"
            error={homepageError}
          >
            <input
              value={homepage}
              onChange={(e) => setHomepage(e.target.value.slice(0, HOMEPAGE_MAX))}
              placeholder="https://example.com"
              className="input text-sm w-full"
              maxLength={HOMEPAGE_MAX}
            />
          </Field>

          {/* Privatsphäre */}
          <div className="pt-2 border-t border-gray-100">
            <label className="flex items-center gap-1.5 text-xs font-semibold text-gray-700 mb-2">
              {privacyPublic ? (
                <Eye className="w-3.5 h-3.5 text-gray-400" />
              ) : (
                <EyeOff className="w-3.5 h-3.5 text-gray-400" />
              )}
              Privatsphäre
            </label>
            <button
              type="button"
              onClick={() => setPrivacyPublic((v) => !v)}
              className={cn(
                'w-full flex items-start gap-3 p-3 rounded-xl border text-left transition-all',
                privacyPublic
                  ? 'bg-primary-50 border-primary-200 hover:bg-primary-100/60'
                  : 'bg-gray-50 border-gray-200 hover:bg-gray-100',
              )}
              aria-pressed={privacyPublic}
            >
              <span
                className={cn(
                  'mt-0.5 flex-shrink-0 w-10 h-6 rounded-full p-0.5 transition-colors',
                  privacyPublic ? 'bg-primary-600' : 'bg-gray-300',
                )}
                aria-hidden="true"
              >
                <span
                  className={cn(
                    'block h-5 w-5 rounded-full bg-white shadow-sm transition-transform',
                    privacyPublic ? 'translate-x-4' : 'translate-x-0',
                  )}
                />
              </span>
              <span className="flex-1 min-w-0">
                <span className="block text-sm font-medium text-gray-900">
                  {privacyPublic ? 'Öffentliches Profil' : 'Privates Profil'}
                </span>
                <span className="block text-xs text-gray-500 mt-0.5 leading-snug">
                  {privacyPublic
                    ? 'Andere Nutzer können dein Profil, deine Beiträge und Aktivitäten sehen.'
                    : 'Dein Profil ist nur für dich sichtbar. Andere sehen einen Hinweis, dass das Profil privat ist.'}
                </span>
              </span>
            </button>
          </div>
        </div>

        {/* Footer */}
        <div className="flex items-center justify-end gap-3 px-6 py-4 border-t border-gray-100 bg-gray-50/50 sm:rounded-b-3xl">
          <button
            onClick={requestClose}
            disabled={saving || avatarUploading}
            className="px-4 py-2 rounded-xl text-sm font-medium text-gray-600 hover:bg-gray-200 transition-colors disabled:opacity-50"
          >
            Abbrechen
          </button>
          <button
            onClick={handleSave}
            disabled={!canSave}
            className={cn(
              'inline-flex items-center gap-2 px-5 py-2 rounded-xl text-sm font-semibold',
              'bg-primary-600 text-white shadow-sm',
              'hover:bg-primary-700 active:scale-95 transition-all',
              'disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:bg-primary-600 disabled:active:scale-100',
            )}
          >
            {saving ? (
              <>
                <Loader2 className="w-4 h-4 animate-spin" />
                Speichert…
              </>
            ) : (
              <>
                <Check className="w-4 h-4" />
                Speichern
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  )
}

// ── Sub-Components ──────────────────────────────────────────────────────────
function Field({
  icon: Icon,
  label,
  required,
  error,
  children,
}: {
  icon?: React.ComponentType<{ className?: string }>
  label: string
  required?: boolean
  error?: string | null
  children: React.ReactNode
}) {
  return (
    <div>
      <label className="flex items-center gap-1.5 text-xs font-semibold text-gray-700 mb-1.5">
        {Icon && <Icon className="w-3.5 h-3.5 text-gray-400" />}
        {label}
        {required && <span className="text-red-500">*</span>}
      </label>
      {children}
      {error && <p className="mt-1 text-xs text-red-600">{error}</p>}
    </div>
  )
}

function Counter({ current, max }: { current: number; max: number }) {
  const pct = current / max
  return (
    <p
      className={cn(
        'mt-1 text-[10px] text-right',
        pct > 0.9 ? 'text-amber-600' : 'text-gray-400',
      )}
    >
      {current}/{max}
    </p>
  )
}
