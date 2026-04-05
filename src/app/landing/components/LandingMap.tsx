'use client'

import { useEffect, useState } from 'react'
import dynamic from 'next/dynamic'
import Link from 'next/link'
import LandingSection from './LandingSection'
import { useScrollAnimation } from '../hooks/useScrollAnimation'

// Dynamically import Leaflet components (no SSR)
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

const markers = [
  { lat: 52.52, lng: 13.405, color: '#1EAAA6', label: 'Berlin' },
  { lat: 48.1351, lng: 11.582, color: '#4F6D8A', label: 'München' },
  { lat: 53.5511, lng: 9.9937, color: '#38a169', label: 'Hamburg' },
  { lat: 50.9375, lng: 6.9603, color: '#1EAAA6', label: 'Köln' },
  { lat: 50.1109, lng: 8.6821, color: '#4F6D8A', label: 'Frankfurt' },
  { lat: 48.7758, lng: 9.1829, color: '#38a169', label: 'Stuttgart' },
]

export default function LandingMap() {
  const { ref: sectionRef, isVisible } = useScrollAnimation()
  const [showMap, setShowMap] = useState(false)

  // Only mount map when section is visible (lazy load)
  useEffect(() => {
    if (isVisible) setShowMap(true)
  }, [isVisible])

  return (
    <LandingSection id="map" background="gray">
      <h2
        id="map-heading"
        className="text-3xl md:text-4xl font-bold text-center text-gray-900"
      >
        Schau was in deiner Nähe passiert
      </h2>
      <p className="text-gray-600 text-center mt-4">
        Die Karte zeigt dir Hilfsangebote und -gesuche in Echtzeit
      </p>

      <div ref={sectionRef} className="mt-10 relative rounded-2xl overflow-hidden">
        {showMap ? (
          <div className="h-[400px] md:h-[450px]" aria-label="Kartenvorschau mit Beispiel-Standorten in Deutschland">
            <MapContainer
              center={[51.1657, 10.4515]}
              zoom={6}
              scrollWheelZoom={false}
              dragging={false}
              zoomControl={false}
              attributionControl={false}
              className="h-full w-full z-0"
            >
              <TileLayer
                url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
              />
              {markers.map((m, i) => (
                <CircleMarker
                  key={i}
                  center={[m.lat, m.lng]}
                  radius={10}
                  pathOptions={{
                    fillColor: m.color,
                    fillOpacity: 0.7,
                    color: m.color,
                    weight: 2,
                  }}
                />
              ))}
            </MapContainer>
          </div>
        ) : (
          <div className="h-[400px] md:h-[450px] bg-warm-100 rounded-2xl animate-pulse" aria-label="Karte wird geladen" />
        )}

        {/* CTA Overlay */}
        <div className="absolute bottom-0 inset-x-0 bg-gradient-to-t from-white via-white/80 to-transparent h-48 flex items-end justify-center pb-8 z-10">
          <Link
            href="/auth?mode=register"
            className="btn-primary px-6 py-3 shadow-lg min-h-[44px]"
          >
            <span aria-hidden="true">🗺️</span>
            Registrieren und Karte freischalten
          </Link>
        </div>
      </div>
    </LandingSection>
  )
}
