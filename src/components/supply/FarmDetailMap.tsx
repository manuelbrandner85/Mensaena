'use client'

import { useEffect, useRef } from 'react'

export default function FarmDetailMap({
  lat, lng, name
}: { lat: number; lng: number; name: string }) {
  const mapRef = useRef<HTMLDivElement>(null)
  const mapInstance = useRef<import('leaflet').Map | null>(null)

  useEffect(() => {
    if (!mapRef.current || mapInstance.current) return
    let mounted = true

    const init = async () => {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const L = (await import('leaflet')).default as any
      if (!mounted || !mapRef.current) return

      const map = L.map(mapRef.current, {
        center: [lat, lng],
        zoom: 14,
        zoomControl: false,
        dragging: false,
        scrollWheelZoom: false,
      })

      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap',
      }).addTo(map)

      const icon = L.divIcon({
        html: `<div style="width:40px;height:40px;background:#16A34A;border:3px solid white;border-radius:50% 50% 50% 0;transform:rotate(-45deg);box-shadow:0 2px 8px rgba(0,0,0,0.3);display:flex;align-items:center;justify-content:center;">
          <span style="transform:rotate(45deg);font-size:18px;">🏡</span>
        </div>`,
        className: '',
        iconSize: [40, 40],
        iconAnchor: [20, 40],
      })

      L.marker([lat, lng], { icon })
        .addTo(map)
        .bindPopup(`<b>${name}</b>`)
        .openPopup()

      mapInstance.current = map
    }
    init()

    return () => {
      mounted = false
      mapInstance.current?.remove()
      mapInstance.current = null
    }
  }, [lat, lng, name])

  return <div ref={mapRef} className="w-full h-48" />
}
