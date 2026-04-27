'use client'

import { useRef, useState, useEffect } from 'react'
import { Printer, Download, FileText } from 'lucide-react'
import Card from '@/components/ui/Card'
import SectionHeader from '@/components/ui/SectionHeader'
import FlyerA from './FlyerA'
import FlyerB from './FlyerB'
import FlyerC from './FlyerC'
import FlyerD from './FlyerD'

interface FlyerSectionProps {
  inviteUrl: string
  userName: string
}

interface FlyerMeta {
  key: string
  title: string
  description: string
  naturalWidth: number
  naturalHeight: number
  previewScale: number
  actions: ('print' | 'png')[]
}

const FLYERS: FlyerMeta[] = [
  {
    key: 'a',
    title: 'Briefkasten-Karte',
    description: 'A6 · für Briefkästen',
    naturalWidth: 397,
    naturalHeight: 559,
    previewScale: 0.38,
    actions: ['print'],
  },
  {
    key: 'b',
    title: 'Schwarzes Brett',
    description: 'A4 · mit Abreiß-Streifen',
    naturalWidth: 794,
    naturalHeight: 1123,
    previewScale: 0.205,
    actions: ['print'],
  },
  {
    key: 'c',
    title: 'Gemeinschafts-Flyer',
    description: 'A5 quer · für Veranstaltungen',
    naturalWidth: 794,
    naturalHeight: 559,
    previewScale: 0.29,
    actions: ['print'],
  },
  {
    key: 'd',
    title: 'Digital-Share',
    description: '1080 × 1080 px · Social Media',
    naturalWidth: 1080,
    naturalHeight: 1080,
    previewScale: 0.21,
    actions: ['print', 'png'],
  },
]

async function captureFlyer(el: HTMLElement): Promise<string> {
  const { toPng } = await import('html-to-image')
  return toPng(el, { pixelRatio: 2, cacheBust: true })
}

function openPrintWindow(pngDataUrl: string) {
  const w = window.open('', '_blank', 'width=960,height=1200,menubar=no,toolbar=no,scrollbars=yes')
  if (!w) return
  w.document.write(
    `<!DOCTYPE html><html><head><meta charset="utf-8"><title>Mensaena Flyer</title>` +
    `<style>*{margin:0;padding:0;box-sizing:border-box}` +
    `body{background:#fff;display:flex;justify-content:center;padding:20px}` +
    `img{max-width:100%;height:auto;display:block}` +
    `@media print{body{padding:0}@page{margin:0}}</style></head>` +
    `<body><img src="${pngDataUrl}">` +
    `<script>window.onload=function(){window.print()}<\/script></body></html>`
  )
  w.document.close()
}

export default function FlyerSection({ inviteUrl, userName }: FlyerSectionProps) {
  const [qrDataUrl, setQrDataUrl] = useState('')
  const [busy, setBusy] = useState<string | null>(null)

  const flyerARefs = useRef<HTMLDivElement | null>(null)
  const flyerBRef = useRef<HTMLDivElement | null>(null)
  const flyerCRef = useRef<HTMLDivElement | null>(null)
  const flyerDRef = useRef<HTMLDivElement | null>(null)

  const refMap: Record<string, React.RefObject<HTMLDivElement | null>> = {
    a: flyerARefs,
    b: flyerBRef,
    c: flyerCRef,
    d: flyerDRef,
  }

  useEffect(() => {
    if (!inviteUrl) return
    let cancelled = false
    import('qrcode').then((mod) => {
      const QRCode = mod.default
      QRCode.toDataURL(inviteUrl, {
        width: 400,
        margin: 1,
        color: { dark: '#147170', light: '#ffffff' },
      }).then((url: string) => {
        if (!cancelled) setQrDataUrl(url)
      })
    })
    return () => { cancelled = true }
  }, [inviteUrl])

  const handlePrint = async (key: string) => {
    const ref = refMap[key]
    if (!ref.current) return
    setBusy(`print-${key}`)
    try {
      const png = await captureFlyer(ref.current)
      openPrintWindow(png)
    } finally {
      setBusy(null)
    }
  }

  const handleDownloadPng = async (key: string) => {
    const ref = refMap[key]
    if (!ref.current) return
    setBusy(`png-${key}`)
    try {
      const { toPng } = await import('html-to-image')
      const png = await toPng(ref.current, { pixelRatio: 3, cacheBust: true })
      const a = document.createElement('a')
      a.href = png
      a.download = `mensaena-flyer-${key}.png`
      document.body.appendChild(a)
      a.click()
      document.body.removeChild(a)
    } finally {
      setBusy(null)
    }
  }

  return (
    <Card variant="default">
      <SectionHeader
        title="Flyer herunterladen"
        subtitle="Drucke Flyer mit deinem persönlichen QR-Code – jede Registrierung zählt für dein Badge"
        icon={<FileText className="w-4 h-4" />}
        className="mb-5"
      />

      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        {FLYERS.map((flyer) => {
          const previewW = Math.round(flyer.naturalWidth * flyer.previewScale)
          const previewH = Math.round(flyer.naturalHeight * flyer.previewScale)
          const isPrintBusy = busy === `print-${flyer.key}`
          const isPngBusy = busy === `png-${flyer.key}`

          return (
            <div key={flyer.key} className="flex flex-col gap-3">
              {/* Preview */}
              <div
                className="relative border border-stone-200 rounded-xl overflow-hidden bg-stone-50"
                style={{ width: previewW, height: previewH }}
              >
                <div
                  style={{
                    transform: `scale(${flyer.previewScale})`,
                    transformOrigin: 'top left',
                    position: 'absolute',
                    top: 0,
                    left: 0,
                    pointerEvents: 'none',
                    userSelect: 'none',
                  }}
                >
                  {flyer.key === 'a' && (
                    <FlyerA flyerRef={flyerARefs} qrDataUrl={qrDataUrl} inviteUrl={inviteUrl} />
                  )}
                  {flyer.key === 'b' && (
                    <FlyerB flyerRef={flyerBRef} qrDataUrl={qrDataUrl} inviteUrl={inviteUrl} />
                  )}
                  {flyer.key === 'c' && (
                    <FlyerC flyerRef={flyerCRef} qrDataUrl={qrDataUrl} inviteUrl={inviteUrl} userName={userName} />
                  )}
                  {flyer.key === 'd' && (
                    <FlyerD flyerRef={flyerDRef} qrDataUrl={qrDataUrl} inviteUrl={inviteUrl} />
                  )}
                </div>
              </div>

              {/* Info */}
              <div>
                <p className="text-sm font-semibold text-ink-800">{flyer.title}</p>
                <p className="text-xs text-ink-400">{flyer.description}</p>
              </div>

              {/* Actions */}
              <div className="space-y-1.5">
                <button
                  onClick={() => handlePrint(flyer.key)}
                  disabled={busy !== null}
                  className="w-full flex items-center justify-center gap-1.5 px-3 py-2 rounded-lg bg-primary-50 hover:bg-primary-100 border border-primary-200 text-primary-700 text-xs font-medium transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <Printer className="w-3.5 h-3.5" />
                  {isPrintBusy ? 'Lädt…' : 'Drucken / PDF'}
                </button>

                {flyer.actions.includes('png') && (
                  <button
                    onClick={() => handleDownloadPng(flyer.key)}
                    disabled={busy !== null}
                    className="w-full flex items-center justify-center gap-1.5 px-3 py-2 rounded-lg bg-stone-50 hover:bg-stone-100 border border-stone-200 text-ink-600 text-xs font-medium transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    <Download className="w-3.5 h-3.5" />
                    {isPngBusy ? 'Lädt…' : 'Als PNG'}
                  </button>
                )}
              </div>
            </div>
          )
        })}
      </div>

      <p className="text-xs text-ink-400 mt-4 text-center">
        Alle Flyer enthalten deinen persönlichen QR-Code. Jede neue Registrierung über deinen Link zählt.
      </p>
    </Card>
  )
}
