'use client'

import { useEffect, useState } from 'react'
import { MapContainer, TileLayer, Marker, Popup, useMap } from 'react-leaflet'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'
import { useRouter } from 'next/navigation'
import type { EventItem, AttendeeStatus } from '../hooks/useEvents'
import { EVENT_CATEGORIES, formatEventDateShort } from '../hooks/useEvents'

// Fix Leaflet default icon issue in Next.js
delete (L.Icon.Default.prototype as Record<string, unknown>)._getIconUrl
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon-2x.png',
  iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png',
})

const CATEGORY_COLORS: Record<string, string> = {
  purple: '#8b5cf6', blue: '#3b82f6', emerald: '#10b981', orange: '#f97316',
  amber: '#f59e0b', pink: '#ec4899', cyan: '#06b6d4', rose: '#f43f5e',
  green: '#22c55e', gray: '#6b7280',
}

function createColorIcon(color: string): L.DivIcon {
  return L.divIcon({
    html: `<div style="background:${color};width:28px;height:28px;border-radius:50% 50% 50% 0;border:3px solid white;box-shadow:0 2px 6px rgba(0,0,0,0.3);transform:rotate(-45deg);margin-top:-14px;margin-left:-14px"></div>`,
    className: '',
    iconSize: [28, 28],
    iconAnchor: [14, 28],
    popupAnchor: [0, -28],
  })
}

function FitBounds({ events }: { events: EventItem[] }) {
  const map = useMap()
  useEffect(() => {
    if (events.length === 0) return
    const bounds = L.latLngBounds(
      events.map((e) => [e.latitude!, e.longitude!] as [number, number]),
    )
    map.fitBounds(bounds, { padding: [40, 40], maxZoom: 14 })
  }, [events, map])
  return null
}

interface EventMapInnerProps {
  events: EventItem[]
  onAttend: (eventId: string, status: AttendeeStatus) => Promise<boolean>
  onRemove: (eventId: string) => void
}

export default function EventMapInner({ events }: EventMapInnerProps) {
  const router = useRouter()
  const [userPos, setUserPos] = useState<[number, number] | null>(null)

  useEffect(() => {
    navigator.geolocation?.getCurrentPosition(
      (pos) => setUserPos([pos.coords.latitude, pos.coords.longitude]),
      () => {},
      { timeout: 5000 },
    )
  }, [])

  const center: [number, number] = userPos || [51.1657, 10.4515] // Germany center

  return (
    <div className="rounded-xl overflow-hidden border border-gray-200" style={{ height: 'calc(100vh - 280px)', minHeight: 400 }}>
      <MapContainer
        center={center}
        zoom={userPos ? 12 : 6}
        className="h-full w-full z-0"
        scrollWheelZoom
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OSM</a>'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        <FitBounds events={events} />

        {events.map((event) => {
          const catInfo = EVENT_CATEGORIES[event.category]
          const color = CATEGORY_COLORS[catInfo?.color || 'gray'] || '#6b7280'
          return (
            <Marker
              key={event.id}
              position={[event.latitude!, event.longitude!]}
              icon={createColorIcon(color)}
            >
              <Popup minWidth={200} maxWidth={280}>
                <div className="p-1">
                  <div className="flex items-center gap-1 mb-1">
                    <span className="text-xs">{catInfo?.emoji}</span>
                    <span className="text-xs font-medium text-gray-500">{catInfo?.label}</span>
                  </div>
                  <h4 className="font-semibold text-sm text-gray-900 mb-1">{event.title}</h4>
                  <p className="text-xs text-gray-600 mb-1">
                    {formatEventDateShort(event.start_date, event.is_all_day)}
                  </p>
                  {event.location_name && (
                    <p className="text-xs text-gray-500 mb-2">{event.location_name}</p>
                  )}
                  <button
                    onClick={() => router.push(`/dashboard/events/${event.id}`)}
                    className="text-xs font-medium text-emerald-600 hover:text-emerald-700"
                  >
                    Details anzeigen &rarr;
                  </button>
                </div>
              </Popup>
            </Marker>
          )
        })}

        {/* User position */}
        {userPos && (
          <Marker
            position={userPos}
            icon={L.divIcon({
              html: '<div style="background:#3b82f6;width:14px;height:14px;border-radius:50%;border:3px solid white;box-shadow:0 0 0 2px #3b82f6;margin-top:-7px;margin-left:-7px"></div>',
              className: '',
              iconSize: [14, 14],
            })}
          />
        )}
      </MapContainer>
    </div>
  )
}
