'use client'

import React, { useRef, useState, useEffect, useCallback } from 'react'
import toast from 'react-hot-toast'
import { Download, FileText, X, Eye, FileDown, QrCode } from 'lucide-react'
import Card from '@/components/ui/Card'
import SectionHeader from '@/components/ui/SectionHeader'
import FlyerA from './FlyerA'
import FlyerB from './FlyerB'
import FlyerC from './FlyerC'
import FlyerD from './FlyerD'
import FlyerH from './FlyerH'
import FlyerSticker from './FlyerSticker'

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
  pdfWidth: number
  pdfHeight: number
  showPng: boolean
}

const FLYERS: FlyerMeta[] = [
  { key: 'a', title: 'Briefkasten-Karte',  description: 'A6 · für Briefkästen',         naturalWidth: 397,  naturalHeight: 559,  previewScale: 0.38,  pdfWidth: 105, pdfHeight: 148, showPng: false },
  { key: 'b', title: 'Schwarzes Brett',    description: 'A4 · mit Abreiß-Streifen',     naturalWidth: 794,  naturalHeight: 1123, previewScale: 0.205, pdfWidth: 210, pdfHeight: 297, showPng: false },
  { key: 'c', title: 'Gemeinschafts-Flyer', description: 'A5 quer · für Veranstaltungen', naturalWidth: 794,  naturalHeight: 559,  previewScale: 0.29,  pdfWidth: 210, pdfHeight: 148, showPng: false },
  { key: 'd', title: 'Digital-Share',      description: '1080 × 1080 · Social Media',    naturalWidth: 1080, naturalHeight: 1080, previewScale: 0.21,  pdfWidth: 285, pdfHeight: 285, showPng: true  },
  { key: 'h', title: 'Botschafter-Story',  description: '1080 × 1080 · WhatsApp Status', naturalWidth: 1080, naturalHeight: 1080, previewScale: 0.21,  pdfWidth: 285, pdfHeight: 285, showPng: true  },
  { key: 's', title: 'Aufkleber-Bogen',    description: 'A4 · 12 QR-Aufkleber zum Ausschneiden', naturalWidth: 794, naturalHeight: 1123, previewScale: 0.205, pdfWidth: 210, pdfHeight: 297, showPng: false },
]

// ── Download helpers ─────────────────────────────────────────────────────────

async function shareOrDownloadBlob(blob: Blob, filename: string, mime: string) {
  // Try Web Share API first (works on iOS/Android Safari/Chrome including Capacitor)
  if (typeof navigator !== 'undefined' && typeof File !== 'undefined' && (navigator as Navigator).canShare) {
    try {
      const file = new File([blob], filename, { type: mime })
      if (navigator.canShare?.({ files: [file] })) {
        await navigator.share({ files: [file], title: 'Mensaena Flyer' })
        return
      }
    } catch (e) {
      const err = e as Error
      if (err.name === 'AbortError') return
      // Fall through to download fallback
    }
  }

  // Fallback: object URL + <a download>
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  a.rel = 'noopener'
  a.style.display = 'none'
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  setTimeout(() => URL.revokeObjectURL(url), 2000)
}

async function dataUrlToBlob(dataUrl: string): Promise<Blob> {
  const res = await fetch(dataUrl)
  return res.blob()
}

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
  const blob = pdf.output('blob') as Blob
  await shareOrDownloadBlob(blob, `mensaena-flyer-${flyer.key}.pdf`, 'application/pdf')
}

async function downloadPng(el: HTMLElement, key: string) {
  const dataUrl = await capturePng(el, 3)
  const blob = await dataUrlToBlob(dataUrl)
  await shareOrDownloadBlob(blob, `mensaena-flyer-${key}.png`, 'image/png')
}

async function downloadQrPng(qrDataUrl: string) {
  if (!qrDataUrl) throw new Error('QR-Code nicht bereit')
  // Generate a higher-resolution version directly from qrcode lib
  const { default: QRCode } = await import('qrcode')
  // We don't have the inviteUrl here directly; instead re-encode the existing
  // dataUrl into a canvas at large size by drawing the existing image scaled.
  const img = new Image()
  await new Promise<void>((resolve, reject) => {
    img.onload = () => resolve()
    img.onerror = () => reject(new Error('QR-Image konnte nicht geladen werden'))
    img.src = qrDataUrl
  })
  const canvas = document.createElement('canvas')
  canvas.width = 1024
  canvas.height = 1024
  const ctx = canvas.getContext('2d')
  if (!ctx) throw new Error('Canvas nicht verfügbar')
  ctx.fillStyle = '#ffffff'
  ctx.fillRect(0, 0, 1024, 1024)
  ctx.imageSmoothingEnabled = false
  ctx.drawImage(img, 0, 0, 1024, 1024)
  const blob = await new Promise<Blob>((resolve, reject) => {
    canvas.toBlob((b) => b ? resolve(b) : reject(new Error('Canvas-Export fehlgeschlagen')), 'image/png')
  })
  await shareOrDownloadBlob(blob, 'mensaena-qr-code.png', 'image/png')
  // satisfy linter for unused QRCode import - reserved for future redesign
  void QRCode
}

// ── Flyer renderer ───────────────────────────────────────────────────────────

function FlyerRenderer({
  flyerKey, flyerRef, qrDataUrl, inviteUrl, userName, city,
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
  if (flyerKey === 's') return <FlyerSticker flyerRef={flyerRef} qrDataUrl={qrDataUrl} />
  return <FlyerD flyerRef={flyerRef} qrDataUrl={qrDataUrl} inviteUrl={inviteUrl} />
}

// ── Modal ────────────────────────────────────────────────────────────────────

function FlyerModal({
  flyer, flyerRef, qrDataUrl, inviteUrl, userName, city,
  busy, onClose, onDownloadPdf, onDownloadPng,
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
      const maxH = window.innerHeight * 0.7
      const s = Math.min(maxW / flyer.naturalWidth, maxH / flyer.naturalHeight, 1)
      setScale(s)
    }
    calc()
    window.addEventListener('resize', calc)
    return () => window.removeEventListener('resize', calc)
  }, [flyer.naturalWidth, flyer.naturalHeight])

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
    <div className="fixed inset-0 z-50 flex flex-col items-center justify-center bg-black/75 p-4" onClick={onClose}>
      <button
        className="absolute top-4 right-4 w-10 h-10 flex items-center justify-center rounded-full bg-white/10 hover:bg-white/20 text-white transition-colors"
        onClick={onClose}
        aria-label="Schließen"
      >
        <X className="w-5 h-5" />
      </button>

      <p className="text-white/70 text-sm font-medium mb-3">{flyer.title}</p>

      <div
        style={{ width: scaledW, height: scaledH, position: 'relative', overflow: 'hidden' }}
        onClick={(e) => e.stopPropagation()}
      >
        <div style={{ transform: `scale(${scale})`, transformOrigin: 'top left', position: 'absolute', top: 0, left: 0, pointerEvents: 'none' }}>
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

      <div className="flex gap-3 mt-5 flex-wrap justify-center" onClick={(e) => e.stopPropagation()}>
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

// ── Main ─────────────────────────────────────────────────────────────────────

export default function FlyerSection({ inviteUrl, userName, city = '' }: FlyerSectionProps) {
  const [qrDataUrl, setQrDataUrl] = useState('')
  const [busy, setBusy] = useState<string | null>(null)
  const [openKey, setOpenKey] = useState<string | null>(null)

  const flyerARef = useRef<HTMLDivElement | null>(null)
  const flyerBRef = useRef<HTMLDivElement | null>(null)
  const flyerCRef = useRef<HTMLDivElement | null>(null)
  const flyerDRef = useRef<HTMLDivElement | null>(null)
  const flyerHRef = useRef<HTMLDivElement | null>(null)
  const flyerSRef = useRef<HTMLDivElement | null>(null)

  const refMap: Record<string, React.RefObject<HTMLDivElement | null>> = {
    a: flyerARef, b: flyerBRef, c: flyerCRef, d: flyerDRef, h: flyerHRef, s: flyerSRef,
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
    if (!ref?.current || !flyer) {
      toast.error('Flyer noch nicht bereit')
      return
    }
    setBusy(`pdf-${key}`)
    try {
      await downloadPdf(ref.current, flyer)
      toast.success('PDF erstellt')
    } catch (e) {
      console.error('PDF-Download:', e)
      toast.error('Fehler beim PDF-Download')
    } finally {
      setBusy(null)
    }
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  const handleDownloadPng = useCallback(async (key: string) => {
    const ref = refMap[key]
    if (!ref?.current) {
      toast.error('Flyer noch nicht bereit')
      return
    }
    setBusy(`png-${key}`)
    try {
      await downloadPng(ref.current, key)
      toast.success('PNG erstellt')
    } catch (e) {
      console.error('PNG-Download:', e)
      toast.error('Fehler beim PNG-Download')
    } finally {
      setBusy(null)
    }
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  const handleDownloadQr = useCallback(async () => {
    if (!qrDataUrl) {
      toast.error('QR-Code noch nicht bereit')
      return
    }
    setBusy('qr')
    try {
      await downloadQrPng(qrDataUrl)
      toast.success('QR-Code gespeichert')
    } catch (e) {
      console.error('QR-Download:', e)
      toast.error('Fehler beim QR-Download')
    } finally {
      setBusy(null)
    }
  }, [qrDataUrl])

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

        <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
          {FLYERS.map((flyer) => {
            const previewW = Math.round(flyer.naturalWidth * flyer.previewScale)
            const previewH = Math.round(flyer.naturalHeight * flyer.previewScale)
            const ref = refMap[flyer.key]

            return (
              <div key={flyer.key} className="flex flex-col gap-2">
                <button
                  className="relative border border-stone-200 rounded-xl overflow-hidden bg-stone-50 group focus:outline-none focus-visible:ring-2 focus-visible:ring-primary-400 cursor-pointer"
                  style={{ width: previewW, height: previewH }}
                  onClick={() => setOpenKey(flyer.key)}
                  aria-label={`${flyer.title} öffnen`}
                >
                  <div style={{
                    transform: `scale(${flyer.previewScale})`,
                    transformOrigin: 'top left',
                    position: 'absolute',
                    top: 0, left: 0,
                    pointerEvents: 'none',
                    userSelect: 'none',
                  }}>
                    <FlyerRenderer
                      flyerKey={flyer.key}
                      flyerRef={ref}
                      qrDataUrl={qrDataUrl}
                      inviteUrl={inviteUrl}
                      userName={userName}
                      city={city}
                    />
                  </div>
                  <div className="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-colors flex items-center justify-center">
                    <div className="opacity-0 group-hover:opacity-100 transition-opacity bg-white rounded-full p-2 shadow-lg">
                      <Eye className="w-4 h-4 text-ink-700" />
                    </div>
                  </div>
                </button>

                <div>
                  <p className="text-sm font-semibold text-ink-800">{flyer.title}</p>
                  <p className="text-xs text-ink-400">{flyer.description}</p>
                </div>

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

        {/* QR-Only download */}
        <div className="mt-5 pt-5 border-t border-stone-100">
          <div className="flex items-start gap-3">
            <div className="w-9 h-9 rounded-xl bg-primary-50 border border-primary-200 flex items-center justify-center flex-shrink-0">
              <QrCode className="w-4 h-4 text-primary-600" />
            </div>
            <div className="flex-1">
              <p className="text-sm font-semibold text-ink-800">Nur QR-Code als PNG</p>
              <p className="text-xs text-ink-500 mt-0.5">
                Hochauflösendes QR-Code-Bild (1024×1024px) – ideal für eigenes Design oder Online-Profile
              </p>
            </div>
            <button
              onClick={handleDownloadQr}
              disabled={busy !== null || !qrDataUrl}
              className="flex-shrink-0 flex items-center gap-1.5 px-3 py-2 rounded-lg bg-primary-50 hover:bg-primary-100 border border-primary-200 text-primary-700 text-xs font-medium transition-colors disabled:opacity-50"
            >
              <Download className="w-3.5 h-3.5" />
              {busy === 'qr' ? 'Lädt…' : 'PNG'}
            </button>
          </div>
        </div>

        <p className="text-xs text-ink-400 mt-4 text-center">
          Auf Smartphones öffnet sich das System-Teilen-Menü. Auf Desktop wird die Datei direkt heruntergeladen.
        </p>
      </Card>

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
