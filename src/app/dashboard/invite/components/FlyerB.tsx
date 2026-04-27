'use client'

import React from 'react'

interface FlyerBProps {
  flyerRef: React.RefObject<HTMLDivElement | null>
  qrDataUrl: string
  inviteUrl: string
}

const LEAF_SVG = (
  <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
    <path d="M12 22C6 22 2 18 2 12C2 6.5 6 2 12 2C18 2 22 6.5 22 11C22 16.5 18 22 12 22Z" />
    <path d="M12 22C10 22 8 18 8 12C8 6 10 2 12 2" />
    <path d="M2 12H22" />
  </svg>
)

const FEATURES = [
  ['🤝', 'Hilfe anbieten & suchen', 'Finde Nachbarn die helfen oder Hilfe brauchen'],
  ['🛒', 'Nachbarschafts-Marktplatz', 'Gebrauchtes teilen, schenken, tauschen'],
  ['📅', 'Gemeinschaftskalender', 'Lokale Veranstaltungen & Treffen entdecken'],
  ['🚨', 'Krisenwarnungen', 'Aktuelle Meldungen aus deiner Umgebung'],
  ['💬', 'Nachbarschaftschat', 'Direkt mit Nachbarn kommunizieren'],
  ['🗺️', 'Interaktive Karte', 'Alle Angebote & Gesuche auf einen Blick'],
  ['🔒', 'Kostenlos & sicher', 'Keine Kosten, DSGVO-konform, offen für alle'],
]

const NUM_STRIPS = 8

export default function FlyerB({ flyerRef, qrDataUrl, inviteUrl }: FlyerBProps) {
  return (
    <div
      ref={flyerRef}
      style={{
        width: 794,
        height: 1123,
        background: 'white',
        display: 'flex',
        flexDirection: 'column',
        fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif',
        overflow: 'hidden',
        boxSizing: 'border-box',
      }}
    >
      {/* Header */}
      <div style={{
        background: 'linear-gradient(135deg, #1EAAA6 0%, #147170 100%)',
        padding: '40px 50px 36px',
        color: 'white',
        position: 'relative',
        overflow: 'hidden',
        flexShrink: 0,
      }}>
        <div style={{ position: 'absolute', top: -40, right: -40, width: 220, height: 220, borderRadius: '50%', background: 'rgba(255,255,255,0.06)' }} />
        <div style={{ position: 'absolute', bottom: -30, left: 200, width: 140, height: 140, borderRadius: '50%', background: 'rgba(255,255,255,0.05)' }} />

        <div style={{ display: 'flex', alignItems: 'center', gap: 16, marginBottom: 18, position: 'relative', zIndex: 1 }}>
          <div style={{
            width: 52, height: 52,
            background: 'rgba(255,255,255,0.18)',
            borderRadius: 14,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            border: '1px solid rgba(255,255,255,0.28)',
            flexShrink: 0,
          }}>
            {LEAF_SVG}
          </div>
          <div>
            <div style={{ fontSize: 26, fontWeight: 800, letterSpacing: '-0.3px', lineHeight: 1 }}>Mensaena</div>
            <div style={{ fontSize: 13, opacity: 0.82, marginTop: 3, fontWeight: 500 }}>Nachbarschaftshilfe · www.mensaena.de</div>
          </div>
        </div>
        <div style={{ fontSize: 34, fontWeight: 800, lineHeight: 1.22, letterSpacing: '-0.5px', position: 'relative', zIndex: 1 }}>
          Hilf &amp; werde geholfen –<br />direkt in deiner Nachbarschaft.
        </div>
      </div>

      {/* Body */}
      <div style={{ flex: 1, padding: '38px 50px', display: 'flex', gap: 40, minHeight: 0 }}>
        {/* Features list */}
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 17, fontWeight: 700, color: '#111827', marginBottom: 22 }}>
            Was bietet Mensaena?
          </div>
          {FEATURES.map(([icon, title, desc]) => (
            <div key={title} style={{ display: 'flex', gap: 14, marginBottom: 20 }}>
              <div style={{ fontSize: 22, flexShrink: 0, marginTop: 1 }}>{icon}</div>
              <div>
                <div style={{ fontSize: 15, fontWeight: 600, color: '#1f2937' }}>{title}</div>
                <div style={{ fontSize: 12, color: '#6b7280', marginTop: 2, lineHeight: 1.45 }}>{desc}</div>
              </div>
            </div>
          ))}
        </div>

        {/* QR + CTA panel */}
        <div style={{ width: 230, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 18, flexShrink: 0 }}>
          <div style={{
            background: '#effcfb',
            borderRadius: 20,
            padding: 20,
            border: '2px solid #a3eae8',
            textAlign: 'center',
            width: '100%',
            boxSizing: 'border-box',
          }}>
            <div style={{ fontSize: 14, fontWeight: 700, color: '#147170', marginBottom: 14 }}>
              Jetzt kostenlos registrieren
            </div>
            {qrDataUrl
              ? <img src={qrDataUrl} width={160} height={160} alt="QR-Code" style={{ display: 'block', borderRadius: 8, margin: '0 auto' }} />
              : <div style={{ width: 160, height: 160, background: '#e5e7eb', borderRadius: 8, margin: '0 auto' }} />}
            <div style={{ fontSize: 11, color: '#6b7280', marginTop: 12 }}>Kamera auf QR-Code richten</div>
          </div>

          <div style={{
            background: '#1EAAA6',
            color: 'white',
            borderRadius: 12,
            padding: '13px 20px',
            textAlign: 'center',
            fontWeight: 700,
            fontSize: 15,
            width: '100%',
            boxSizing: 'border-box',
          }}>
            www.mensaena.de
          </div>

          <div style={{ fontSize: 11, color: '#9ca3af', textAlign: 'center', lineHeight: 1.6 }}>
            Kostenlos · DSGVO-konform<br />Für alle Nachbarn offen
          </div>
        </div>
      </div>

      {/* Tear strips */}
      <div style={{ borderTop: '2px dashed #d1d5db', display: 'flex', height: 76, flexShrink: 0 }}>
        {Array.from({ length: NUM_STRIPS }).map((_, i) => (
          <div
            key={i}
            style={{
              flex: 1,
              borderRight: i < NUM_STRIPS - 1 ? '1px dashed #d1d5db' : undefined,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              padding: '4px 2px',
            }}
          >
            <div style={{
              fontSize: 9,
              color: '#147170',
              fontWeight: 600,
              writingMode: 'vertical-rl' as const,
              textOrientation: 'mixed' as const,
              transform: 'rotate(180deg)',
              letterSpacing: 0.5,
              whiteSpace: 'nowrap',
            }}>
              mensaena.de
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
