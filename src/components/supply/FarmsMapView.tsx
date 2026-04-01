'use client'

import { useEffect, useRef, useState } from 'react'
import type { FarmListing } from '@/types/farm'
import { CATEGORY_ICONS } from '@/types/farm'
import { createBrowserClient } from '@supabase/ssr'

// Public Supabase credentials (safe to expose - anon key only)
const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5ODcxMTgsImV4cCI6MjA5MDU2MzExOH0.Q5ciM8f--f1xAsKyr9-hv1mz7GGbJ6vbxPe4Cj5mgYE'

// eslint-disable-next-line @typescript-eslint/no-explicit-any
let L: any

const CATEGORY_PIN_COLORS: Record<string, string> = {
  'Bauernhof':                  '#D97706',
  'Hofladen':                   '#EA580C',
  'Direktvermarktung':          '#16A34A',
  'Wochenmarkt':                '#2563EB',
  'Solidarische Landwirtschaft':'#059669',
  'Biohof':                     '#65A30D',
  'Selbsternte':                '#CA8A04',
  'Lieferdienst':               '#7C3AED',
}

/* ── Pin-Icon ──────────────────────────────────────────────────────── */
function makePinIcon(category: string, isBio: boolean, selected = false) {
  const color  = CATEGORY_PIN_COLORS[category] || '#4B5563'
  const icon   = CATEGORY_ICONS[category as keyof typeof CATEGORY_ICONS] || '🏡'
  const border = isBio    ? '3px solid #84CC16'
               : selected ? '3px solid #3B82F6'
               : '3px solid white'
  const size   = selected ? 44 : 36
  const shadow = selected ? '0 4px 16px rgba(59,130,246,0.5)' : '0 2px 8px rgba(0,0,0,0.25)'
  return L.divIcon({
    html: `<div style="
      width:${size}px;height:${size}px;
      background:${color};border:${border};
      border-radius:50% 50% 50% 0;transform:rotate(-45deg);
      box-shadow:${shadow};
      display:flex;align-items:center;justify-content:center;
      transition:all .2s;
    "><span style="transform:rotate(45deg);font-size:${selected?18:15}px;line-height:1;">${icon}</span></div>`,
    className: '',
    iconSize:    [size, size],
    iconAnchor:  [size / 2, size],
    popupAnchor: [0, -size],
  })
}

/* ── Popup HTML ────────────────────────────────────────────────────── */
function popupHtml(farm: FarmListing) {
  const catIcon = CATEGORY_ICONS[farm.category] || '🏡'
  const prods   = farm.products?.slice(0, 5).join(' · ') || ''
  const phone   = farm.phone
    ? `<a href="tel:${farm.phone}" style="color:#6B7280;text-decoration:none;font-size:11px;">📞 ${farm.phone}</a>`
    : ''
  const web = farm.website
    ? `<a href="${farm.website}" target="_blank" rel="noopener" style="color:#6B7280;text-decoration:none;font-size:11px;">🌐 Website</a>`
    : ''
  const hours = farm.opening_hours
    ? (() => {
        try {
          const oh = farm.opening_hours as Record<string, string>
          const info = oh['info'] || Object.entries(oh).slice(0,3).map(([k,v])=>`${k}: ${v}`).join(', ')
          return info ? `<div style="font-size:10px;color:#9CA3AF;margin-top:4px;">🕐 ${info.slice(0,80)}</div>` : ''
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
      <div style="display:flex;gap:8px;flex-wrap:wrap;margin:6px 0 8px">
        ${phone}
        ${web}
      </div>
      <a href="/dashboard/supply/farm/${farm.slug}"
         style="display:block;text-align:center;background:#16A34A;color:white;font-size:12px;font-weight:600;
                padding:7px 14px;border-radius:8px;text-decoration:none;">
        Details ansehen →
      </a>
    </div>
  `
}

/* ── Fetch ALL farms from Supabase ────────────────────────────────── */
async function fetchAllMapFarms(
  searchQ: string,
  filters: {
    category: string; country: string; bio: boolean
    delivery: boolean; product: string; state: string
  }
): Promise<FarmListing[]> {
  const supabase = createBrowserClient(SUPABASE_URL, SUPABASE_ANON_KEY)
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
    if (filters.category) q = q.eq('category', filters.category)
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

/* ── Main Component ────────────────────────────────────────────────── */
export default function FarmsMapView({
  selectedFarm,
  onSelectFarm,
  searchQ = '',
  filters = { category: '', country: '', bio: false, delivery: false, product: '', state: '' },
}: {
  selectedFarm: FarmListing | null
  onSelectFarm: (farm: FarmListing | null) => void
  searchQ?: string
  filters?: {
    category: string; country: string; bio: boolean
    delivery: boolean; product: string; state: string
  }
}) {
  const mapRef      = useRef<HTMLDivElement>(null)
  const mapInstance = useRef<import('leaflet').Map | null>(null)
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const layerRef    = useRef<any>(null)
  const [mapReady, setMapReady] = useState(false)
  const [farms, setFarms] = useState<FarmListing[]>([])
  const [dataLoading, setDataLoading] = useState(true)
  const [dataCount, setDataCount] = useState(0)

  /* ── Load ALL farms directly ── */
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
    }).catch(() => {
      if (!cancelled) setDataLoading(false)
    })

    return () => { cancelled = true }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [searchQ, filters.category, filters.country, filters.bio, filters.delivery, filters.product, filters.state])

  /* ── Init Leaflet map ── */
  useEffect(() => {
    if (!mapRef.current || mapInstance.current) return
    let mounted = true

    const init = async () => {
      L = (await import('leaflet')).default
      if (!mounted || !mapRef.current) return

      const map = L.map(mapRef.current, {
        center: [51.2, 10.4],
        zoom: 6,
        zoomControl: true,
        attributionControl: true,
      })

      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
        maxZoom: 19,
      }).addTo(map)

      // Geolocation dot
      if (navigator.geolocation) {
        navigator.geolocation.getCurrentPosition(({ coords }) => {
          const icon = L.divIcon({
            html: `<div style="width:16px;height:16px;background:#3B82F6;border:3px solid white;border-radius:50%;box-shadow:0 2px 8px rgba(59,130,246,0.5);"></div>`,
            className: '', iconSize: [16, 16], iconAnchor: [8, 8],
          })
          L.marker([coords.latitude, coords.longitude], { icon })
            .addTo(map).bindPopup('<b>📍 Dein Standort</b>')
        }, () => {})
      }

      mapInstance.current = map
      layerRef.current = L.layerGroup().addTo(map)
      setMapReady(true)
    }

    init()
    return () => {
      mounted = false
      mapInstance.current?.remove()
      mapInstance.current = null
      layerRef.current = null
    }
  }, [])

  /* ── Render markers when farms + map both ready ── */
  useEffect(() => {
    if (!mapReady || !mapInstance.current || !layerRef.current || !L || dataLoading) return

    layerRef.current.clearLayers()

    const withCoords = farms.filter((f) => f.latitude && f.longitude)
    if (withCoords.length === 0) return

    // Use cluster if available, else simple markers
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    let markerContainer: any = layerRef.current

    try {
      // Dynamic import of cluster plugin
      if (typeof window !== 'undefined' && (window as any).L?.MarkerClusterGroup) {
        const cluster = (window as any).L.markerClusterGroup({ chunkedLoading: true, maxClusterRadius: 60 })
        mapInstance.current.addLayer(cluster)
        markerContainer = cluster
        layerRef.current = cluster
      }
    } catch { /* use layerGroup */ }

    withCoords.forEach((farm) => {
      const isSelected = selectedFarm?.id === farm.id
      const icon = makePinIcon(farm.category, farm.is_bio, isSelected)
      const marker = L.marker([farm.latitude!, farm.longitude!], { icon })
      marker.bindPopup(L.popup({ maxWidth: 300 }).setContent(popupHtml(farm)), { autoPan: true })
      marker.on('click', () => { onSelectFarm(farm); marker.openPopup() })
      markerContainer.addLayer(marker)
    })

    // Fit bounds on first load
    if (!selectedFarm) {
      try {
        const bounds = L.latLngBounds(withCoords.map((f) => [f.latitude!, f.longitude!]))
        mapInstance.current.fitBounds(bounds, { padding: [40, 40], maxZoom: 8 })
      } catch { /* ignore */ }
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [farms, mapReady, dataLoading])

  /* ── Fly to selected farm ── */
  useEffect(() => {
    if (!mapInstance.current || !selectedFarm?.latitude || !selectedFarm?.longitude) return
    mapInstance.current.flyTo([selectedFarm.latitude, selectedFarm.longitude], 14, { animate: true, duration: 0.8 })
  }, [selectedFarm])

  const isLoading = dataLoading || !mapReady

  return (
    <div className="relative">
      {/* Map container */}
      <div ref={mapRef} className="w-full h-[600px] rounded-2xl border border-gray-200 shadow-sm z-0" />

      {/* Loading overlay */}
      {isLoading && (
        <div className="absolute inset-0 flex items-center justify-center bg-green-50/90 rounded-2xl z-10">
          <div className="text-center">
            <div className="w-12 h-12 border-4 border-green-400 border-t-transparent rounded-full animate-spin mx-auto mb-4" />
            <p className="text-green-700 text-sm font-semibold">
              {dataLoading ? 'Lade alle Betriebe…' : 'Karte wird initialisiert…'}
            </p>
            <p className="text-green-500 text-xs mt-1">
              {dataLoading ? 'Einen Moment bitte' : ''}
            </p>
          </div>
        </div>
      )}

      {/* Count badge */}
      {!isLoading && (
        <div className="absolute top-3 right-3 z-[1000] bg-white/95 backdrop-blur-sm rounded-xl shadow border border-gray-100 px-3 py-2 flex items-center gap-2">
          <span className="text-lg">📍</span>
          <div>
            <div className="text-xs font-bold text-gray-800">{dataCount.toLocaleString()} Betriebe</div>
            <div className="text-[10px] text-gray-500">auf der Karte</div>
          </div>
        </div>
      )}

      {/* Legend */}
      <LegendPanel />

      {/* Selected farm card */}
      {selectedFarm && (
        <div className="absolute bottom-4 left-1/2 -translate-x-1/2 z-[1000] w-72 bg-white rounded-2xl shadow-xl border border-green-200 p-4">
          <div className="flex items-start gap-3">
            <span className="text-2xl">{CATEGORY_ICONS[selectedFarm.category] || '🏡'}</span>
            <div className="flex-1 min-w-0">
              <p className="font-semibold text-gray-900 text-sm leading-tight truncate">{selectedFarm.name}</p>
              <p className="text-xs text-gray-500 mt-0.5 truncate">
                {selectedFarm.postal_code} {selectedFarm.city}
              </p>
              {selectedFarm.products && selectedFarm.products.length > 0 && (
                <p className="text-xs text-green-700 mt-1 truncate">
                  {selectedFarm.products.slice(0, 4).join(' · ')}
                </p>
              )}
            </div>
            <button onClick={() => onSelectFarm(null)} className="text-gray-400 hover:text-gray-600 text-xl leading-none">×</button>
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

/* ── Legend Panel ──────────────────────────────────────────────────── */
function LegendPanel() {
  const [open, setOpen] = useState(false)
  return (
    <div className="absolute bottom-4 left-3 z-[1000]">
      <button
        onClick={() => setOpen(!open)}
        className="bg-white/95 backdrop-blur-sm rounded-xl shadow border border-gray-100 px-3 py-2 text-xs font-semibold text-gray-700 flex items-center gap-1.5"
      >
        🗺️ Legende {open ? '▲' : '▼'}
      </button>
      {open && (
        <div className="absolute bottom-full mb-2 left-0 bg-white rounded-xl shadow-lg border border-gray-100 p-3 w-52">
          <div className="space-y-1.5">
            {(Object.entries(CATEGORY_PIN_COLORS) as [string, string][]).map(([cat, color]) => (
              <div key={cat} className="flex items-center gap-2">
                <div className="w-3 h-3 rounded-full shrink-0 border-2 border-white shadow-sm" style={{ background: color }} />
                <span className="text-xs text-gray-700">{CATEGORY_ICONS[cat as keyof typeof CATEGORY_ICONS]} {cat}</span>
              </div>
            ))}
            <div className="pt-1 mt-1 border-t border-gray-100 flex items-center gap-2">
              <div className="w-3 h-3 rounded-full shrink-0 bg-lime-500 border-2 border-lime-300" />
              <span className="text-xs text-gray-700">🌿 Bio-Betrieb</span>
            </div>
            <div className="flex items-center gap-2">
              <div className="w-3 h-3 rounded-full shrink-0 bg-blue-500 border-2 border-blue-200" />
              <span className="text-xs text-gray-700">📍 Dein Standort</span>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
