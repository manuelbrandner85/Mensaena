'use client'

import React from 'react'

interface FlyerHProps {
  flyerRef: React.RefObject<HTMLDivElement | null>
  qrDataUrl: string
  inviteUrl: string
  userName: string
  city: string
}

const LEAF_SVG = (
  <svg width="42" height="42" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round">
    <path d="M12 22C6 22 2 18 2 12C2 6.5 6 2 12 2C18 2 22 6.5 22 11C22 16.5 18 22 12 22Z" />
    <path d="M12 22C10 22 8 18 8 12C8 6 10 2 12 2" />
    <path d="M2 12H22" />
  </svg>
)

export default function FlyerH({ flyerRef, qrDataUrl, inviteUrl, userName, city }: FlyerHProps) {
  return (
    <div
      ref={flyerRef}
      style={{
        width: 1080,
        height: 1080,
        background: 'linear-gradient(148deg, #0d5755 0%, #147170 30%, #1EAAA6 65%, #38c4c0 100%)',
        display: 'flex',
        flexDirection: 'column',
        fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif',
        color: 'white',
        position: 'relative',
        overflow: 'hidden',
        boxSizing: 'border-box',
      }}
    >
      {/* Decorative shapes */}
      <div style={{ position: 'absolute', top: -120, left: -80, width: 500, height: 500, borderRadius: '50%', background: 'rgba(255,255,255,0.06)' }} />
      <div style={{ position: 'absolute', bottom: -80, right: -80, width: 380, height: 380, borderRadius: '50%', background: 'rgba(0,0,0,0.08)' }} />
      <div style={{ position: 'absolute', top: 300, right: -40, width: 200, height: 200, borderRadius: '50%', background: 'rgba(255,255,255,0.04)' }} />

      {/* Top bar */}
      <div style={{
        padding: '40px 50px',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        zIndex: 1,
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
          <div style={{
            width: 52, height: 52,
            background: 'rgba(255,255,255,0.15)',
            borderRadius: 14,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            border: '1px solid rgba(255,255,255,0.22)',
          }}>
            {LEAF_SVG}
          </div>
          <div>
            <div style={{ fontSize: 22, fontWeight: 900, letterSpacing: '-0.3px' }}>Mensaena</div>
            <div style={{ fontSize: 11, opacity: 0.72, letterSpacing: 2, textTransform: 'uppercase', marginTop: 2 }}>Nachbarschaftshilfe</div>
          </div>
        </div>

        <div style={{
          background: 'rgba(255,255,255,0.15)',
          borderRadius: 12,
          padding: '8px 18px',
          fontSize: 13,
          fontWeight: 600,
          border: '1px solid rgba(255,255,255,0.22)',
        }}>
          🏅 Nachbarschafts-Botschafter:in
        </div>
      </div>

      {/* Main content */}
      <div style={{
        flex: 1,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '0 60px',
        zIndex: 1,
        textAlign: 'center',
      }}>
        <div style={{
          fontSize: 18,
          opacity: 0.78,
          fontWeight: 500,
          letterSpacing: 1,
          marginBottom: 16,
          textTransform: 'uppercase',
        }}>
          {userName} aus {city || 'deiner Nachbarschaft'}
        </div>

        <div style={{
          fontSize: 54,
          fontWeight: 900,
          lineHeight: 1.12,
          letterSpacing: '-1.5px',
          marginBottom: 24,
          textShadow: '0 4px 24px rgba(0,0,0,0.15)',
        }}>
          Ich bin Nachbarschafts-<br />Botschafter:in!
        </div>

        <div style={{
          fontSize: 20,
          opacity: 0.78,
          lineHeight: 1.55,
          maxWidth: 580,
          marginBottom: 48,
        }}>
          Gemeinsam gestalten wir eine starke Gemeinschaft –<br />
          werde Teil von Mensaena.
        </div>

        {/* QR row */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 32 }}>
          <div style={{
            background: 'white',
            borderRadius: 22,
            padding: 16,
            boxShadow: '0 16px 50px rgba(0,0,0,0.22)',
          }}>
            {qrDataUrl
              ? <img src={qrDataUrl} width={180} height={180} alt="QR" style={{ display: 'block' }} />
              : <div style={{ width: 180, height: 180, background: '#e5e7eb', borderRadius: 10 }} />}
          </div>

          <div style={{ textAlign: 'left' }}>
            <div style={{ fontSize: 22, fontWeight: 800, marginBottom: 8 }}>Jetzt kostenlos<br />registrieren</div>
            <div style={{ fontSize: 14, opacity: 0.7, lineHeight: 1.6 }}>QR-Code scannen oder<br />www.mensaena.de besuchen</div>
            <div style={{
              display: 'inline-block',
              marginTop: 14,
              background: 'rgba(255,255,255,0.15)',
              borderRadius: 10,
              padding: '8px 16px',
              fontSize: 13,
              fontWeight: 600,
              border: '1px solid rgba(255,255,255,0.25)',
            }}>
              Kostenlos · Sicher · Lokal
            </div>
          </div>
        </div>
      </div>

      {/* Bottom bar */}
      <div style={{
        background: 'rgba(0,0,0,0.18)',
        borderTop: '1px solid rgba(255,255,255,0.1)',
        padding: '16px 50px',
        textAlign: 'center',
        fontSize: 15,
        fontWeight: 600,
        letterSpacing: 0.5,
        opacity: 0.85,
        zIndex: 1,
      }}>
        www.mensaena.de · Kostenlos &amp; sicher · DSGVO-konform
      </div>
    </div>
  )
}
