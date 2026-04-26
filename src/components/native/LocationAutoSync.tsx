'use client'

import { useEffect, useRef } from 'react'
import { createClient } from '@/lib/supabase/client'
import { reverseGeocode, formatAddressPrivacy } from '@/lib/api/nominatim'

// Maximales Sync-Intervall: 30 Minuten (verhindert Nominatim-Spam)
const SYNC_INTERVAL_MS = 30 * 60 * 1000
const STORAGE_KEY = 'msa_location_synced_at'

async function getPosition(): Promise<{ lat: number; lng: number } | null> {
  try {
    // Capacitor Geolocation (Native) – zuverlässiger im Hintergrund auf Android
    const { Capacitor } = await import('@capacitor/core')
    if (Capacitor.isNativePlatform()) {
      const { Geolocation } = await import('@capacitor/geolocation')
      const perm = await Geolocation.checkPermissions()
      // Nur syncen wenn Permission bereits gewährt – kein automatischer Popup
      if (perm.location !== 'granted') return null
      const pos = await Geolocation.getCurrentPosition({
        enableHighAccuracy: false,
        timeout: 10000,
      })
      return { lat: pos.coords.latitude, lng: pos.coords.longitude }
    }
  } catch {
    // Kein Capacitor oder Permission nicht vorhanden
  }

  // Web-Fallback: nur syncen wenn Browser-Permission bereits 'granted'
  try {
    const perm = await navigator.permissions.query({ name: 'geolocation' as PermissionName })
    if (perm.state !== 'granted') return null
    const pos = await new Promise<GeolocationPosition>((resolve, reject) =>
      navigator.geolocation.getCurrentPosition(resolve, reject, {
        enableHighAccuracy: false,
        timeout: 10000,
        maximumAge: 5 * 60 * 1000,
      })
    )
    return { lat: pos.coords.latitude, lng: pos.coords.longitude }
  } catch {
    return null
  }
}

async function syncLocation() {
  // Throttle: nicht öfter als alle 30 Minuten syncen
  const last = Number(localStorage.getItem(STORAGE_KEY) ?? 0)
  if (Date.now() - last < SYNC_INTERVAL_MS) return

  const position = await getPosition()
  if (!position) return

  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return

  // Privacy-Modus: nur Stadtteil/Stadt/Bundesland – niemals Straße/Hausnummer
  const addr = await reverseGeocode(position.lat, position.lng, { zoom: 13 })
  const locationText = formatAddressPrivacy(addr)

  await supabase
    .from('profiles')
    .update({
      latitude:  position.lat,
      longitude: position.lng,
      ...(locationText ? { location: locationText } : {}),
    })
    .eq('id', user.id)

  localStorage.setItem(STORAGE_KEY, String(Date.now()))
}

// Wird einmal ins Root-Layout eingebunden und arbeitet dann still
// im Hintergrund – kein Permission-Popup, kein UI.
export default function LocationAutoSync() {
  const mounted = useRef(false)

  useEffect(() => {
    if (!mounted.current) {
      mounted.current = true
      void syncLocation()
    }

    const onVisibilityChange = () => {
      if (document.visibilityState === 'visible') void syncLocation()
    }
    document.addEventListener('visibilitychange', onVisibilityChange)
    return () => document.removeEventListener('visibilitychange', onVisibilityChange)
  }, [])

  return null
}
