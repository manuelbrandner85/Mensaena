'use client'

import { useEffect, useRef, useState } from 'react'
import { Camera, Loader2, X, Check, User, MapPin, Phone, Globe } from 'lucide-react'
import toast from 'react-hot-toast'
import { createClient } from '@/lib/supabase/client'
import { compressImage } from '@/lib/image-utils'
import { handleSupabaseError } from '@/lib/errors'
import { cn } from '@/lib/utils'
import type { ProfileHeaderData } from './ProfileHeader'

export interface EditableProfile extends ProfileHeaderData {
  phone?: string | null
  homepage?: string | null
}

interface Props {
  profile: EditableProfile
  onClose: () => void
  onSaved: (updated: EditableProfile) => void
}

const NAME_MAX = 60
const BIO_MAX = 300
const LOCATION_MAX = 80
const PHONE_MAX = 30
const HOMEPAGE_MAX = 200

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
  const [bio, setBio] = useState(profile.bio ?? '')
  const [location, setLocation] = useState(profile.location ?? '')
  const [phone, setPhone] = useState(profile.phone ?? '')
  const [homepage, setHomepage] = useState(profile.homepage ?? '')
  const [avatarUrl, setAvatarUrl] = useState(profile.avatar_url ?? null)
  const [avatarUploading, setAvatarUploading] = useState(false)
  const [saving, setSaving] = useState(false)
  const fileInputRef = useRef<HTMLInputElement>(null)

  // Escape schliesst
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && !saving && !avatarUploading) onClose()
    }
    window.addEventListener('keydown', onKey)
    // Body-Scroll sperren
    const prev = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return () => {
      window.removeEventListener('keydown', onKey)
      document.body.style.overflow = prev
    }
  }, [onClose, saving, avatarUploading])

  const nameError = name.trim().length === 0
    ? 'Name darf nicht leer sein'
    : name.length > NAME_MAX
      ? `Name zu lang (max. ${NAME_MAX})`
      : null

  const homepageError = homepage && !isValidUrl(homepage)
    ? 'Ungültige URL'
    : null

  const canSave = !nameError && !homepageError && !saving && !avatarUploading

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
        bio: bio.trim() || null,
        location: location.trim() || null,
        phone: phone.trim() || null,
        homepage: homepage.trim() || null,
        avatar_url: avatarUrl,
        updated_at: new Date().toISOString(),
      }

      const { error } = await supabase
        .from('profiles')
        .update(payload)
        .eq('id', profile.id)

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
      onClick={() => {
        if (!saving && !avatarUploading) onClose()
      }}
    >
      <div
        className={cn(
          'w-full sm:max-w-lg bg-white sm:rounded-3xl rounded-t-3xl shadow-2xl',
          'max-h-[92vh] flex flex-col',
        )}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
          <h2 className="text-lg font-bold text-gray-900">Profil bearbeiten</h2>
          <button
            onClick={onClose}
            disabled={saving || avatarUploading}
            className="p-1.5 rounded-lg hover:bg-gray-100 transition-colors disabled:opacity-50"
            aria-label="Schließen"
          >
            <X className="w-5 h-5 text-gray-500" />
          </button>
        </div>

        {/* Body */}
        <div className="flex-1 overflow-y-auto px-6 py-6 space-y-5">
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
        </div>

        {/* Footer */}
        <div className="flex items-center justify-end gap-3 px-6 py-4 border-t border-gray-100 bg-gray-50/50 sm:rounded-b-3xl">
          <button
            onClick={onClose}
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
