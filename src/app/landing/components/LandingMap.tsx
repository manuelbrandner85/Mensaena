'use client'

import { useEffect, useState } from 'react'
import dynamic from 'next/dynamic'
import Link from 'next/link'
import { ArrowRight } from 'lucide-react'
import CinemaSection from '@/components/cinema/ui/CinemaSection'
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
  { lat: 51.2277, lng: 6.7735,  label: 'Düsseldorf' },
  { lat: 51.3397, lng: 12.3731, label: 'Leipzig' },
  { lat: 49.4521, lng: 11.0767, label: 'Nürnberg' },
  { lat: 51.4556, lng: 7.0116,  label: 'Essen' },
  { lat: 51.4818, lng: 7.2197,  label: 'Dortmund' },
  { lat: 53.0793, lng: 8.8017,  label: 'Bremen' },
]

export default function LandingMap() {
  const { ref: sectionRef, isVisible } = useScrollAnimation()
  const [showMap, setShowMap] = useState(false)

  useEffect(() => {
    if (isVisible) setShowMap(true)
  }, [isVisible])

  return (
    <CinemaSection
      id="map"
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
          background: 'radial-gradient(circle, rgba(199,147,99,0.12) 0%, transparent 70%)',
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
          background: 'radial-gradient(circle, rgba(125,211,252,0.10) 0%, transparent 70%)',
          filter: 'blur(70px)',
          animation: 'ambientBreath3 20s ease-in-out 4s infinite',
          zIndex: 0,
        }}
        aria-hidden="true"
      />

      {/* ── Map frame — premium cinema card with amber edge glow ── */}
      <div
        ref={sectionRef}
        className="reveal reveal-delay-2 relative overflow-hidden rounded-3xl border border-white/8"
        style={{
          background: 'linear-gradient(180deg, rgba(15,22,40,0.6) 0%, rgba(10,15,28,0.85) 100%)',
          boxShadow:
            '0 1px 0 rgba(199,147,99,0.08) inset, 0 16px 48px rgba(0,0,0,0.55), 0 32px 96px rgba(0,0,0,0.40), 0 0 80px rgba(199,147,99,0.06)',
        }}
      >
        {showMap ? (
          <div className="h-[460px] md:h-[560px] relative" aria-label="Kartenvorschau">
            <MapContainer
              center={[51.1657, 10.4515]}
              zoom={6}
              scrollWheelZoom={false}
              dragging={false}
              zoomControl={false}
              attributionControl={false}
              className="h-full w-full z-0"
              style={{ background: '#0A0F1C' }}
            >
              {/* CartoDB Dark Matter — cinema-perfect dark basemap */}
              <TileLayer
                url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
                attribution='&copy; OpenStreetMap &copy; CARTO'
                subdomains="abcd"
                maxZoom={19}
              />
              {markers.map((m, i) => (
                <CircleMarker
                  key={i}
                  center={[m.lat, m.lng]}
                  radius={9}
                  pathOptions={{
                    fillColor: '#c79363',
                    fillOpacity: 0.92,
                    color: '#FEF3C7',
                    weight: 2,
                    className: 'cinema-marker-pulse',
                  }}
                />
              ))}
            </MapContainer>

            {/* ── Radial vignette over map (cinema framing) ── */}
            <div
              className="absolute inset-0 pointer-events-none z-[400]"
              aria-hidden="true"
              style={{
                background:
                  'radial-gradient(ellipse at 50% 50%, transparent 50%, rgba(10,15,28,0.55) 100%)',
              }}
            />
            {/* ── Drifting lantern glow particles ── */}
            <div className="absolute inset-0 pointer-events-none overflow-hidden z-[401]" aria-hidden>
              {[
                { top: '18%', left: '22%', size: 180, delay: '0s'   },
                { top: '32%', left: '68%', size: 160, delay: '2s'   },
                { top: '62%', left: '38%', size: 220, delay: '1s'   },
                { top: '70%', left: '78%', size: 140, delay: '3s'   },
                { top: '48%', left: '52%', size: 280, delay: '4.5s' },
              ].map((l, i) => (
                <div
                  key={i}
                  className="absolute rounded-full"
                  style={{
                    top: l.top,
                    left: l.left,
                    width: l.size,
                    height: l.size,
                    background: 'radial-gradient(circle, rgba(199,147,99,0.10) 0%, transparent 70%)',
                    animation: `lanternDrift 14s ease-in-out ${l.delay} infinite`,
                    filter: 'blur(2px)',
                    transform: 'translate(-50%, -50%)',
                  }}
                />
              ))}
            </div>
          </div>
        ) : (
          <div className="h-[460px] md:h-[560px] animate-pulse" style={{ background: 'rgba(15,22,40,0.6)' }} />
        )}

        {/* ── Cinematic CTA overlay — dark glass with amber edge ── */}
        <div
          className="absolute bottom-0 inset-x-0 z-[500] flex items-center justify-center px-6 md:px-10 pb-8 pt-24"
          style={{
            background:
              'linear-gradient(to top, rgba(10,15,28,0.95) 35%, rgba(10,15,28,0.75) 65%, transparent 100%)',
          }}
        >
          {/* Top edge amber light line */}
          <div
            className="absolute top-0 left-[10%] right-[10%] h-px pointer-events-none"
            style={{
              background:
                'linear-gradient(90deg, transparent 0%, rgba(199,147,99,0.20) 30%, rgba(199,147,99,0.50) 50%, rgba(199,147,99,0.20) 70%, transparent 100%)',
            }}
            aria-hidden="true"
          />
          <Link
            href="/auth?mode=register"
            className="glow-btn-cinema-primary group inline-flex items-center gap-3 px-7 py-3.5 rounded-full text-sm font-medium tracking-wide"
          >
            Registrieren und Karte freischalten
            <ArrowRight className="w-4 h-4 transition-transform duration-300 group-hover:translate-x-1" />
          </Link>
        </div>
      </div>
    </CinemaSection>
  )
}
