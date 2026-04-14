'use client'

import { useEffect, useState } from 'react'
import dynamic from 'next/dynamic'
import Link from 'next/link'
import { ArrowRight } from 'lucide-react'
import LandingSection from './LandingSection'
import { useScrollAnimation } from '../hooks/useScrollAnimation'

// Dynamically import Leaflet components (no SSR)
const MapContainer = dynamic(
  () => import('react-leaflet').then((m) => m.MapContainer),
  { ssr: false },
)
const TileLayer = dynamic(
  () => import('react-leaflet').then((m) => m.TileLayer),
  { ssr: false },
)
const CircleMarker = dynamic(
  () => import('react-leaflet').then((m) => m.CircleMarker),
  { ssr: false },
)

const markers = [
  { lat: 52.52,   lng: 13.405,  label: 'Berlin' },
  { lat: 48.1351, lng: 11.582,  label: 'München' },
  { lat: 53.5511, lng: 9.9937,  label: 'Hamburg' },
  { lat: 50.9375, lng: 6.9603,  label: 'Köln' },
  { lat: 50.1109, lng: 8.6821,  label: 'Frankfurt' },
  { lat: 48.7758, lng: 9.1829,  label: 'Stuttgart' },
]

export default function LandingMap() {
  const { ref: sectionRef, isVisible } = useScrollAnimation()
  const [showMap, setShowMap] = useState(false)

  useEffect(() => {
    if (isVisible) setShowMap(true)
  }, [isVisible])

  return (
    <LandingSection
      id="map"
      background="stone"
      index="07"
      label="Live in der Fläche"
      title={
        <>
          Echte <span className="text-accent">Nachbarschaften</span>,
          <br />
          verbunden in Echtzeit.
        </>
      }
    >
      <div
        ref={sectionRef}
        className="reveal reveal-delay-2 relative overflow-hidden rounded-3xl border border-stone-300 bg-paper"
      >
        {showMap ? (
          <div className="h-[460px] md:h-[560px]" aria-label="Kartenvorschau">
            <MapContainer
              center={[51.1657, 10.4515]}
              zoom={6}
              scrollWheelZoom={false}
              dragging={false}
              zoomControl={false}
              attributionControl={false}
              className="h-full w-full z-0"
              style={{ background: '#FAFAF7' }}
            >
              <TileLayer
                url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
              />
              {markers.map((m, i) => (
                <CircleMarker
                  key={i}
                  center={[m.lat, m.lng]}
                  radius={11}
                  pathOptions={{
                    fillColor: '#1EAAA6',
                    fillOpacity: 0.85,
                    color: '#147170',
                    weight: 2,
                  }}
                />
              ))}
            </MapContainer>
          </div>
        ) : (
          <div className="h-[460px] md:h-[560px] bg-stone-100 animate-pulse" />
        )}

        {/* CTA overlay — thin bottom bar instead of heavy gradient */}
        <div className="absolute bottom-0 inset-x-0 bg-gradient-to-t from-paper via-paper/90 to-transparent h-32 flex items-end px-6 md:px-10 pb-8 z-10">
          <Link
            href="/auth?mode=register"
            className="group inline-flex items-center gap-3 bg-ink-800 hover:bg-ink-700 text-paper px-6 py-3 rounded-full text-sm font-medium tracking-wide transition-colors duration-300"
          >
            Registrieren und Karte freischalten
            <ArrowRight className="w-4 h-4 transition-transform duration-300 group-hover:translate-x-1" />
          </Link>
        </div>
      </div>
    </LandingSection>
  )
}
