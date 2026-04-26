'use client'

import { useState, useEffect } from 'react'
import { MapPin, X, Loader2 } from 'lucide-react'
import toast from 'react-hot-toast'
import { createClient } from '@/lib/supabase/client'
import { cn } from '@/lib/utils'
import AddressAutocomplete from '@/components/input/AddressAutocomplete'
import type { PhotonResult } from '@/lib/api/photon'
import { reverseGeocode, formatAddressShort } from '@/lib/api/nominatim'

const DISMISSED_KEY = 'mensaena_location_dismissed'
const DISMISS_TTL = 24 * 60 * 60 * 1000 // 24h

const COUNTRIES = [
  { code: 'de', label: 'Deutschland' },
  { code: 'at', label: 'Österreich' },
  { code: 'ch', label: 'Schweiz' },
]

function wasDismissedRecently(): boolean {
  if (typeof window === 'undefined') return false
  const stored = localStorage.getItem(DISMISSED_KEY)
  if (!stored) return false
  return Date.now() - Number(stored) < DISMISS_TTL
}

interface LocationOnboardingModalProps {
  userId: string
  onLocationSaved: (lat: number, lng: number, location: string) => void
}

export default function LocationOnboardingModal({
  userId,
  onLocationSaved,
}: LocationOnboardingModalProps) {
  const [visible, setVisible] = useState(false)
  const [mode, setMode] = useState<'choose' | 'plz' | 'address'>('choose')
  const [plz, setPlz] = useState('')
  const [country, setCountry] = useState('de')
  const [loading, setLoading] = useState(false)
  const [geoError, setGeoError] = useState<string | null>(null)

  useEffect(() => {
    if (!wasDismissedRecently()) setVisible(true)
  }, [])

  if (!visible) return null

  function dismiss() {
    localStorage.setItem(DISMISSED_KEY, String(Date.now()))
    setVisible(false)
  }

  async function saveLocation(lat: number, lng: number, location: string) {
    const supabase = createClient()
    const { error } = await supabase
      .from('profiles')
      .update({ latitude: lat, longitude: lng, location })
      .eq('id', userId)
    if (error) throw error
    toast.success('Standort gesetzt! 🌿')
    onLocationSaved(lat, lng, location)
    setVisible(false)
  }

  function shortenDisplayName(displayName: string): string {
    // Keep "Ort, PLZ" – take first two comma-separated segments
    const parts = displayName.split(',').map(s => s.trim())
    return parts.slice(0, 2).join(', ')
  }

  async function handleGeoLocation() {
    if (typeof navigator === 'undefined' || !navigator.geolocation) {
      setGeoError('Standorterkennung nicht erlaubt. Bitte gib deine PLZ ein.')
      setMode('plz')
      return
    }
    setLoading(true)
    setGeoError(null)
    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        try {
          const { latitude: lat, longitude: lng } = pos.coords
          const addr = await reverseGeocode(lat, lng)
          await saveLocation(lat, lng, formatAddressShort(addr))
        } catch {
          toast.error('Standort konnte nicht gespeichert werden.')
        } finally {
          setLoading(false)
        }
      },
      () => {
        setLoading(false)
        setGeoError('Standorterkennung nicht erlaubt. Bitte gib deine PLZ ein.')
        setMode('plz')
      },
      { enableHighAccuracy: false, timeout: 10000 }
    )
  }

  async function handlePlzSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!plz.trim()) return
    setLoading(true)
    setGeoError(null)
    try {
      const res = await fetch(
        `https://nominatim.openstreetmap.org/search?postalcode=${encodeURIComponent(plz.trim())}&country=${country}&format=json&limit=1`,
        { headers: { 'Accept-Language': 'de' } }
      )
      const data = await res.json()
      if (!Array.isArray(data) || data.length === 0) {
        setGeoError('PLZ nicht gefunden. Bitte prüfe deine Eingabe.')
        return
      }
      const { lat, lon, display_name } = data[0]
      const location = shortenDisplayName(display_name ?? plz)
      await saveLocation(Number(lat), Number(lon), location)
    } catch {
      toast.error('Standort konnte nicht gespeichert werden.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 animate-fade-in">
      {/* Backdrop */}
      <div
        className="absolute inset-0 bg-black/40 backdrop-blur-sm"
        onClick={dismiss}
      />

      {/* Modal */}
      <div className={cn(
        'relative w-full max-w-md bg-white rounded-2xl shadow-2xl overflow-hidden animate-scale-in',
      )}>
        {/* Close */}
        <button
          onClick={dismiss}
          aria-label="Später"
          className="absolute top-4 right-4 p-1.5 rounded-full text-gray-400 hover:bg-stone-100 hover:text-gray-600 transition-colors"
        >
          <X className="w-4 h-4" />
        </button>

        {/* Header */}
        <div className="bg-gradient-to-br from-primary-500 to-primary-700 px-6 pt-8 pb-10 text-white text-center">
          <div className="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-white/20 mb-4">
            <MapPin className="w-7 h-7" />
          </div>
          <h2 className="text-xl font-bold leading-snug">
            MensaEna zeigt dir Hilfe in deiner Nähe
          </h2>
          <p className="text-sm text-white/80 mt-2 leading-relaxed">
            Dafür brauchen wir deinen ungefähren Standort.
            Deine genaue Adresse wird niemals geteilt.
          </p>
        </div>

        {/* Scallop */}
        <div className="relative -mt-4 h-4 bg-white rounded-t-[2rem]" />

        {/* Body */}
        <div className="px-6 pb-6 space-y-3 -mt-2">
          {geoError && (
            <p className="text-sm text-amber-700 bg-amber-50 border border-amber-200 rounded-xl px-4 py-2.5">
              {geoError}
            </p>
          )}

          {mode === 'choose' && (
            <>
              <button
                onClick={handleGeoLocation}
                disabled={loading}
                className={cn(
                  'w-full flex items-center justify-center gap-2 py-3 px-4 rounded-xl font-medium text-sm transition-all',
                  'bg-primary-500 text-white hover:bg-primary-600 active:scale-[0.98]',
                  loading && 'opacity-60 cursor-not-allowed'
                )}
              >
                {loading
                  ? <Loader2 className="w-4 h-4 animate-spin" />
                  : <span>📍</span>
                }
                Standort automatisch erkennen
              </button>

              <button
                onClick={() => setMode('address')}
                disabled={loading}
                className="w-full flex items-center justify-center gap-2 py-3 px-4 rounded-xl font-medium text-sm border border-stone-200 text-gray-700 hover:bg-stone-50 transition-colors"
              >
                <MapPin className="w-4 h-4 text-gray-400" />
                Adresse suchen
              </button>

              <button
                onClick={() => setMode('plz')}
                disabled={loading}
                className="w-full flex items-center justify-center gap-2 py-3 px-4 rounded-xl font-medium text-sm border border-stone-200 text-gray-700 hover:bg-stone-50 transition-colors"
              >
                Postleitzahl eingeben
              </button>
            </>
          )}

          {mode === 'address' && (
            <div className="space-y-3">
              <AddressAutocomplete
                onSelect={async (r: PhotonResult) => {
                  setLoading(true)
                  try {
                    await saveLocation(r.latitude, r.longitude, r.displayName)
                  } catch {
                    toast.error('Standort konnte nicht gespeichert werden.')
                  } finally {
                    setLoading(false)
                  }
                }}
                placeholder="Straße, Ort oder PLZ suchen…"
              />
              <button
                type="button"
                onClick={() => { setMode('choose'); setGeoError(null) }}
                disabled={loading}
                className="w-full text-sm text-gray-400 hover:text-gray-600 py-1 transition-colors"
              >
                ← Zurück
              </button>
            </div>
          )}

          {mode === 'plz' && (
            <form onSubmit={handlePlzSubmit} className="space-y-3">
              <div className="flex gap-2">
                <select
                  value={country}
                  onChange={e => setCountry(e.target.value)}
                  className="input w-20 flex-shrink-0 text-sm"
                  disabled={loading}
                >
                  {COUNTRIES.map(c => (
                    <option key={c.code} value={c.code}>{c.code.toUpperCase()}</option>
                  ))}
                </select>
                <input
                  type="text"
                  value={plz}
                  onChange={e => setPlz(e.target.value)}
                  placeholder="z.B. 55545"
                  maxLength={10}
                  autoFocus
                  disabled={loading}
                  className="input flex-1 text-sm"
                />
              </div>

              <button
                type="submit"
                disabled={loading || !plz.trim()}
                className={cn(
                  'w-full flex items-center justify-center gap-2 py-3 px-4 rounded-xl font-medium text-sm transition-all',
                  'bg-primary-500 text-white hover:bg-primary-600 active:scale-[0.98]',
                  (loading || !plz.trim()) && 'opacity-60 cursor-not-allowed'
                )}
              >
                {loading && <Loader2 className="w-4 h-4 animate-spin" />}
                Standort speichern
              </button>

              <button
                type="button"
                onClick={() => { setMode('choose'); setGeoError(null) }}
                disabled={loading}
                className="w-full text-sm text-gray-400 hover:text-gray-600 py-1 transition-colors"
              >
                ← Zurück
              </button>
            </form>
          )}

          <button
            onClick={dismiss}
            className="w-full text-xs text-gray-400 hover:text-gray-500 py-1 transition-colors"
          >
            Später
          </button>
        </div>
      </div>
    </div>
  )
}
