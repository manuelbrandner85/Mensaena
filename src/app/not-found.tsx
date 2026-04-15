import type { Metadata } from 'next'
import Link from 'next/link'
import Image from 'next/image'

export const metadata: Metadata = {
  title: 'Seite nicht gefunden',
  robots: { index: false, follow: false },
}

export default function NotFound() {
  return (
    <div className="min-h-screen bg-background flex items-center justify-center px-4">
      <div className="max-w-md w-full text-center">
        <Link href="/" className="inline-block mb-8">
          <Image
            src="/mensaena-logo.png"
            alt="Mensaena"
            width={225}
            height={150}
            className="h-14 w-auto object-contain mx-auto"
          />
        </Link>

        <div className="w-16 h-16 bg-primary-100 rounded-2xl flex items-center justify-center mx-auto mb-6">
          <span className="text-3xl" aria-hidden="true">
            🌿
          </span>
        </div>

        <h1 className="text-2xl font-bold text-gray-900 mb-3">
          Seite nicht gefunden
        </h1>
        <p className="text-gray-600 mb-8 text-sm leading-relaxed">
          Die angeforderte Seite existiert nicht oder wurde verschoben.
        </p>

        <div className="flex gap-3 justify-center">
          <Link
            href="/"
            className="px-6 py-2.5 bg-primary-600 hover:bg-primary-700 text-white text-sm font-semibold rounded-xl transition-all"
          >
            Zur Startseite
          </Link>
          <Link
            href="/dashboard/map"
            className="px-6 py-2.5 bg-gray-100 hover:bg-gray-200 text-gray-700 text-sm font-semibold rounded-xl transition-all"
          >
            Zur Karte
          </Link>
        </div>
      </div>
    </div>
  )
}
