'use client'

import { useState, useEffect, useCallback } from 'react'
import { User, MapPin, Globe, Phone, Loader2, Navigation, Save, AtSign, Check, X } from 'lucide-react'
import toast from 'react-hot-toast'
import SettingsSection from './SettingsSection'
import type { SettingsProfile } from '../types'

interface Props {
  settings: SettingsProfile
  onSave: (updates: Partial<SettingsProfile>, msg?: string) => Promise<boolean>
  geocode: (addr: string) => Promise<{ lat: number; lng: number } | null>
  saving: boolean
  onDirty?: () => void
  checkUsername?: (username: string) => void
  usernameAvailable?: boolean | null
  checkingUsername?: boolean
}

export default function ProfileLocationSettings({
  settings, onSave, geocode, saving, onDirty,
  checkUsername, usernameAvailable, checkingUsername,
}: Props) {
  const [displayName, setDisplayName] = useState(settings.display_name ?? settings.name ?? '')
  const [username, setUsername] = useState(settings.username ?? '')
  const [bio, setBio] = useState(settings.bio ?? '')
  const [phone, setPhone] = useState(settings.phone ?? '')
  const [homepage, setHomepage] = useState(settings.homepage ?? '')
  const [address, setAddress] = useState(settings.address ?? settings.location ?? '')
  const [radiusKm, setRadiusKm] = useState(settings.radius_km ?? 5)
  const [geocoding, setGeocoding] = useState(false)
  const [coordinates, setCoordinates] = useState<{ lat: number; lng: number } | null>(
    settings.latitude && settings.longitude ? { lat: settings.latitude, lng: settings.longitude } : null
  )

  // Dirty tracking helper
  const markDirty = useCallback(() => { onDirty?.() }, [onDirty])

  // Username debounce check
  useEffect(() => {
    if (checkUsername && username !== (settings.username ?? '')) {
      checkUsername(username)
    }
  }, [username, checkUsername, settings.username])

  const handleGeocode = async () => {
    if (!address.trim()) { toast.error('Bitte Adresse eingeben'); return }
    setGeocoding(true)
    const result = await geocode(address)
    setGeocoding(false)
    if (result) {
      setCoordinates(result)
      markDirty()
      toast.success('Standort gefunden')
    } else {
      toast.error('Adresse nicht gefunden. Bitte genauer angeben.')
    }
  }

  const handleSaveAll = async () => {
    // Username validation
    if (username && usernameAvailable === false) {
      toast.error('Benutzername ist bereits vergeben')
      return
    }

    const updates: Partial<SettingsProfile> = {
      display_name: displayName || null as unknown as string,
      name: displayName || settings.name,
      username: username ? username.toLowerCase().trim() : null as unknown as string,
      bio,
      phone: phone || null as unknown as string,
      homepage: homepage || null as unknown as string,
      address: address || null as unknown as string,
      location: address || settings.location,
      radius_km: radiusKm,
    }
    if (coordinates) {
      updates.latitude = coordinates.lat
      updates.longitude = coordinates.lng
    }
    await onSave(updates, 'Einstellungen gespeichert ✓')
  }

  return (
    <div className="space-y-5">
      {/* Profile Info */}
      <SettingsSection
        icon={<User className="w-4 h-4 text-emerald-700" />}
        title="Profil-Informationen"
        description="Dein öffentliches Profil auf Mensaena"
      >
        <div className="space-y-4">
          <div>
            <label className="label">Anzeigename</label>
            <input
              value={displayName}
              onChange={e => { setDisplayName(e.target.value); markDirty() }}
              placeholder="Dein Name"
              className="input"
              maxLength={60}
            />
            <p className="text-xs text-gray-400 mt-1">Wird anderen Nutzern angezeigt</p>
          </div>

          {/* Username with availability check */}
          <div>
            <label className="label">Benutzername</label>
            <div className="relative">
              <AtSign className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input
                value={username}
                onChange={e => {
                  const v = e.target.value.toLowerCase().replace(/[^a-z0-9_.-]/g, '')
                  setUsername(v)
                  markDirty()
                }}
                placeholder="mein_username"
                className="input pl-10 pr-10"
                maxLength={30}
              />
              {/* Availability indicator */}
              <div className="absolute right-3 top-1/2 -translate-y-1/2">
                {checkingUsername && (
                  <Loader2 className="w-4 h-4 text-gray-400 animate-spin" />
                )}
                {!checkingUsername && usernameAvailable === true && username.length >= 3 && (
                  <Check className="w-4 h-4 text-emerald-600" />
                )}
                {!checkingUsername && usernameAvailable === false && username.length >= 3 && (
                  <X className="w-4 h-4 text-red-500" />
                )}
              </div>
            </div>
            <p className="text-xs mt-1">
              {checkingUsername && <span className="text-gray-400">Prüfe Verfügbarkeit...</span>}
              {!checkingUsername && usernameAvailable === true && username.length >= 3 && (
                <span className="text-emerald-600">Benutzername ist verfügbar</span>
              )}
              {!checkingUsername && usernameAvailable === false && username.length >= 3 && (
                <span className="text-red-500">Benutzername ist bereits vergeben</span>
              )}
              {!checkingUsername && usernameAvailable === null && username.length < 3 && username.length > 0 && (
                <span className="text-gray-400">Mindestens 3 Zeichen</span>
              )}
              {!checkingUsername && usernameAvailable === null && username.length === 0 && (
                <span className="text-gray-400">Kleinbuchstaben, Zahlen, Unterstrich, Punkt und Bindestrich</span>
              )}
            </p>
          </div>

          <div>
            <label className="label">Über mich</label>
            <textarea
              value={bio}
              onChange={e => { setBio(e.target.value.slice(0, 300)); markDirty() }}
              placeholder="Erzähle etwas über dich..."
              className="input resize-none"
              rows={3}
              maxLength={300}
            />
            <p className="text-xs text-gray-400 mt-1 text-right">{bio.length}/300</p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="label">Telefon</label>
              <div className="relative">
                <Phone className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                <input
                  value={phone}
                  onChange={e => { setPhone(e.target.value); markDirty() }}
                  placeholder="+49 123 4567890"
                  className="input pl-10"
                  type="tel"
                />
              </div>
            </div>
            <div>
              <label className="label">Webseite</label>
              <div className="relative">
                <Globe className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                <input
                  value={homepage}
                  onChange={e => { setHomepage(e.target.value); markDirty() }}
                  placeholder="https://..."
                  className="input pl-10"
                  type="url"
                />
              </div>
            </div>
          </div>
        </div>
      </SettingsSection>

      {/* Location */}
      <SettingsSection
        icon={<MapPin className="w-4 h-4 text-emerald-700" />}
        title="Standort & Umkreis"
        description="Für lokalen Feed und Nachbarschaftssuche"
      >
        <div className="space-y-4">
          <div>
            <label className="label">Adresse / Ort</label>
            <div className="flex gap-2">
              <input
                value={address}
                onChange={e => { setAddress(e.target.value); markDirty() }}
                placeholder="z.B. Musterstrasse 1, 10115 Berlin"
                className="input flex-1"
              />
              <button
                onClick={handleGeocode}
                disabled={geocoding}
                className="flex items-center gap-1.5 px-3 py-2 rounded-xl text-sm font-medium bg-emerald-100 text-emerald-700 hover:bg-emerald-200 transition-colors disabled:opacity-50 min-h-[44px]"
              >
                {geocoding ? <Loader2 className="w-4 h-4 animate-spin" /> : <Navigation className="w-4 h-4" />}
                Finden
              </button>
            </div>
            {coordinates && (
              <p className="text-xs text-emerald-600 mt-1">
                Koordinaten: {coordinates.lat.toFixed(4)}, {coordinates.lng.toFixed(4)}
              </p>
            )}
            <p className="text-xs text-gray-400 mt-1">
              Wird für den lokalen Feed genutzt. Kein exakter Standort wird geteilt, nur die ungefaehre Region.
            </p>
          </div>

          <div>
            <label className="label">Umkreis: {radiusKm} km</label>
            <input
              type="range"
              min={1}
              max={150}
              value={radiusKm}
              onChange={e => { setRadiusKm(parseInt(e.target.value)); markDirty() }}
              className="w-full h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer accent-emerald-600"
            />
            <div className="flex justify-between text-xs text-gray-400 mt-1">
              <span>1 km</span>
              <span>25 km</span>
              <span>75 km</span>
              <span>150 km</span>
            </div>
          </div>
        </div>
      </SettingsSection>

      {/* Save Button */}
      <div className="flex justify-end">
        <button
          onClick={handleSaveAll}
          disabled={saving || (checkingUsername ?? false)}
          className="flex items-center gap-2 px-6 py-2.5 rounded-xl text-sm font-medium bg-emerald-600 text-white hover:bg-emerald-700 transition-all disabled:opacity-50 min-h-[44px]"
        >
          {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />}
          Profil speichern
        </button>
      </div>
    </div>
  )
}
