'use client'

import { useEffect, useRef, useState, useCallback } from 'react'
import type { FarmListing } from '@/types/farm'
import { CATEGORY_ICONS } from '@/types/farm'
import { createClient } from '@/lib/supabase/client'

// eslint-disable-next-line @typescript-eslint/no-explicit-any
let L: any

const CATEGORY_PIN_COLORS: Record<string, string> = {
  'Bauernhof':                   '#D97706',
  'Hofladen':                    '#EA580C',
  'Direktvermarktung':           '#16A34A',
  'Wochenmarkt':                 '#2563EB',
  'Solidarische Landwirtschaft': '#059669',
  'Biohof':                      '#65A30D',
  'Selbsternte':                 '#CA8A04',
  'Lieferdienst':                '#7C3AED',
}

/* ── Haversine distance (km) ─────────────────────────────────── */
function haversine(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371
  const dLat = ((lat2 - lat1) * Math.PI) / 180
  const dLon = ((lon2 - lon1) * Math.PI) / 180
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
}

/* ── Pin Icon ────────────────────────────────────────────────── */
function makePinIcon(category: string, isBio: boolean, selected = false) {
  const color  = CATEGORY_PIN_COLORS[category] || '#4B5563'
  const icon   = CATEGORY_ICONS[category as keyof typeof CATEGORY_ICONS] || '🏡'
  const border = isBio    ? '3px solid #84CC16'
               : selected ? '3px solid #3B82F6'
               : '3px solid white'
  const size   = selected ? 44 : 36
  const shadow = selected ? '0 4px 16px rgba(59,130,246,0.5)' : '0 2px 8px rgba(0,0,0,0.25)'
  return L.divIcon({
    html: `<div style="width:${size}px;height:${size}px;background:${color};border:${border};
      border-radius:50% 50% 50% 0;transform:rotate(-45deg);box-shadow:${shadow};
      display:flex;align-items:center;justify-content:center;transition:all .2s;">
      <span style="transform:rotate(45deg);font-size:${selected ? 18 : 15}px;line-height:1;">${icon}</span></div>`,
    className: '',
    iconSize:    [size, size],
    iconAnchor:  [size / 2, size],
    popupAnchor: [0, -size],
  })
}

/* ── Popup HTML ──────────────────────────────────────────────── */
function popupHtml(farm: FarmListing) {
  const catIcon = CATEGORY_ICONS[farm.category] || '🏡'
  const prods   = farm.products?.slice(0, 5).join(' · ') || ''
  const phone   = farm.phone
    ? `<a href="tel:${farm.phone}" style="color:#6B7280;font-size:11px;text-decoration:none;">📞 ${farm.phone}</a>`
    : ''
  const web = farm.website
    ? `<a href="${farm.website}" target="_blank" rel="noopener" style="color:#6B7280;font-size:11px;text-decoration:none;">🌐 Website</a>`
    : ''
  const hours = farm.opening_hours
    ? (() => {
        try {
          const oh = farm.opening_hours as Record<string, string>
          const info = oh['info'] || Object.entries(oh).slice(0, 3).map(([k, v]) => `${k}: ${v}`).join(', ')
          return info ? `<div style="font-size:10px;color:#9CA3AF;margin-top:4px;">🕐 ${info.slice(0, 80)}</div>` : ''
        } catch { return '' }
      })()
    : ''

  return `
    <div style="padding:6px 2px;min-width:220px;max-width:280px;font-family:system-ui,sans-serif">
      <div style="display:flex;align-items:center;gap:6px;margin-bottom:6px">
        <span style="font-size:18px">${catIcon}</span>
        <div>
          <div style="font-size:10px;color:#6B7280;font-weight:500;text-transform:uppercase;letter-spacing:.5px">
            ${farm.category}${farm.is_bio ? ' · 🌿 Bio' : ''}${farm.is_verified ? ' · ✓' : ''}
          </div>
          <div style="font-weight:700;font-size:14px;color:#111827;line-height:1.3">${farm.name}</div>
        </div>
      </div>
      <div style="font-size:11px;color:#6B7280;margin-bottom:6px">
        📍 ${farm.address ? farm.address + ', ' : ''}${farm.postal_code || ''} ${farm.city}${farm.state ? ', ' + farm.state : ''}
      </div>
      ${prods ? `<div style="font-size:11px;color:#059669;background:#F0FDF4;padding:4px 8px;border-radius:6px;margin-bottom:6px;line-height:1.4">${prods}</div>` : ''}
      ${hours}
      <div style="display:flex;gap:8px;flex-wrap:wrap;margin:6px 0 8px">${phone}${web}</div>
      <a href="/dashboard/supply/farm/${farm.slug}"
         style="display:block;text-align:center;background:#16A34A;color:white;font-size:12px;font-weight:600;
                padding:7px 14px;border-radius:8px;text-decoration:none;">
        Details ansehen →
      </a>
    </div>`
}

/* ── Fetch ALL farms from Supabase ───────────────────────────── */
async function fetchAllMapFarms(
  searchQ: string,
  filters: {
    category: string; categories: string[]; country: string; bio: boolean
    delivery: boolean; product: string; state: string
  }
): Promise<FarmListing[]> {
  const supabase = createClient()
  const MAP_COLS = 'id,name,slug,category,city,state,postal_code,address,latitude,longitude,products,phone,website,opening_hours,is_bio,is_verified,country,description,delivery_options,services,subcategories,email,image_url,source_url,source_name,imported_at,last_verified_at,created_at,updated_at,is_seasonal,is_public'
  const allFarms: FarmListing[] = []
  let from = 0
  const batchSize = 1000

  while (true) {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    let q: any = supabase
      .from('farm_listings')
      .select(MAP_COLS)
      .eq('is_public', true)
      .not('latitude', 'is', null)
      .not('longitude', 'is', null)
      .order('name', { ascending: true })
      .range(from, from + batchSize - 1)

    if (searchQ) q = q.or(`name.ilike.%${searchQ}%,city.ilike.%${searchQ}%,description.ilike.%${searchQ}%,state.ilike.%${searchQ}%`)
    // Multi-category support
    const cats = filters.categories.length > 0 ? filters.categories : (filters.category ? [filters.category] : [])
    if (cats.length === 1) q = q.eq('category', cats[0])
    else if (cats.length > 1) q = q.in('category', cats)
    if (filters.country)  q = q.eq('country', filters.country)
    if (filters.state)    q = q.ilike('state', `%${filters.state}%`)
    if (filters.bio)      q = q.eq('is_bio', true)
    if (filters.product)  q = q.contains('products', [filters.product])
    if (filters.delivery) q = q.not('delivery_options', 'eq', '{}')

    const { data, error } = await q
    if (error || !data || data.length === 0) break
    allFarms.push(...data)
    if (data.length < batchSize) break
    from += batchSize
  }
  return allFarms
}

/* ── Props ───────────────────────────────────────────────────── */
export interface MapFilters {
  category: string
  categories: string[]
  country: string
  bio: boolean
  delivery: boolean
  product: string
  state: string
}

export default function FarmsMapView({
  selectedFarm,
  onSelectFarm,
  searchQ = '',
  filters = { category: '', categories: [], country: '', bio: false, delivery: false, product: '', state: '' },
}: {
  selectedFarm: FarmListing | null
  onSelectFarm: (farm: FarmListing | null) => void
  searchQ?: string
  filters?: MapFilters
}) {
  const mapRef      = useRef<HTMLDivElement>(null)
  const mapInstance = useRef<import('leaflet').Map | null>(null)
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const layerRef    = useRef<any>(null)
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const userMarker  = useRef<any>(null)
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const radiusCircle = useRef<any>(null)
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const tileLayerRef = useRef<any>(null)

  const [mapReady,    setMapReady]    = useState(false)
  const [farms,       setFarms]       = useState<FarmListing[]>([])
  const [dataLoading, setDataLoading] = useState(true)
  const [dataCount,   setDataCount]   = useState(0)

  // Satellite toggle
  const [satellite, setSatellite] = useState(false)
  // Proximity
  const [userPos,    setUserPos]   = useState<{ lat: number; lng: number } | null>(null)
  const [radius,     setRadius]    = useState(50)          // km
  const [nearbyMode, setNearbyMode] = useState(false)
  const [locating,   setLocating]  = useState(false)
  // PLZ search
  const [plzInput,   setPlzInput]  = useState('')
  const [plzLoading, setPlzLoading] = useState(false)
  const [plzPos,     setPlzPos]    = useState<{ lat: number; lng: number } | null>(null)

  /* ── Load ALL farms ──────────────────────────────────────────── */
  useEffect(() => {
    let cancelled = false
    setDataLoading(true)
    setFarms([])

    fetchAllMapFarms(searchQ, filters).then((data) => {
      if (!cancelled) {
        setFarms(data)
        setDataCount(data.length)
        setDataLoading(false)
      }
    }).catch(() => { if (!cancelled) setDataLoading(false) })

    return () => { cancelled = true }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [searchQ, filters.category, filters.categories.join(','), filters.country, filters.bio, filters.delivery, filters.product, filters.state])

  /* ── Init Leaflet ────────────────────────────────────────────── */
  useEffect(() => {
    if (!mapRef.current || mapInstance.current) return
    let mounted = true

    const init = async () => {
      L = (await import('leaflet')).default
      if (!mounted || !mapRef.current) return

      // Load Leaflet CSS
      if (!document.getElementById('leaflet-css')) {
        const link = document.createElement('link')
        link.id = 'leaflet-css'
        link.rel = 'stylesheet'
        link.href = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css'
        document.head.appendChild(link)
      }
      // Load MarkerCluster CSS
      if (!document.getElementById('cluster-css')) {
        const link = document.createElement('link')
        link.id = 'cluster-css'
        link.rel = 'stylesheet'
        link.href = 'https://unpkg.com/leaflet.markercluster@1.5.3/dist/MarkerCluster.css'
        document.head.appendChild(link)
        const link2 = document.createElement('link')
        link2.id = 'cluster-css2'
        link2.rel = 'stylesheet'
        link2.href = 'https://unpkg.com/leaflet.markercluster@1.5.3/dist/MarkerCluster.Default.css'
        document.head.appendChild(link2)
      }
      // Load MarkerCluster JS
      if (!(window as any).LMC) {
        await new Promise<void>((resolve) => {
          const script = document.createElement('script')
          script.src = 'https://unpkg.com/leaflet.markercluster@1.5.3/dist/leaflet.markercluster.js'
          script.onload = () => { (window as any).LMC = true; resolve() }
          script.onerror = () => resolve()
          document.head.appendChild(script)
        })
      }

      const map = L.map(mapRef.current!, {
        center: [47.5, 11.5],
        zoom: 6,
        zoomControl: false,
        attributionControl: true,
        tap: true,          // better mobile touch
      })

      // Custom zoom control top-right
      L.control.zoom({ position: 'topright' }).addTo(map)

      // Default tile layer (OSM)
      tileLayerRef.current = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
        maxZoom: 19,
      }).addTo(map)

      mapInstance.current = map
      layerRef.current    = L.layerGroup().addTo(map)
      setMapReady(true)
    }

    init()
    return () => {
      mounted = false
      mapInstance.current?.remove()
      mapInstance.current = null
      layerRef.current    = null
    }
  }, [])

  /* ── Toggle satellite layer ──────────────────────────────────── */
  useEffect(() => {
    if (!mapInstance.current || !tileLayerRef.current) return
    tileLayerRef.current.remove()
    if (satellite) {
      tileLayerRef.current = L.tileLayer(
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
        { attribution: 'Tiles © Esri', maxZoom: 19 }
      ).addTo(mapInstance.current)
    } else {
      tileLayerRef.current = L.tileLayer(
        'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
        { attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>', maxZoom: 19 }
      ).addTo(mapInstance.current)
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [satellite])

  /* ── Draw markers ────────────────────────────────────────────── */
  const drawMarkers = useCallback(() => {
    if (!mapReady || !mapInstance.current || !L || dataLoading) return

    // Clear old layer
    if (layerRef.current) {
      layerRef.current.clearLayers()
      mapInstance.current.removeLayer(layerRef.current)
    }

    let visibleFarms = farms.filter((f) => f.latitude && f.longitude)

    // Nearby filter
    const activePos = plzPos || userPos
    if (nearbyMode && activePos) {
      visibleFarms = visibleFarms.filter(
        (f) => haversine(activePos.lat, activePos.lng, f.latitude!, f.longitude!) <= radius
      )
    }

    // Create cluster group
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    let container: any
    try {
      if ((window as any).L?.MarkerClusterGroup || (L as any).MarkerClusterGroup) {
        const MCG = (L as any).MarkerClusterGroup || (window as any).L.MarkerClusterGroup
        container = new MCG({
          chunkedLoading: true,
          maxClusterRadius: 60,
          showCoverageOnHover: false,
          iconCreateFunction: (cluster: any) => {
            const n = cluster.getChildCount()
            const size = n > 100 ? 48 : n > 20 ? 42 : 36
            const bg   = n > 100 ? '#DC2626' : n > 20 ? '#D97706' : '#16A34A'
            return L.divIcon({
              html: `<div style="width:${size}px;height:${size}px;background:${bg};color:white;
                border-radius:50%;display:flex;align-items:center;justify-content:center;
                font-weight:700;font-size:${n > 99 ? 11 : 13}px;
                border:3px solid white;box-shadow:0 2px 8px rgba(0,0,0,0.3);">${n}</div>`,
              className: '',
              iconSize: [size, size],
              iconAnchor: [size / 2, size / 2],
            })
          },
        })
      } else {
        container = L.layerGroup()
      }
    } catch {
      container = L.layerGroup()
    }

    visibleFarms.forEach((farm) => {
      const isSelected = selectedFarm?.id === farm.id
      const icon   = makePinIcon(farm.category, farm.is_bio, isSelected)
      const marker = L.marker([farm.latitude!, farm.longitude!], { icon })
      marker.bindPopup(L.popup({ maxWidth: 300 }).setContent(popupHtml(farm)), { autoPan: true })
      marker.on('click', () => { onSelectFarm(farm); marker.openPopup() })
      container.addLayer(marker)
    })

    mapInstance.current.addLayer(container)
    layerRef.current = container

    // Fit bounds on first load (not in nearby mode)
    if (!selectedFarm && !nearbyMode && visibleFarms.length > 0) {
      try {
        const bounds = L.latLngBounds(visibleFarms.map((f) => [f.latitude!, f.longitude!]))
        mapInstance.current.fitBounds(bounds, { padding: [40, 40], maxZoom: 8 })
      } catch { /* ignore */ }
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [farms, mapReady, dataLoading, nearbyMode, radius, userPos, plzPos, selectedFarm])

  useEffect(() => { drawMarkers() }, [drawMarkers])

  /* ── Fly to selected farm ────────────────────────────────────── */
  useEffect(() => {
    if (!mapInstance.current || !selectedFarm?.latitude || !selectedFarm?.longitude) return
    mapInstance.current.flyTo([selectedFarm.latitude, selectedFarm.longitude], 14, { animate: true, duration: 0.8 })
  }, [selectedFarm])

  /* ── User location ───────────────────────────────────────────── */
  const locateUser = useCallback(() => {
    if (!navigator.geolocation || !mapInstance.current) return
    setLocating(true)
    navigator.geolocation.getCurrentPosition(
      ({ coords }) => {
        const { latitude: lat, longitude: lng } = coords
        setUserPos({ lat, lng })
        setNearbyMode(true)
        setLocating(false)

        if (userMarker.current) { userMarker.current.remove(); userMarker.current = null }
        if (radiusCircle.current) { radiusCircle.current.remove(); radiusCircle.current = null }

        const icon = L.divIcon({
          html: `<div style="width:20px;height:20px;background:#3B82F6;border:3px solid white;border-radius:50%;box-shadow:0 2px 8px rgba(59,130,246,0.5);"></div>`,
          className: '', iconSize: [20, 20], iconAnchor: [10, 10],
        })
        userMarker.current = L.marker([lat, lng], { icon })
          .addTo(mapInstance.current!).bindPopup('<b>📍 Dein Standort</b>')
        radiusCircle.current = L.circle([lat, lng], {
          radius: radius * 1000,
          color: '#3B82F6', fillColor: '#3B82F6', fillOpacity: 0.06, weight: 2,
        }).addTo(mapInstance.current!)

        mapInstance.current!.flyTo([lat, lng], 10, { animate: true, duration: 1 })
      },
      () => setLocating(false),
      { enableHighAccuracy: true, timeout: 10000 }
    )
  }, [radius])

  /* ── Update radius circle when radius changes ─────────────────── */
  useEffect(() => {
    if (!radiusCircle.current || !userPos) return
    radiusCircle.current.setRadius(radius * 1000)
  }, [radius, userPos])

  /* ── PLZ geocode via Nominatim ───────────────────────────────── */
  const geocodePlZ = useCallback(async () => {
    if (!plzInput.trim() || !mapInstance.current) return
    setPlzLoading(true)
    try {
      const res = await fetch(
        `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(plzInput)}&format=json&limit=1&addressdetails=1`,
        { headers: { 'Accept-Language': 'de', 'User-Agent': 'Mensaena/1.0' } }
      )
      const data = await res.json()
      if (data && data[0]) {
        const lat = parseFloat(data[0].lat)
        const lng = parseFloat(data[0].lon)
        setPlzPos({ lat, lng })
        setNearbyMode(true)

        if (radiusCircle.current) { radiusCircle.current.remove(); radiusCircle.current = null }
        if (userMarker.current)   { userMarker.current.remove();   userMarker.current = null }

        const icon = L.divIcon({
          html: `<div style="width:20px;height:20px;background:#059669;border:3px solid white;border-radius:50%;box-shadow:0 2px 8px rgba(5,150,105,0.5);"></div>`,
          className: '', iconSize: [20, 20], iconAnchor: [10, 10],
        })
        userMarker.current = L.marker([lat, lng], { icon })
          .addTo(mapInstance.current!).bindPopup(`<b>📍 ${plzInput}</b>`)
        radiusCircle.current = L.circle([lat, lng], {
          radius: radius * 1000,
          color: '#059669', fillColor: '#059669', fillOpacity: 0.06, weight: 2,
        }).addTo(mapInstance.current!)
        mapInstance.current!.flyTo([lat, lng], 10, { animate: true, duration: 1 })
      }
    } catch { /* ignore */ }
    setPlzLoading(false)
  }, [plzInput, radius])

  /* ── Clear nearby mode ───────────────────────────────────────── */
  const clearNearby = useCallback(() => {
    setNearbyMode(false)
    setUserPos(null)
    setPlzPos(null)
    setPlzInput('')
    if (userMarker.current)   { userMarker.current.remove();   userMarker.current = null }
    if (radiusCircle.current) { radiusCircle.current.remove(); radiusCircle.current = null }
  }, [])

  const isLoading = dataLoading || !mapReady
  const activePos = plzPos || userPos

  // Farms within radius for count display
  const nearbyCount = nearbyMode && activePos
    ? farms.filter((f) => f.latitude && f.longitude && haversine(activePos.lat, activePos.lng, f.latitude!, f.longitude!) <= radius).length
    : dataCount

  return (
    <div className="relative">
      {/* Map container */}
      <div
        ref={mapRef}
        className="w-full rounded-2xl border border-stone-200 shadow-sm z-0"
        style={{ height: 'clamp(400px, 60dvh, 650px)' }}
      />

      {/* Loading overlay */}
      {isLoading && (
        <div className="absolute inset-0 flex items-center justify-center bg-green-50/90 rounded-2xl z-10">
          <div className="text-center">
            <div className="w-12 h-12 border-4 border-green-400 border-t-transparent rounded-full animate-spin mx-auto mb-4" />
            <p className="text-green-700 text-sm font-semibold">
              {dataLoading ? 'Lade alle Betriebe…' : 'Karte wird initialisiert…'}
            </p>
          </div>
        </div>
      )}

      {!isLoading && (
        <>
          {/* ── Top-left toolbar ─────────────────────────────── */}
          <div className="absolute top-3 left-3 z-[1000] flex flex-col gap-2">

            {/* Satellite toggle */}
            <button
              onClick={() => setSatellite((s) => !s)}
              title={satellite ? 'Straßenkarte anzeigen' : 'Satellitenansicht'}
              className={`w-9 h-9 rounded-xl shadow border flex items-center justify-center text-base transition-all ${
                satellite ? 'bg-blue-600 border-blue-600 text-white' : 'bg-white border-stone-200 hover:border-blue-400 text-ink-700'
              }`}
            >
              🛰️
            </button>

            {/* Locate me */}
            <button
              onClick={locateUser}
              title="Mein Standort"
              disabled={locating}
              className={`w-9 h-9 rounded-xl shadow border flex items-center justify-center text-base transition-all ${
                nearbyMode && userPos ? 'bg-blue-600 border-blue-600 text-white' : 'bg-white border-stone-200 hover:border-blue-400 text-ink-700'
              } disabled:opacity-50`}
            >
              {locating ? <span className="w-4 h-4 border-2 border-blue-400 border-t-transparent rounded-full animate-spin" /> : '📍'}
            </button>

            {/* Clear nearby */}
            {nearbyMode && (
              <button
                onClick={clearNearby}
                title="Umkreissuche deaktivieren"
                className="w-9 h-9 rounded-xl shadow border bg-red-50 border-red-200 hover:bg-red-100 text-red-600 flex items-center justify-center text-sm font-bold"
              >
                ✕
              </button>
            )}
          </div>

          {/* ── PLZ + Radius toolbar ─────────────────────────── */}
          <div className="absolute top-3 left-14 z-[1000] flex items-center gap-2">
            <div className="flex bg-white/95 backdrop-blur-sm rounded-xl shadow border border-stone-200 overflow-hidden">
              <input
                type="text"
                value={plzInput}
                onChange={(e) => setPlzInput(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && geocodePlZ()}
                placeholder="PLZ oder Ort…"
                className="px-3 py-2 text-xs outline-none w-32 sm:w-40 bg-transparent"
              />
              <button
                onClick={geocodePlZ}
                disabled={plzLoading || !plzInput.trim()}
                className="px-3 py-2 bg-green-600 text-white text-xs font-semibold hover:bg-green-700 transition-colors disabled:opacity-50"
              >
                {plzLoading ? '…' : 'Suchen'}
              </button>
            </div>

            {nearbyMode && (
              <div className="flex bg-white/95 backdrop-blur-sm rounded-xl shadow border border-stone-200 items-center gap-1 px-2 py-1">
                <span className="text-xs text-ink-500 whitespace-nowrap">Radius:</span>
                <select
                  value={radius}
                  onChange={(e) => setRadius(Number(e.target.value))}
                  className="text-xs outline-none bg-transparent font-medium text-ink-800 cursor-pointer"
                >
                  {[10, 20, 30, 50, 75, 100].map((r) => (
                    <option key={r} value={r}>{r} km</option>
                  ))}
                </select>
              </div>
            )}
          </div>

          {/* ── Count badge (top-right) ───────────────────────── */}
          <div className="absolute top-3 right-12 z-[1000] bg-white/95 backdrop-blur-sm rounded-xl shadow border border-stone-100 px-3 py-2 flex items-center gap-2">
            <span className="text-base">📍</span>
            <div>
              <div className="text-xs font-bold text-ink-800">
                {nearbyMode ? `${nearbyCount} / ${dataCount}` : dataCount.toLocaleString()} Betriebe
              </div>
              <div className="text-[10px] text-ink-500">
                {nearbyMode ? `im Umkreis ${radius} km` : 'auf der Karte'}
              </div>
            </div>
          </div>

          {/* ── Legend ───────────────────────────────────────── */}
          <LegendPanel />
        </>
      )}

      {/* ── Selected farm mini-card (bottom) ─────────────────── */}
      {selectedFarm && (
        <div className="absolute bottom-4 left-1/2 -translate-x-1/2 z-[1000] w-72 bg-white rounded-2xl shadow-xl border border-green-200 p-4">
          <div className="flex items-start gap-3">
            <span className="text-2xl">{CATEGORY_ICONS[selectedFarm.category] || '🏡'}</span>
            <div className="flex-1 min-w-0">
              <p className="font-semibold text-ink-900 text-sm leading-tight truncate">{selectedFarm.name}</p>
              <p className="text-xs text-ink-500 mt-0.5 truncate">
                {selectedFarm.postal_code} {selectedFarm.city}
              </p>
              {selectedFarm.products && selectedFarm.products.length > 0 && (
                <p className="text-xs text-green-700 mt-1 truncate">
                  {selectedFarm.products.slice(0, 4).join(' · ')}
                </p>
              )}
            </div>
            <button onClick={() => onSelectFarm(null)} className="text-ink-400 hover:text-ink-600 text-xl leading-none">×</button>
          </div>
          <a
            href={`/dashboard/supply/farm/${selectedFarm.slug}`}
            className="mt-3 flex items-center justify-center gap-2 bg-green-600 hover:bg-green-700 text-white text-xs font-semibold py-2 px-4 rounded-xl transition-colors"
          >
            Vollständiges Profil ansehen →
          </a>
        </div>
      )}
    </div>
  )
}

/* ── Legend Panel ────────────────────────────────────────────── */
function LegendPanel() {
  const [open, setOpen] = useState(false)
  return (
    <div className="absolute bottom-4 left-3 z-[1000]">
      <button
        onClick={() => setOpen(!open)}
        className="bg-white/95 backdrop-blur-sm rounded-xl shadow border border-stone-100 px-3 py-2 text-xs font-semibold text-ink-700 flex items-center gap-1.5"
      >
        🗺️ Legende {open ? '▲' : '▼'}
      </button>
      {open && (
        <div className="absolute bottom-full mb-2 left-0 bg-white rounded-xl shadow-lg border border-stone-100 p-3 w-52">
          <div className="space-y-1.5">
            {(Object.entries(CATEGORY_PIN_COLORS) as [string, string][]).map(([cat, color]) => (
              <div key={cat} className="flex items-center gap-2">
                <div className="w-3 h-3 rounded-full shrink-0 border-2 border-white shadow-sm" style={{ background: color }} />
                <span className="text-xs text-ink-700">{CATEGORY_ICONS[cat as keyof typeof CATEGORY_ICONS]} {cat}</span>
              </div>
            ))}
            <div className="pt-1 mt-1 border-t border-stone-100 flex items-center gap-2">
              <div className="w-3 h-3 rounded-full shrink-0 bg-lime-500 border-2 border-lime-300" />
              <span className="text-xs text-ink-700">🌿 Bio-Betrieb</span>
            </div>
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 rounded-full shrink-0 bg-blue-500 border-2 border-blue-200" />
              <span className="text-xs text-ink-700">📍 Standort</span>
            </div>
            <div className="pt-1 mt-1 border-t border-stone-100">
              <p className="text-[10px] text-ink-400 font-medium mb-1">Cluster-Farben</p>
              <div className="flex gap-2 text-[10px] text-ink-600">
                <span className="flex items-center gap-1"><span className="w-2.5 h-2.5 rounded-full bg-green-600 inline-block" /> &lt;20</span>
                <span className="flex items-center gap-1"><span className="w-2.5 h-2.5 rounded-full bg-amber-600 inline-block" /> 20–100</span>
                <span className="flex items-center gap-1"><span className="w-2.5 h-2.5 rounded-full bg-red-600 inline-block" /> &gt;100</span>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
