import type { Metadata } from 'next'
import Link from 'next/link'
import Image from 'next/image'

export const metadata: Metadata = {
  title: 'Seite nicht gefunden',
  robots: { index: false, follow: false },
}

export default function NotFound() {
  return (
    <div className="min-h-dvh bg-paper aurora-bg flex items-center justify-center px-4">
      <div className="max-w-md w-full text-center">
        <Link href="/" className="inline-block mb-8" aria-label="Zurück zur Startseite">
          <Image
            src="/mensaena-logo.png"
            alt="Mensaena"
            width={225}
            height={150}
            className="h-14 w-auto object-contain mx-auto"
          />
        </Link>

        <div className="w-16 h-16 bg-primary-100 rounded-2xl flex items-center justify-center mx-auto mb-6">
          <span className="font-display text-3xl font-medium text-primary-600" aria-hidden="true">
            404
          </span>
        </div>

        <h1 className="font-display text-2xl font-medium text-ink-800 mb-3">
          Seite nicht gefunden
        </h1>
        <p className="text-ink-500 mb-8 text-sm leading-relaxed">
          Die angeforderte Seite existiert nicht oder wurde verschoben.
        </p>

        <div className="flex gap-3 justify-center">
          <Link
            href="/"
            className="inline-flex items-center h-10 px-6 rounded-full bg-ink-900 hover:bg-ink-700 text-paper text-sm font-medium tracking-wide transition-colors"
          >
            Zur Startseite
          </Link>
          <Link
            href="/dashboard/map"
            className="inline-flex items-center h-10 px-6 rounded-full border border-stone-200 hover:border-stone-300 bg-white text-ink-700 text-sm font-medium tracking-wide transition-colors"
          >
            Zur Karte
          </Link>
        </div>
      </div>
    </div>
  )
}
