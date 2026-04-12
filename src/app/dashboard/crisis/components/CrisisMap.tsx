'use client'

import { useEffect, useState, useRef } from 'react'
import { MapPin, Loader2 } from 'lucide-react'
import { cn } from '@/lib/utils'
import { URGENCY_CONFIG, CRISIS_CATEGORY_CONFIG, type Crisis } from '../types'

interface Props {
  crises: Crisis[]
  loading?: boolean
  className?: string
  height?: string
  onCrisisClick?: (crisis: Crisis) => void
}

export default function CrisisMap({ crises, loading, className, height = 'h-[400px]', onCrisisClick }: Props) {
  const mapRef = useRef<HTMLDivElement>(null)
  const mapInstanceRef = useRef<any>(null)
  const [mapReady, setMapReady] = useState(false)

  useEffect(() => {
    if (typeof window === 'undefined' || !mapRef.current) return
    if (mapInstanceRef.current) return

    let cancelled = false

    const initMap = async () => {
      const L = (await import('leaflet')).default
      await import('leaflet/dist/leaflet.css')

      if (cancelled || !mapRef.current) return

      const map = L.map(mapRef.current, {
        center: [47.5, 13.5], // Austria center
        zoom: 7,
        zoomControl: true,
        attributionControl: true,
      })

      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; OpenStreetMap',
        maxZoom: 18,
      }).addTo(map)

      mapInstanceRef.current = map
      setMapReady(true)
    }

    initMap()
    return () => {
      cancelled = true
      if (mapInstanceRef.current) {
        mapInstanceRef.current.remove()
        mapInstanceRef.current = null
      }
    }
  }, [])

  // Update markers when crises change
  useEffect(() => {
    if (!mapReady || !mapInstanceRef.current) return

    const L = require('leaflet')
    const map = mapInstanceRef.current
    const markers: any[] = []

    const geolocatedCrises = crises.filter(c => c.latitude && c.longitude)

    geolocatedCrises.forEach(crisis => {
      const urgCfg = URGENCY_CONFIG[crisis.urgency]
      const catCfg = CRISIS_CATEGORY_CONFIG[crisis.category]
      const isActive = crisis.status === 'active' || crisis.status === 'in_progress'

      const markerColor = crisis.urgency === 'critical' ? '#dc2626'
        : crisis.urgency === 'high' ? '#ea580c'
        : crisis.urgency === 'medium' ? '#ca8a04'
        : '#2563eb'

      const icon = L.divIcon({
        className: 'custom-crisis-marker',
        html: `<div style="
          background: ${markerColor};
          width: 28px; height: 28px;
          border-radius: 50%;
          border: 3px solid white;
          box-shadow: 0 2px 8px rgba(0,0,0,0.3);
          display: flex; align-items: center; justify-content: center;
          font-size: 14px;
          ${isActive && crisis.urgency === 'critical' ? 'animation: pulse 2s infinite;' : ''}
        ">${catCfg.emoji}</div>`,
        iconSize: [28, 28],
        iconAnchor: [14, 14],
      })

      const marker = L.marker([crisis.latitude!, crisis.longitude!], { icon })
        .addTo(map)
        .bindPopup(`
          <div style="max-width:200px">
            <p style="font-weight:bold;font-size:13px;margin:0 0 4px">${catCfg.emoji} ${crisis.title}</p>
            <p style="font-size:11px;color:#666;margin:0 0 4px">${urgCfg.label} &middot; ${crisis.helper_count}/${crisis.needed_helpers} Helfer</p>
            ${crisis.location_text ? `<p style="font-size:11px;color:#888;margin:0">📍 ${crisis.location_text}</p>` : ''}
          </div>
        `)

      if (onCrisisClick) {
        marker.on('click', () => onCrisisClick(crisis))
      }

      markers.push(marker)
    })

    // Fit bounds
    if (geolocatedCrises.length > 0) {
      const bounds = L.latLngBounds(geolocatedCrises.map(c => [c.latitude!, c.longitude!]))
      map.fitBounds(bounds, { padding: [30, 30], maxZoom: 12 })
    }

    return () => {
      markers.forEach(m => m.remove())
    }
  }, [crises, mapReady, onCrisisClick])

  return (
    <div className={cn('relative rounded-2xl overflow-hidden border border-gray-200', height, className)}>
      {(loading || !mapReady) && (
        <div className="absolute inset-0 bg-gray-100 flex items-center justify-center z-20">
          <div className="text-center">
            <Loader2 className="w-6 h-6 text-gray-400 animate-spin mx-auto mb-2" />
            <p className="text-xs text-gray-500">Karte wird geladen...</p>
          </div>
        </div>
      )}
      <div ref={mapRef} className="w-full h-full" aria-label="Krisenkarte" />
      <style jsx global>{`
        @keyframes pulse {
          0%, 100% { transform: scale(1); opacity: 1; }
          50% { transform: scale(1.2); opacity: 0.8; }
        }
      `}</style>
    </div>
  )
}
