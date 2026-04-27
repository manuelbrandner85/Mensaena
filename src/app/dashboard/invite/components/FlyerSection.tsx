'use client'

import React, { useRef, useState, useEffect, useCallback } from 'react'
import { Download, FileText, X, Eye, FileDown } from 'lucide-react'
import Card from '@/components/ui/Card'
import SectionHeader from '@/components/ui/SectionHeader'
import FlyerA from './FlyerA'
import FlyerB from './FlyerB'
import FlyerC from './FlyerC'
import FlyerD from './FlyerD'
import FlyerH from './FlyerH'

interface FlyerSectionProps {
  inviteUrl: string
  userName: string
  city?: string
}

interface FlyerMeta {
  key: string
  title: string
  description: string
  naturalWidth: number
  naturalHeight: number
  previewScale: number
  // jsPDF page dimensions in mm
  pdfWidth: number
  pdfHeight: number
  showPng: boolean
}

const FLYERS: FlyerMeta[] = [
  {
    key: 'a',
    title: 'Briefkasten-Karte',
    description: 'A6 · für Briefkästen',
    naturalWidth: 397,
    naturalHeight: 559,
    previewScale: 0.38,
    pdfWidth: 105,
    pdfHeight: 148,
    showPng: false,
  },
  {
    key: 'b',
    title: 'Schwarzes Brett',
    description: 'A4 · mit Abreiß-Streifen',
    naturalWidth: 794,
    naturalHeight: 1123,
    previewScale: 0.205,
    pdfWidth: 210,
    pdfHeight: 297,
    showPng: false,
  },
  {
    key: 'c',
    title: 'Gemeinschafts-Flyer',
    description: 'A5 quer · für Veranstaltungen',
    naturalWidth: 794,
    naturalHeight: 559,
    previewScale: 0.29,
    pdfWidth: 210,
    pdfHeight: 148,
    showPng: false,
  },
  {
    key: 'd',
    title: 'Digital-Share',
    description: '1080 × 1080 px · Social Media',
    naturalWidth: 1080,
    naturalHeight: 1080,
    previewScale: 0.21,
    pdfWidth: 285,
    pdfHeight: 285,
    showPng: true,
  },
  {
    key: 'h',
    title: 'Botschafter-Story',
    description: '1080 × 1080 px · WhatsApp Status',
    naturalWidth: 1080,
    naturalHeight: 1080,
    previewScale: 0.21,
    pdfWidth: 285,
    pdfHeight: 285,
    showPng: true,
  },
]

async function capturePng(el: HTMLElement, pixelRatio = 2): Promise<string> {
  const { toPng } = await import('html-to-image')
  return toPng(el, { pixelRatio, cacheBust: true })
}

async function downloadPdf(el: HTMLElement, flyer: FlyerMeta) {
  const png = await capturePng(el, 2)
  const { default: jsPDF } = await import('jspdf')
  const pdf = new jsPDF({
    unit: 'mm',
    format: [flyer.pdfWidth, flyer.pdfHeight],
    orientation: flyer.pdfWidth > flyer.pdfHeight ? 'landscape' : 'portrait',
  })
  pdf.addImage(png, 'PNG', 0, 0, flyer.pdfWidth, flyer.pdfHeight)
  pdf.save(`mensaena-flyer-${flyer.key}.pdf`)
}

async function downloadPng(el: HTMLElement, key: string) {
  const png = await capturePng(el, 3)
  const a = document.createElement('a')
  a.href = png
  a.download = `mensaena-flyer-${key}.png`
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
}

// ── Flyer renderer (reused for both preview grid and modal) ─────────────────

function FlyerRenderer({
  flyerKey,
  flyerRef,
  qrDataUrl,
  inviteUrl,
  userName,
  city,
}: {
  flyerKey: string
  flyerRef: React.RefObject<HTMLDivElement | null>
  qrDataUrl: string
  inviteUrl: string
  userName: string
  city: string
}) {
  if (flyerKey === 'a') return <FlyerA flyerRef={flyerRef} qrDataUrl={qrDataUrl} inviteUrl={inviteUrl} />
  if (flyerKey === 'b') return <FlyerB flyerRef={flyerRef} qrDataUrl={qrDataUrl} inviteUrl={inviteUrl} />
  if (flyerKey === 'c') return <FlyerC flyerRef={flyerRef} qrDataUrl={qrDataUrl} inviteUrl={inviteUrl} userName={userName} />
  if (flyerKey === 'h') return <FlyerH flyerRef={flyerRef} qrDataUrl={qrDataUrl} inviteUrl={inviteUrl} userName={userName} city={city} />
  return <FlyerD flyerRef={flyerRef} qrDataUrl={qrDataUrl} inviteUrl={inviteUrl} />
}

// ── Full-screen flyer modal ──────────────────────────────────────────────────

function FlyerModal({
  flyer,
  flyerRef,
  qrDataUrl,
  inviteUrl,
  userName,
  city,
  busy,
  onClose,
  onDownloadPdf,
  onDownloadPng,
}: {
  flyer: FlyerMeta
  flyerRef: React.RefObject<HTMLDivElement | null>
  qrDataUrl: string
  inviteUrl: string
  userName: string
  city: string
  busy: string | null
  onClose: () => void
  onDownloadPdf: () => void
  onDownloadPng: () => void
}) {
  const [scale, setScale] = useState(1)

  useEffect(() => {
    const calc = () => {
      const maxW = window.innerWidth * 0.88
      const maxH = window.innerHeight * 0.72
      const s = Math.min(maxW / flyer.naturalWidth, maxH / flyer.naturalHeight, 1)
      setScale(s)
    }
    calc()
    window.addEventListener('resize', calc)
    return () => window.removeEventListener('resize', calc)
  }, [flyer.naturalWidth, flyer.naturalHeight])

  // Esc closes modal
  useEffect(() => {
    const handler = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose() }
    document.addEventListener('keydown', handler)
    document.body.style.overflow = 'hidden'
    return () => {
      document.removeEventListener('keydown', handler)
      document.body.style.overflow = ''
    }
  }, [onClose])

  const scaledW = Math.round(flyer.naturalWidth * scale)
  const scaledH = Math.round(flyer.naturalHeight * scale)
  const isPdfBusy = busy === `pdf-${flyer.key}`
  const isPngBusy = busy === `png-${flyer.key}`

  return (
    <div
      className="fixed inset-0 z-50 flex flex-col items-center justify-center bg-black/75 p-4"
      onClick={onClose}
    >
      {/* Close button */}
      <button
        className="absolute top-4 right-4 w-10 h-10 flex items-center justify-center rounded-full bg-white/10 hover:bg-white/20 text-white transition-colors"
        onClick={onClose}
        aria-label="Schließen"
      >
        <X className="w-5 h-5" />
      </button>

      {/* Title */}
      <p className="text-white/70 text-sm font-medium mb-3">{flyer.title}</p>

      {/* Flyer preview (scaled) */}
      <div
        style={{ width: scaledW, height: scaledH, position: 'relative', overflow: 'hidden' }}
        onClick={(e) => e.stopPropagation()}
      >
        <div
          style={{
            transform: `scale(${scale})`,
            transformOrigin: 'top left',
            position: 'absolute',
            top: 0,
            left: 0,
            pointerEvents: 'none',
          }}
        >
          <FlyerRenderer
            flyerKey={flyer.key}
            flyerRef={flyerRef}
            qrDataUrl={qrDataUrl}
            inviteUrl={inviteUrl}
            userName={userName}
            city={city}
          />
        </div>
      </div>

      {/* Download actions */}
      <div className="flex gap-3 mt-5" onClick={(e) => e.stopPropagation()}>
        <button
          onClick={onDownloadPdf}
          disabled={busy !== null}
          className="flex items-center gap-2 px-5 py-2.5 rounded-xl bg-primary-500 hover:bg-primary-600 text-white text-sm font-semibold transition-colors disabled:opacity-50"
        >
          <FileDown className="w-4 h-4" />
          {isPdfBusy ? 'Erstelle PDF…' : 'PDF herunterladen'}
        </button>

        {flyer.showPng && (
          <button
            onClick={onDownloadPng}
            disabled={busy !== null}
            className="flex items-center gap-2 px-5 py-2.5 rounded-xl bg-white/10 hover:bg-white/20 text-white text-sm font-semibold transition-colors disabled:opacity-50"
          >
            <Download className="w-4 h-4" />
            {isPngBusy ? 'Erstelle PNG…' : 'Als PNG'}
          </button>
        )}
      </div>
    </div>
  )
}

// ── Main component ───────────────────────────────────────────────────────────

export default function FlyerSection({ inviteUrl, userName, city = '' }: FlyerSectionProps) {
  const [qrDataUrl, setQrDataUrl] = useState('')
  const [busy, setBusy] = useState<string | null>(null)
  const [openKey, setOpenKey] = useState<string | null>(null)

  const flyerARef = useRef<HTMLDivElement | null>(null)
  const flyerBRef = useRef<HTMLDivElement | null>(null)
  const flyerCRef = useRef<HTMLDivElement | null>(null)
  const flyerDRef = useRef<HTMLDivElement | null>(null)
  const flyerHRef = useRef<HTMLDivElement | null>(null)

  const refMap: Record<string, React.RefObject<HTMLDivElement | null>> = {
    a: flyerARef,
    b: flyerBRef,
    c: flyerCRef,
    d: flyerDRef,
    h: flyerHRef,
  }

  useEffect(() => {
    if (!inviteUrl) return
    let cancelled = false
    import('qrcode').then((mod) => {
      mod.default.toDataURL(inviteUrl, {
        width: 400,
        margin: 1,
        color: { dark: '#147170', light: '#ffffff' },
      }).then((url: string) => {
        if (!cancelled) setQrDataUrl(url)
      })
    })
    return () => { cancelled = true }
  }, [inviteUrl])

  const handleDownloadPdf = useCallback(async (key: string) => {
    const ref = refMap[key]
    const flyer = FLYERS.find(f => f.key === key)
    if (!ref.current || !flyer) return
    setBusy(`pdf-${key}`)
    try {
      await downloadPdf(ref.current, flyer)
    } finally {
      setBusy(null)
    }
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  const handleDownloadPng = useCallback(async (key: string) => {
    const ref = refMap[key]
    if (!ref.current) return
    setBusy(`png-${key}`)
    try {
      await downloadPng(ref.current, key)
    } finally {
      setBusy(null)
    }
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  const activeFlyer = openKey ? FLYERS.find(f => f.key === openKey) : null

  return (
    <>
      <Card variant="default">
        <SectionHeader
          title="Flyer herunterladen"
          subtitle="Klicke auf einen Flyer zum Anzeigen – alle enthalten deinen persönlichen QR-Code"
          icon={<FileText className="w-4 h-4" />}
          className="mb-5"
        />

        <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
          {FLYERS.map((flyer) => {
            const previewW = Math.round(flyer.naturalWidth * flyer.previewScale)
            const previewH = Math.round(flyer.naturalHeight * flyer.previewScale)
            const ref = refMap[flyer.key]

            return (
              <div key={flyer.key} className="flex flex-col gap-2">
                {/* Clickable preview thumbnail */}
                <button
                  className="relative border border-stone-200 rounded-xl overflow-hidden bg-stone-50 group focus:outline-none focus-visible:ring-2 focus-visible:ring-primary-400 cursor-pointer"
                  style={{ width: previewW, height: previewH }}
                  onClick={() => setOpenKey(flyer.key)}
                  aria-label={`${flyer.title} öffnen`}
                >
                  <div
                    style={{
                      transform: `scale(${flyer.previewScale})`,
                      transformOrigin: 'top left',
                      position: 'absolute',
                      top: 0, left: 0,
                      pointerEvents: 'none',
                      userSelect: 'none',
                    }}
                  >
                    <FlyerRenderer
                      flyerKey={flyer.key}
                      flyerRef={ref}
                      qrDataUrl={qrDataUrl}
                      inviteUrl={inviteUrl}
                      userName={userName}
                      city={city}
                    />
                  </div>
                  {/* Hover overlay */}
                  <div className="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-colors flex items-center justify-center">
                    <div className="opacity-0 group-hover:opacity-100 transition-opacity bg-white rounded-full p-2 shadow-lg">
                      <Eye className="w-4 h-4 text-ink-700" />
                    </div>
                  </div>
                </button>

                {/* Info */}
                <div>
                  <p className="text-sm font-semibold text-ink-800">{flyer.title}</p>
                  <p className="text-xs text-ink-400">{flyer.description}</p>
                </div>

                {/* Quick download */}
                <button
                  onClick={() => handleDownloadPdf(flyer.key)}
                  disabled={busy !== null}
                  className="w-full flex items-center justify-center gap-1.5 px-3 py-2 rounded-lg bg-primary-50 hover:bg-primary-100 border border-primary-200 text-primary-700 text-xs font-medium transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <FileDown className="w-3.5 h-3.5" />
                  {busy === `pdf-${flyer.key}` ? 'Lädt…' : 'PDF herunterladen'}
                </button>

                {flyer.showPng && (
                  <button
                    onClick={() => handleDownloadPng(flyer.key)}
                    disabled={busy !== null}
                    className="w-full flex items-center justify-center gap-1.5 px-3 py-2 rounded-lg bg-stone-50 hover:bg-stone-100 border border-stone-200 text-ink-600 text-xs font-medium transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    <Download className="w-3.5 h-3.5" />
                    {busy === `png-${flyer.key}` ? 'Lädt…' : 'Als PNG'}
                  </button>
                )}
              </div>
            )
          })}
        </div>

        <p className="text-xs text-ink-400 mt-4 text-center">
          Alle Flyer enthalten deinen persönlichen QR-Code. Jede neue Registrierung über deinen Link zählt.
        </p>
      </Card>

      {/* Full-screen modal */}
      {openKey && activeFlyer && (
        <FlyerModal
          flyer={activeFlyer}
          flyerRef={refMap[openKey]}
          qrDataUrl={qrDataUrl}
          inviteUrl={inviteUrl}
          userName={userName}
          city={city}
          busy={busy}
          onClose={() => setOpenKey(null)}
          onDownloadPdf={() => handleDownloadPdf(openKey)}
          onDownloadPng={() => handleDownloadPng(openKey)}
        />
      )}
    </>
  )
}
