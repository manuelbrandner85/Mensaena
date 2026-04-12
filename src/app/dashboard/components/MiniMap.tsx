'use client'

import { useMemo } from 'react'
import dynamic from 'next/dynamic'
import Link from 'next/link'
import { MapPin, ArrowRight } from 'lucide-react'
import { categoryColors } from '@/lib/design-system/tokens'
import { Card } from '@/components/ui'
import type { NearbyPost } from '../types'

const MapContainer = dynamic(
  () => import('react-leaflet').then((m) => m.MapContainer),
  { ssr: false }
)
const TileLayer = dynamic(
  () => import('react-leaflet').then((m) => m.TileLayer),
  { ssr: false }
)
const CircleMarker = dynamic(
  () => import('react-leaflet').then((m) => m.CircleMarker),
  { ssr: false }
)
const Popup = dynamic(
  () => import('react-leaflet').then((m) => m.Popup),
  { ssr: false }
)

interface MiniMapProps {
  posts: NearbyPost[]
  userLat: number | null
  userLng: number | null
}

export default function MiniMap({ posts, userLat, userLng }: MiniMapProps) {
  const postsWithCoords = useMemo(
    () => posts.filter((p) => p.latitude && p.longitude),
    [posts]
  )

  if (!userLat || !userLng) {
    return (
      <Card variant="flat" padding="lg" className="bg-gray-50 text-center">
        <MapPin className="w-8 h-8 text-gray-300 mx-auto mb-2" />
        <p className="text-sm text-gray-500 mb-2">
          Standort einstellen für die Karten-Vorschau
        </p>
        <Link
          href="/dashboard/settings"
          className="text-sm text-primary-600 hover:text-primary-700 font-medium inline-flex items-center gap-1"
        >
          Einstellungen <ArrowRight className="w-3.5 h-3.5" />
        </Link>
      </Card>
    )
  }

  return (
    <div className="relative h-[200px] rounded-xl overflow-hidden border border-gray-100">
      <MapContainer
        center={[userLat, userLng]}
        zoom={13}
        scrollWheelZoom={false}
        dragging={true}
        zoomControl={false}
        attributionControl={false}
        className="h-full w-full z-0"
      >
        <TileLayer
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />

        {/* User position */}
        <CircleMarker
          center={[userLat, userLng]}
          radius={8}
          pathOptions={{ color: '#3b82f6', fillColor: '#3b82f6', fillOpacity: 0.8, weight: 2 }}
        >
          <Popup>Dein Standort</Popup>
        </CircleMarker>

        {/* Posts */}
        {postsWithCoords.map((p) => {
          const markerColor = categoryColors[p.type]?.dot ?? '#6b7280'
          return (
            <CircleMarker
              key={p.id}
              center={[p.latitude!, p.longitude!]}
              radius={6}
              pathOptions={{
                color: markerColor,
                fillColor: markerColor,
                fillOpacity: 0.7,
                weight: 1,
              }}
            >
              <Popup>
                <span className="text-xs font-medium">{p.title}</span>
              </Popup>
            </CircleMarker>
          )
        })}
      </MapContainer>

      {/* Link overlay */}
      <Link
        href="/dashboard/map"
        className="absolute bottom-3 right-3 bg-white/90 backdrop-blur-sm text-sm px-3 py-1.5 rounded-lg shadow-sm hover:bg-white transition-colors font-medium text-gray-700 z-10"
      >
        Vollständige Karte →
      </Link>

      {/* SR-only attribution */}
      <span className="sr-only">Map data © OpenStreetMap contributors</span>
    </div>
  )
}
