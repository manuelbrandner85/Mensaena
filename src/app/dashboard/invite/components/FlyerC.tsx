'use client'

import React from 'react'

interface FlyerCProps {
  flyerRef: React.RefObject<HTMLDivElement | null>
  qrDataUrl: string
  inviteUrl: string
  userName?: string
}

const LEAF_SVG = (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
    <path d="M12 22C6 22 2 18 2 12C2 6.5 6 2 12 2C18 2 22 6.5 22 11C22 16.5 18 22 12 22Z" />
    <path d="M12 22C10 22 8 18 8 12C8 6 10 2 12 2" />
    <path d="M2 12H22" />
  </svg>
)

const GRID_ITEMS = [
  ['🤝', 'Helfen', 'Hilfe anbieten & suchen'],
  ['🛒', 'Teilen', 'Dinge tauschen & schenken'],
  ['📅', 'Treffen', 'Events & Gemeinschaft'],
  ['🚨', 'Warnungen', 'Lokale Alerts in Echtzeit'],
  ['💬', 'Chatten', 'Direkt mit Nachbarn'],
  ['🗺️', 'Entdecken', 'Alles auf der Karte'],
]

const TAGS = ['Kostenlos', 'DSGVO-konform', 'Offen für alle']

export default function FlyerC({ flyerRef, qrDataUrl, inviteUrl, userName }: FlyerCProps) {
  return (
    <div
      ref={flyerRef}
      style={{
        width: 794,
        height: 559,
        background: 'white',
        display: 'flex',
        fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif',
        overflow: 'hidden',
        boxSizing: 'border-box',
      }}
    >
      {/* Left teal panel */}
      <div style={{
        width: 270,
        background: 'linear-gradient(160deg, #1EAAA6 0%, #0d5755 100%)',
        padding: '36px 28px',
        color: 'white',
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'space-between',
        position: 'relative',
        overflow: 'hidden',
        flexShrink: 0,
        boxSizing: 'border-box',
      }}>
        <div style={{ position: 'absolute', bottom: -30, right: -30, width: 120, height: 120, borderRadius: '50%', background: 'rgba(255,255,255,0.07)' }} />
        <div style={{ position: 'absolute', top: -20, left: -20, width: 80, height: 80, borderRadius: '50%', background: 'rgba(255,255,255,0.05)' }} />

        <div style={{ position: 'relative', zIndex: 1 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 22 }}>
            <div style={{
              width: 38, height: 38,
              background: 'rgba(255,255,255,0.18)',
              borderRadius: 10,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              border: '1px solid rgba(255,255,255,0.28)',
              flexShrink: 0,
            }}>
              {LEAF_SVG}
            </div>
            <div>
              <div style={{ fontSize: 18, fontWeight: 800, lineHeight: 1 }}>Mensaena</div>
              <div style={{ fontSize: 9, opacity: 0.78, letterSpacing: 1.5, marginTop: 3, textTransform: 'uppercase' }}>Nachbarschaftshilfe</div>
            </div>
          </div>

          <div style={{ fontSize: 22, fontWeight: 800, lineHeight: 1.25, letterSpacing: '-0.3px' }}>
            Gemeinsam<br />füreinander<br />da sein.
          </div>

          <div style={{ fontSize: 12, opacity: 0.76, marginTop: 12, lineHeight: 1.6 }}>
            Mensaena vernetzt Nachbarn –<br />
            kostenlos, sicher und lokal.
          </div>
        </div>

        <div style={{ position: 'relative', zIndex: 1 }}>
          {userName && (
            <div style={{
              background: 'rgba(255,255,255,0.14)',
              borderRadius: 10,
              padding: '10px 14px',
              border: '1px solid rgba(255,255,255,0.24)',
              marginBottom: 14,
            }}>
              <div style={{ fontSize: 10, opacity: 0.76, marginBottom: 3 }}>Eingeladen von</div>
              <div style={{ fontWeight: 700, fontSize: 14 }}>{userName}</div>
            </div>
          )}
          <div style={{ fontSize: 11, opacity: 0.68 }}>www.mensaena.de</div>
        </div>
      </div>

      {/* Right content */}
      <div style={{
        flex: 1,
        padding: '32px 32px 28px 28px',
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'space-between',
        boxSizing: 'border-box',
      }}>
        <div>
          <div style={{ fontSize: 11, color: '#6b7280', fontWeight: 600, marginBottom: 16, letterSpacing: 1.2, textTransform: 'uppercase' }}>
            Was du bei Mensaena findest
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 12 }}>
            {GRID_ITEMS.map(([icon, title, desc]) => (
              <div key={title} style={{
                background: '#f9fafb',
                borderRadius: 12,
                padding: '12px 14px',
                border: '1px solid #f0f0f0',
              }}>
                <div style={{ fontSize: 20, marginBottom: 6 }}>{icon}</div>
                <div style={{ fontSize: 13, fontWeight: 700, color: '#1f2937' }}>{title}</div>
                <div style={{ fontSize: 10, color: '#9ca3af', marginTop: 2, lineHeight: 1.4 }}>{desc}</div>
              </div>
            ))}
          </div>
        </div>

        {/* QR + URL row */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 18, paddingTop: 18, borderTop: '1px solid #f0f0f0' }}>
          <div style={{
            background: 'white',
            borderRadius: 12,
            padding: 8,
            border: '2px solid #a3eae8',
            flexShrink: 0,
          }}>
            {qrDataUrl
              ? <img src={qrDataUrl} width={76} height={76} alt="QR-Code" style={{ display: 'block' }} />
              : <div style={{ width: 76, height: 76, background: '#f0f0f0', borderRadius: 6 }} />}
          </div>
          <div>
            <div style={{ fontSize: 16, fontWeight: 700, color: '#1EAAA6' }}>Jetzt kostenlos registrieren</div>
            <div style={{ fontSize: 12, color: '#6b7280', marginTop: 4 }}>
              QR-Code scannen oder <strong style={{ color: '#147170' }}>www.mensaena.de</strong> besuchen
            </div>
            <div style={{ display: 'flex', gap: 6, marginTop: 8, flexWrap: 'wrap' as const }}>
              {TAGS.map(tag => (
                <span key={tag} style={{
                  fontSize: 10, fontWeight: 600, color: '#147170',
                  background: '#effcfb',
                  padding: '3px 8px', borderRadius: 6,
                  border: '1px solid #a3eae8',
                }}>
                  {tag}
                </span>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
