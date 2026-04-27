'use client'

import React from 'react'

interface FlyerAProps {
  flyerRef: React.RefObject<HTMLDivElement | null>
  qrDataUrl: string
  inviteUrl: string
}

const LEAF_SVG = (
  <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
    <path d="M12 22C6 22 2 18 2 12C2 6.5 6 2 12 2C18 2 22 6.5 22 11C22 16.5 18 22 12 22Z" />
    <path d="M12 22C10 22 8 18 8 12C8 6 10 2 12 2" />
    <path d="M2 12H22" />
  </svg>
)

export default function FlyerA({ flyerRef, qrDataUrl, inviteUrl }: FlyerAProps) {
  return (
    <div
      ref={flyerRef}
      style={{
        width: 397,
        height: 559,
        background: 'linear-gradient(160deg, #1EAAA6 0%, #147170 55%, #0d5755 100%)',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'space-between',
        padding: '36px 32px',
        fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif',
        color: 'white',
        position: 'relative',
        overflow: 'hidden',
        boxSizing: 'border-box',
      }}
    >
      {/* Decorative circles */}
      <div style={{ position: 'absolute', top: -60, right: -60, width: 200, height: 200, borderRadius: '50%', background: 'rgba(255,255,255,0.06)', pointerEvents: 'none' }} />
      <div style={{ position: 'absolute', bottom: -40, left: -40, width: 160, height: 160, borderRadius: '50%', background: 'rgba(255,255,255,0.05)', pointerEvents: 'none' }} />

      {/* Logo */}
      <div style={{ textAlign: 'center', zIndex: 1 }}>
        <div style={{
          width: 60, height: 60,
          background: 'rgba(255,255,255,0.15)',
          borderRadius: 16,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          margin: '0 auto 14px',
          border: '1px solid rgba(255,255,255,0.22)',
        }}>
          {LEAF_SVG}
        </div>
        <div style={{ fontSize: 26, fontWeight: 800, letterSpacing: '-0.5px', lineHeight: 1 }}>Mensaena</div>
        <div style={{ fontSize: 10, fontWeight: 600, opacity: 0.75, marginTop: 5, letterSpacing: 2, textTransform: 'uppercase' }}>Nachbarschaftshilfe</div>
      </div>

      {/* Main claim */}
      <div style={{ textAlign: 'center', zIndex: 1 }}>
        <div style={{ fontSize: 19, fontWeight: 700, lineHeight: 1.35, marginBottom: 10 }}>
          Deine Nachbarschaft<br />hilft sich gegenseitig
        </div>
        <div style={{ fontSize: 12, opacity: 0.72, lineHeight: 1.55 }}>
          Hilfe anbieten &amp; finden · Teilen · Vernetzen
        </div>
      </div>

      {/* QR Code */}
      <div style={{ zIndex: 1, textAlign: 'center' }}>
        <div style={{
          background: 'white',
          borderRadius: 16,
          padding: 12,
          display: 'inline-block',
          boxShadow: '0 8px 32px rgba(0,0,0,0.22)',
        }}>
          {qrDataUrl
            ? <img src={qrDataUrl} width={120} height={120} alt="QR-Code" style={{ display: 'block' }} />
            : <div style={{ width: 120, height: 120, background: '#e5e7eb', borderRadius: 8 }} />}
        </div>
        <div style={{ marginTop: 10, fontSize: 11, opacity: 0.7 }}>Kamera auf QR-Code richten</div>
      </div>

      {/* URL pill */}
      <div style={{
        background: 'rgba(255,255,255,0.14)',
        borderRadius: 10,
        padding: '9px 22px',
        fontSize: 13, fontWeight: 600,
        border: '1px solid rgba(255,255,255,0.24)',
        zIndex: 1,
      }}>
        www.mensaena.de · kostenlos &amp; sicher
      </div>
    </div>
  )
}
