'use client'

import { useEffect, useRef } from 'react'
import type { Organization } from './page'
import { getCategoryConfig, COUNTRY_FLAGS } from './page'

// Leaflet CSS wird im Layout eingebunden; hier nur dynamisch importieren
interface MapViewProps {
  orgs: Organization[]
  selectedOrg: Organization | null
  onOrgSelect: (org: Organization) => void
}

// Kategorie → Leaflet-Marker-Farbe
const CATEGORY_COLORS: Record<string, string> = {
  tierheim:         '#EA580C', // orange-600
  tierschutz:       '#EF4444', // red-500
  suppenkueche:     '#CA8A04', // yellow-600
  obdachlosenhilfe: '#2563EB', // blue-600
  tafel:            '#16A34A', // green-600
  kleiderkammer:    '#9333EA', // purple-600
  sozialkaufhaus:   '#4F46E5', // indigo-600
  krisentelefon:    '#E11D48', // rose-600
  notschlafstelle:  '#475569', // slate-600
  jugend:           '#0284C7', // sky-600
  senioren:         '#EC4899', // pink-500
  fluechtlingshilfe:'#0D9488', // teal-600
  allgemein:        '#4B5563', // gray-600
}

function getColor(category: string): string {
  return CATEGORY_COLORS[category] ?? '#4B5563'
}

function createSvgIcon(color: string, selected: boolean) {
  const size = selected ? 36 : 28
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 30" width="${size}" height="${size * 1.25}">
    <path d="M12 0C5.373 0 0 5.373 0 12c0 9 12 18 12 18S24 21 24 12C24 5.373 18.627 0 12 0z"
      fill="${color}" stroke="white" stroke-width="${selected ? 2 : 1.5}" opacity="${selected ? 1 : 0.9}"/>
    <circle cx="12" cy="12" r="5" fill="white" opacity="0.9"/>
  </svg>`
  return svg
}

export default function MapView({ orgs, selectedOrg, onOrgSelect }: MapViewProps) {
  const mapRef     = useRef<HTMLDivElement>(null)
  const leafletMap = useRef<any>(null)
  const markersRef = useRef<Map<string, any>>(new Map())

  useEffect(() => {
    if (!mapRef.current) return

    // Leaflet lazy load
    import('leaflet').then(L => {
      // Fix default icon path
      delete (L.Icon.Default.prototype as any)._getIconUrl
      L.Icon.Default.mergeOptions({
        iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
        iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
        shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
      })

      if (!leafletMap.current) {
        // Karte erstellen – Zentrum über DE/AT/CH
        const map = L.map(mapRef.current!, {
          center: [48.5, 12.5],
          zoom: 6,
          zoomControl: true,
          scrollWheelZoom: true,
        })

        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
          attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
          maxZoom: 19,
        }).addTo(map)

        leafletMap.current = map
      }

      const map = leafletMap.current

      // Alte Marker entfernen
      markersRef.current.forEach(m => map.removeLayer(m))
      markersRef.current.clear()

      // Neue Marker hinzufügen
      orgs.forEach(org => {
        if (!org.latitude || !org.longitude) return

        const isSelected = selectedOrg?.id === org.id
        const color = getColor(org.category)
        const svg = createSvgIcon(color, isSelected)

        const icon = L.divIcon({
          html: svg,
          className: '',
          iconSize: [isSelected ? 36 : 28, isSelected ? 45 : 35],
          iconAnchor: [isSelected ? 18 : 14, isSelected ? 45 : 35],
          popupAnchor: [0, isSelected ? -45 : -35],
        })

        const cat = getCategoryConfig(org.category)

        const popupHtml = `
          <div style="min-width:220px;max-width:280px;font-family:system-ui,sans-serif">
            <div style="display:flex;align-items:center;gap:8px;margin-bottom:8px">
              <span style="background:${color};color:white;border-radius:8px;padding:4px 8px;font-size:11px;font-weight:600">
                ${cat.label}
              </span>
              <span style="font-size:16px">${COUNTRY_FLAGS[org.country] ?? ''}</span>
            </div>
            <h3 style="font-weight:700;font-size:14px;margin:0 0 4px 0;color:#111">${org.name}</h3>
            ${org.description ? `<p style="font-size:12px;color:#555;margin:0 0 8px 0;line-height:1.4">${org.description.substring(0, 120)}${org.description.length > 120 ? '…' : ''}</p>` : ''}
            <div style="font-size:12px;color:#666;display:flex;flex-direction:column;gap:4px">
              ${org.address ? `<span>📍 ${org.address}, ${org.zip_code ?? ''} ${org.city}</span>` : `<span>📍 ${org.city}</span>`}
              ${org.phone ? `<a href="tel:${org.phone.replace(/\s/g,'')}" style="color:#0D9488;font-weight:600">📞 ${org.phone}</a>` : ''}
              ${org.opening_hours ? `<span>🕒 ${org.opening_hours}</span>` : ''}
            </div>
            <div style="margin-top:10px;display:flex;gap:8px;flex-wrap:wrap">
              ${org.website ? `<a href="${org.website}" target="_blank" rel="noopener" style="font-size:11px;background:#f3f4f6;color:#374151;padding:4px 10px;border-radius:20px;text-decoration:none;display:inline-flex;align-items:center;gap:4px">🌐 Website</a>` : ''}
              <a href="https://www.google.com/maps?q=${org.latitude},${org.longitude}" target="_blank" rel="noopener" style="font-size:11px;background:#e0f2fe;color:#0369a1;padding:4px 10px;border-radius:20px;text-decoration:none;display:inline-flex;align-items:center;gap:4px">🗺️ Google Maps</a>
            </div>
          </div>
        `

        const marker = L.marker([org.latitude, org.longitude], { icon })
          .bindPopup(popupHtml, { maxWidth: 300 })
          .addTo(map)

        marker.on('click', () => {
          onOrgSelect(org)
        })

        markersRef.current.set(org.id, marker)
      })

      // Zu ausgewählter Org zoomen
      if (selectedOrg?.latitude && selectedOrg?.longitude) {
        const marker = markersRef.current.get(selectedOrg.id)
        map.setView([selectedOrg.latitude, selectedOrg.longitude], 14, { animate: true })
        if (marker) marker.openPopup()
      } else if (orgs.length > 0) {
        // Bounds aller Marker
        const points = orgs
          .filter(o => o.latitude && o.longitude)
          .map(o => [o.latitude!, o.longitude!] as [number, number])
        if (points.length > 0) {
          try {
            map.fitBounds(points, { padding: [40, 40], maxZoom: 10 })
          } catch {}
        }
      }
    })

    return () => {
      // Nicht unmounten – Karte bleibt erhalten
    }
  }, [orgs, selectedOrg])

  // Aufräumen wenn Komponente unmountet
  useEffect(() => {
    return () => {
      if (leafletMap.current) {
        leafletMap.current.remove()
        leafletMap.current = null
      }
    }
  }, [])

  return (
    <>
      <link
        rel="stylesheet"
        href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"
      />
      <div
        ref={mapRef}
        style={{ width: '100%', height: '100%', background: '#e5e7eb' }}
      />
    </>
  )
}
