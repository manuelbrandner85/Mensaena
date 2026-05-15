import type { Metadata } from 'next'
import Link from 'next/link'
import Image from 'next/image'

export const metadata: Metadata = {
  title: 'Seite nicht gefunden',
  robots: { index: false, follow: false },
}

export default function NotFound() {
  return (
    <div className="min-h-dvh relative flex items-center justify-center px-4 overflow-hidden" style={{ background: '#0a1420', color: '#ece5d6' }}>
      <div className="absolute pointer-events-none rounded-full" style={{ top: '-20%', left: '-10%', width: '50vw', height: '50vw', background: 'radial-gradient(circle, rgba(199,147,99,0.12) 0%, transparent 70%)', filter: 'blur(80px)' }} aria-hidden="true" />
      <div className="absolute pointer-events-none rounded-full" style={{ bottom: '-15%', right: '-10%', width: '45vw', height: '45vw', background: 'radial-gradient(circle, rgba(43,86,99,0.14) 0%, transparent 70%)', filter: 'blur(80px)' }} aria-hidden="true" />
      <div className="relative max-w-md w-full text-center">
        <Link href="/" className="inline-block mb-8" aria-label="Zurück zur Startseite">
          <Image
            src="/mensaena-logo.png"
            alt="Mensaena"
            width={225}
            height={150}
            className="h-14 w-auto object-contain mx-auto"
          />
        </Link>

        <div className="w-16 h-16 rounded-2xl flex items-center justify-center mx-auto mb-6" style={{ background: 'rgba(22,32,53,0.85)', border: '1px solid rgba(199,147,99,0.20)' }}>
          <span className="text-3xl font-medium" style={{ fontFamily: 'var(--font-cinema), serif', color: '#c79363' }} aria-hidden="true">
            404
          </span>
        </div>

        <h1 className="text-2xl font-medium mb-3" style={{ fontFamily: 'var(--font-cinema), serif', color: '#ece5d6' }}>
          Seite nicht gefunden
        </h1>
        <p className="mb-8 text-sm leading-relaxed" style={{ color: '#94A3B8' }}>
          Die angeforderte Seite existiert nicht oder wurde verschoben.
        </p>

        <div className="flex gap-3 justify-center">
          <Link
            href="/"
            className="inline-flex items-center h-10 px-6 rounded-full text-sm font-medium tracking-wide transition-all hover:opacity-90"
            style={{ background: 'linear-gradient(135deg, #c79363 0%, #d4a472 50%, #c79363 100%)', color: '#0a1420' }}
          >
            Zur Startseite
          </Link>
          <Link
            href="/dashboard/map"
            className="inline-flex items-center h-10 px-6 rounded-full text-sm font-medium tracking-wide transition-all hover:opacity-80"
            style={{ background: 'rgba(22,32,53,0.70)', border: '1px solid rgba(199,147,99,0.25)', color: '#ece5d6' }}
          >
            Zur Karte
          </Link>
        </div>
      </div>
    </div>
  )
}
