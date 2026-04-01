'use client'

import { useEffect, useRef } from 'react'
import type { FarmListing } from '@/types/farm'
import { CATEGORY_ICONS } from '@/types/farm'

// eslint-disable-next-line @typescript-eslint/no-explicit-any
let L: any

const CATEGORY_PIN_COLORS: Record<string, string> = {
  'Bauernhof': '#D97706',
  'Hofladen': '#EA580C',
  'Direktvermarktung': '#16A34A',
  'Wochenmarkt': '#2563EB',
  'Solidarische Landwirtschaft': '#059669',
  'Biohof': '#65A30D',
  'Selbsternte': '#CA8A04',
  'Lieferdienst': '#7C3AED',
}

function makePinIcon(category: string, isBio: boolean) {
  const color = CATEGORY_PIN_COLORS[category] || '#4B5563'
  const icon = CATEGORY_ICONS[category as keyof typeof CATEGORY_ICONS] || '🏡'
  const border = isBio ? '3px solid #84CC16' : '3px solid white'
  return L.divIcon({
    html: `<div style="
      width:36px; height:36px;
      background:${color};
      border:${border};
      border-radius:50% 50% 50% 0;
      transform:rotate(-45deg);
      box-shadow:0 2px 8px rgba(0,0,0,0.3);
      display:flex; align-items:center; justify-content:center;
    "><span style="transform:rotate(45deg); font-size:16px; line-height:1;">${icon}</span></div>`,
    className: '',
    iconSize: [36, 36],
    iconAnchor: [18, 36],
    popupAnchor: [0, -36],
  })
}

export default function FarmsMapView({
  farms,
  selectedFarm,
  onSelectFarm,
}: {
  farms: FarmListing[]
  selectedFarm: FarmListing | null
  onSelectFarm: (farm: FarmListing | null) => void
}) {
  const mapRef = useRef<HTMLDivElement>(null)
  const mapInstance = useRef<import('leaflet').Map | null>(null)
  const markersRef = useRef<import('leaflet').LayerGroup | null>(null)

  // init map
  useEffect(() => {
    if (!mapRef.current || mapInstance.current) return
    let mounted = true

    const init = async () => {
      L = (await import('leaflet')).default
      if (!mounted || !mapRef.current) return

      const map = L.map(mapRef.current, {
        center: [47.8, 13.5],
        zoom: 6,
        zoomControl: true,
      })

      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
        maxZoom: 19,
      }).addTo(map)

      // User location
      if (navigator.geolocation) {
        navigator.geolocation.getCurrentPosition(
          ({ coords }) => {
            const userIcon = L.divIcon({
              html: `<div style="width:14px;height:14px;background:#4F6D8A;border:3px solid white;border-radius:50%;box-shadow:0 2px 8px rgba(0,0,0,0.3);"></div>`,
              className: '',
              iconSize: [14, 14],
              iconAnchor: [7, 7],
            })
            L.marker([coords.latitude, coords.longitude], { icon: userIcon })
              .addTo(map)
              .bindPopup('📍 Dein Standort')
          },
          () => {}
        )
      }

      mapInstance.current = map
      markersRef.current = L.layerGroup().addTo(map)
    }

    init()
    return () => {
      mounted = false
      mapInstance.current?.remove()
      mapInstance.current = null
    }
  }, [])

  // Update markers
  useEffect(() => {
    if (!mapInstance.current || !markersRef.current || !L) return
    markersRef.current.clearLayers()

    const withCoords = farms.filter((f) => f.latitude && f.longitude)

    withCoords.forEach((farm) => {
      const icon = makePinIcon(farm.category, farm.is_bio)
      const marker = L.marker([farm.latitude!, farm.longitude!], { icon })

      const popup = L.popup({ maxWidth: 280, className: 'farm-popup' }).setContent(`
        <div style="padding:4px">
          <div style="font-size:12px;color:#6B7280;margin-bottom:4px">${CATEGORY_ICONS[farm.category] || '🏡'} ${farm.category}${farm.is_bio ? ' · 🌿 Bio' : ''}</div>
          <div style="font-weight:700;font-size:15px;color:#111827;margin-bottom:4px">${farm.name}</div>
          <div style="font-size:12px;color:#6B7280;margin-bottom:6px">📍 ${farm.city}${farm.state ? ', ' + farm.state : ''}</div>
          ${farm.products.length > 0 ? `<div style="font-size:11px;color:#059669;margin-bottom:8px">${farm.products.slice(0, 4).join(' · ')}</div>` : ''}
          <a href="/dashboard/supply/farm/${farm.slug}"
             style="display:inline-block;background:#16A34A;color:white;font-size:12px;font-weight:600;padding:6px 12px;border-radius:8px;text-decoration:none">
            Details →
          </a>
        </div>
      `)

      marker.bindPopup(popup)
      marker.on('click', () => onSelectFarm(farm))
      markersRef.current!.addLayer(marker)
    })

    // Fit bounds
    if (withCoords.length > 0) {
      const bounds = L.latLngBounds(withCoords.map((f) => [f.latitude!, f.longitude!]))
      mapInstance.current.fitBounds(bounds, { padding: [40, 40], maxZoom: 10 })
    }
  }, [farms, onSelectFarm])

  // Highlight selected
  useEffect(() => {
    if (!mapInstance.current || !selectedFarm?.latitude || !selectedFarm?.longitude) return
    mapInstance.current.setView([selectedFarm.latitude, selectedFarm.longitude], 13, { animate: true })
  }, [selectedFarm])

  return (
    <div className="relative">
      <div ref={mapRef} className="w-full h-[500px] rounded-2xl border border-gray-200 shadow-sm z-0" />

      {/* Legend */}
      <div className="absolute bottom-4 left-4 z-[1000] bg-white/95 backdrop-blur-sm rounded-xl shadow-lg border border-gray-100 p-3">
        <p className="text-xs font-semibold text-gray-700 mb-2">Legende</p>
        <div className="space-y-1">
          {(Object.entries(CATEGORY_PIN_COLORS) as [string, string][]).map(([cat, color]) => (
            <div key={cat} className="flex items-center gap-2">
              <div
                className="w-3 h-3 rounded-full shrink-0"
                style={{ background: color }}
              />
              <span className="text-xs text-gray-600">{cat}</span>
            </div>
          ))}
          <div className="flex items-center gap-2 mt-1 pt-1 border-t border-gray-100">
            <div className="w-3 h-3 rounded-full bg-lime-500 border-2 border-lime-300 shrink-0" />
            <span className="text-xs text-gray-600">🌿 Bio-Betrieb</span>
          </div>
        </div>
      </div>

      {/* Count badge */}
      <div className="absolute top-4 right-4 z-[1000] bg-white/95 backdrop-blur-sm rounded-xl shadow border border-gray-100 px-3 py-2">
        <span className="text-xs font-semibold text-gray-700">
          📍 {farms.filter((f) => f.latitude && f.longitude).length} Betriebe auf Karte
        </span>
      </div>
    </div>
  )
}
