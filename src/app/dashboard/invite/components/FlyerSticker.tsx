'use client'

import React from 'react'

interface FlyerStickerProps {
  flyerRef: React.RefObject<HTMLDivElement | null>
  qrDataUrl: string
}

const COLS = 3
const ROWS = 4
const TOTAL = COLS * ROWS

const LEAF_SVG = (
  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
    <path d="M12 22C6 22 2 18 2 12C2 6.5 6 2 12 2C18 2 22 6.5 22 11C22 16.5 18 22 12 22Z" />
    <path d="M12 22C10 22 8 18 8 12C8 6 10 2 12 2" />
    <path d="M2 12H22" />
  </svg>
)

export default function FlyerSticker({ flyerRef, qrDataUrl }: FlyerStickerProps) {
  return (
    <div
      ref={flyerRef}
      style={{
        width: 794,
        height: 1123,
        background: 'white',
        padding: 24,
        boxSizing: 'border-box',
        fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif',
      }}
    >
      <div style={{
        display: 'grid',
        gridTemplateColumns: `repeat(${COLS}, 1fr)`,
        gridTemplateRows: `repeat(${ROWS}, 1fr)`,
        gap: 8,
        height: '100%',
      }}>
        {Array.from({ length: TOTAL }).map((_, i) => (
          <div
            key={i}
            style={{
              border: '1px dashed #cbd5e1',
              borderRadius: 12,
              padding: 12,
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'space-between',
              background: 'linear-gradient(160deg, #ffffff 0%, #f0fdfa 100%)',
              overflow: 'hidden',
            }}
          >
            {/* Logo header */}
            <div style={{
              display: 'flex',
              alignItems: 'center',
              gap: 6,
              alignSelf: 'stretch',
              justifyContent: 'center',
            }}>
              <div style={{
                width: 22,
                height: 22,
                background: 'linear-gradient(135deg, #1EAAA6, #147170)',
                borderRadius: 6,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                flexShrink: 0,
              }}>
                {LEAF_SVG}
              </div>
              <div style={{ fontSize: 13, fontWeight: 800, color: '#147170', letterSpacing: '-0.2px' }}>
                Mensaena
              </div>
            </div>

            {/* QR code */}
            <div style={{
              background: 'white',
              padding: 4,
              borderRadius: 6,
              border: '1px solid #e0f2f1',
            }}>
              {qrDataUrl
                ? <img src={qrDataUrl} width={88} height={88} alt="" style={{ display: 'block' }} />
                : <div style={{ width: 88, height: 88, background: '#f0f0f0', borderRadius: 4 }} />}
            </div>

            {/* URL */}
            <div style={{
              fontSize: 8,
              fontWeight: 600,
              color: '#147170',
              textAlign: 'center',
              letterSpacing: 0.3,
            }}>
              www.mensaena.de
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
