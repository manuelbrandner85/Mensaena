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
      {/* ── Cinematic ambient depth behind the map frame ── */}
      <div
        className="absolute pointer-events-none rounded-full"
        style={{
          top: '20%',
          left: '-10%',
          width: '40vw',
          height: '40vw',
          background: 'radial-gradient(circle, rgba(30,170,166,0.10) 0%, transparent 70%)',
          filter: 'blur(80px)',
          animation: 'ambientBreath2 24s ease-in-out infinite',
          zIndex: 0,
        }}
        aria-hidden="true"
      />
      <div
        className="absolute pointer-events-none rounded-full"
        style={{
          top: '40%',
          right: '-8%',
          width: '32vw',
          height: '32vw',
          background: 'radial-gradient(circle, rgba(79,109,138,0.08) 0%, transparent 70%)',
          filter: 'blur(70px)',
          animation: 'ambientBreath3 20s ease-in-out 4s infinite',
          zIndex: 0,
        }}
        aria-hidden="true"
      />

      {/* ── Map frame — premium card depth ── */}
      <div
        ref={sectionRef}
        className="reveal reveal-delay-2 relative card-depth overflow-hidden rounded-3xl"
      >
        {/* ── Inner radial vignette overlay (top edge) ── */}
        <div
          className="absolute inset-x-0 top-0 h-24 z-10 pointer-events-none"
          style={{
            background: 'linear-gradient(to bottom, rgba(255,255,255,0.4) 0%, transparent 100%)',
          }}
          aria-hidden="true"
        />

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

        {/* ── Cinematic CTA overlay — refined glass-edged bar ── */}
        <div
          className="absolute bottom-0 inset-x-0 z-10 flex items-end px-6 md:px-10 pb-8 pt-24"
          style={{
            background:
              'linear-gradient(to top, rgba(250,250,247,1) 30%, rgba(250,250,247,0.92) 60%, transparent 100%)',
          }}
        >
          {/* Top edge light line */}
          <div
            className="absolute top-0 left-[10%] right-[10%] h-px pointer-events-none"
            style={{
              background:
                'linear-gradient(90deg, transparent 0%, rgba(30,170,166,0.18) 30%, rgba(30,170,166,0.35) 50%, rgba(30,170,166,0.18) 70%, transparent 100%)',
            }}
            aria-hidden="true"
          />
          <Link
            href="/auth?mode=register"
            className="cta-cinema-ink group inline-flex items-center gap-3 text-paper px-7 py-3.5 rounded-full text-sm font-medium tracking-wide"
          >
            Registrieren und Karte freischalten
            <ArrowRight className="w-4 h-4 transition-transform duration-300 group-hover:translate-x-1" />
          </Link>
        </div>
      </div>
    </LandingSection>
  )
}
