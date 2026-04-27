'use client'

import React from 'react'

interface FlyerDProps {
  flyerRef: React.RefObject<HTMLDivElement | null>
  qrDataUrl: string
  inviteUrl: string
}

const LEAF_SVG = (
  <svg width="54" height="54" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="1.3" strokeLinecap="round" strokeLinejoin="round">
    <path d="M12 22C6 22 2 18 2 12C2 6.5 6 2 12 2C18 2 22 6.5 22 11C22 16.5 18 22 12 22Z" />
    <path d="M12 22C10 22 8 18 8 12C8 6 10 2 12 2" />
    <path d="M2 12H22" />
  </svg>
)

export default function FlyerD({ flyerRef, qrDataUrl, inviteUrl }: FlyerDProps) {
  return (
    <div
      ref={flyerRef}
      style={{
        width: 1080,
        height: 1080,
        background: 'linear-gradient(148deg, #1EAAA6 0%, #147170 38%, #0d5755 68%, #0a3f3d 100%)',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif',
        color: 'white',
        position: 'relative',
        overflow: 'hidden',
        boxSizing: 'border-box',
      }}
    >
      {/* Background decorations */}
      <div style={{ position: 'absolute', top: -100, right: -100, width: 420, height: 420, borderRadius: '50%', background: 'rgba(255,255,255,0.05)' }} />
      <div style={{ position: 'absolute', bottom: -80, left: -80, width: 320, height: 320, borderRadius: '50%', background: 'rgba(255,255,255,0.06)' }} />
      <div style={{ position: 'absolute', top: 240, left: -60, width: 180, height: 180, borderRadius: '50%', background: 'rgba(255,255,255,0.03)' }} />
      <div style={{ position: 'absolute', bottom: 220, right: -40, width: 140, height: 140, borderRadius: '50%', background: 'rgba(255,255,255,0.04)' }} />

      {/* Logo section */}
      <div style={{ zIndex: 1, textAlign: 'center', marginBottom: 56 }}>
        <div style={{
          width: 100, height: 100,
          background: 'rgba(255,255,255,0.14)',
          borderRadius: 28,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          margin: '0 auto 24px',
          border: '2px solid rgba(255,255,255,0.22)',
        }}>
          {LEAF_SVG}
        </div>
        <div style={{ fontSize: 52, fontWeight: 900, letterSpacing: '-1.5px', lineHeight: 1 }}>Mensaena</div>
        <div style={{ fontSize: 16, opacity: 0.7, marginTop: 10, letterSpacing: 3.5, textTransform: 'uppercase', fontWeight: 500 }}>Nachbarschaftshilfe</div>
      </div>

      {/* Quote */}
      <div style={{ zIndex: 1, textAlign: 'center', marginBottom: 60, padding: '0 80px' }}>
        <div style={{
          fontSize: 34, fontWeight: 700, lineHeight: 1.32, letterSpacing: '-0.3px',
          textShadow: '0 2px 20px rgba(0,0,0,0.15)',
        }}>
          „Ich bin auf Mensaena –<br />bist du es auch?"
        </div>
        <div style={{ fontSize: 16, opacity: 0.65, marginTop: 18, lineHeight: 1.65 }}>
          Hilfe anbieten · Teilen · Vernetzen · Gemeinsam stark
        </div>
      </div>

      {/* QR Code */}
      <div style={{ zIndex: 1, textAlign: 'center' }}>
        <div style={{
          background: 'white',
          borderRadius: 28,
          padding: 20,
          display: 'inline-block',
          boxShadow: '0 20px 60px rgba(0,0,0,0.28)',
        }}>
          {qrDataUrl
            ? <img src={qrDataUrl} width={220} height={220} alt="QR-Code" style={{ display: 'block' }} />
            : <div style={{ width: 220, height: 220, background: '#e5e7eb', borderRadius: 12 }} />}
        </div>
        <div style={{ marginTop: 18, fontSize: 15, opacity: 0.62 }}>Kamera auf QR-Code richten</div>
      </div>

      {/* Bottom bar */}
      <div style={{
        position: 'absolute', bottom: 0, left: 0, right: 0,
        background: 'rgba(0,0,0,0.22)',
        padding: '18px 40px',
        textAlign: 'center',
        fontSize: 17, fontWeight: 600, letterSpacing: 0.5,
        borderTop: '1px solid rgba(255,255,255,0.1)',
      }}>
        www.mensaena.de · Kostenlos &amp; sicher
      </div>
    </div>
  )
}
