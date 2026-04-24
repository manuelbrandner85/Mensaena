import type { Metadata } from 'next'
import Image from 'next/image'
import Link from 'next/link'
import { Smartphone, ShieldCheck, RefreshCw, ChevronDown } from 'lucide-react'
import AppPageNativeRedirect from './AppPageNativeRedirect'
import AppPageDownloadButton from './AppPageDownloadButton'
import AppPageQRCode from './AppPageQRCode'
import { FDROID_DEEPLINK } from '@/lib/app-download'

export const metadata: Metadata = {
  title: 'Mensaena App – Android installieren',
  description:
    'Mensaena als Android App installieren. QR-Code scannen oder direkt herunterladen.',
  openGraph: {
    title: 'Mensaena App installieren',
    description: 'QR-Code scannen oder Direktdownload – kostenlos für Android.',
  },
}

// Server Component – vollständig statisch. Der QR-Code wird von
// <AppPageQRCode/> client-seitig generiert, weil das 'qrcode'-Package
// in Cloudflare Workers sonst BAILOUT_TO_CLIENT_SIDE_RENDERING auslöst
// und die gesamte Seite leer rendert.
// In der nativen APK wird der Inhalt per CSS (html.is-native .cta-app-download)
// ausgeblendet – dafür leitet <AppPageNativeRedirect/> auf /dashboard weiter.
export default function AppDownloadPage() {
  return (
    <>
      {/* Redirect in der nativen App auf /dashboard – Download ergibt dort keinen Sinn */}
      <AppPageNativeRedirect />

      <main className="cta-app-download min-h-dvh bg-gradient-to-br from-primary-50 via-white to-teal-50 py-8 sm:py-16 px-4">
        <div className="max-w-3xl mx-auto">
          {/* Back link */}
          <Link
            href="/"
            className="inline-flex items-center gap-2 text-sm text-gray-600 hover:text-primary-700 mb-6 font-medium"
          >
            ← Zur Startseite
          </Link>

          <div className="bg-white rounded-3xl shadow-glow-teal/30 border border-primary-100/50 overflow-hidden">
            {/* Hero */}
            <div className="bg-gradient-to-br from-primary-600 to-teal-700 text-white px-6 sm:px-10 py-10 sm:py-14 text-center">
              <div className="inline-block bg-white/15 backdrop-blur-sm rounded-3xl p-3 mb-4">
                <Image
                  src="/icons/icon-512x512.png"
                  alt="Mensaena App Icon"
                  width={88}
                  height={88}
                  className="rounded-2xl"
                  priority
                />
              </div>
              <h1 className="text-3xl sm:text-4xl font-bold tracking-tight">
                Mensaena als App
              </h1>
              <p className="mt-3 text-white/90 text-base sm:text-lg max-w-md mx-auto">
                Nachbarschaftshilfe direkt am Handy – kostenlos für Android
              </p>
            </div>

            {/* Body */}
            <div className="p-6 sm:p-10">
              {/* QR + Download grid */}
              <div className="grid sm:grid-cols-[auto_1fr] gap-8 items-center">
                {/* QR code (client-seitig generiert) */}
                <div className="flex flex-col items-center">
                  <AppPageQRCode />
                  <p className="text-xs text-gray-500 mt-3 text-center max-w-[260px]">
                    QR-Code mit der Kamera des Handys scannen
                  </p>
                </div>

                {/* Direct download */}
                <div className="text-center sm:text-left">
                  <p className="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-2">
                    Oder direkt
                  </p>
                  <h2 className="text-xl font-bold text-gray-900 mb-4">
                    APK herunterladen
                  </h2>
                  <AppPageDownloadButton />
                  <p className="text-xs text-gray-500 mt-3">
                    Aktueller Build aus <code className="text-[11px] bg-gray-100 px-1 rounded">main</code> – signiert &amp; sicher
                  </p>
                </div>
              </div>

              {/* Trust badges */}
              <div className="mt-10 grid grid-cols-1 sm:grid-cols-3 gap-3">
                <Badge icon={<ShieldCheck className="w-4 h-4" />}>
                  Konsistent signiert
                </Badge>
                <Badge icon={<RefreshCw className="w-4 h-4" />}>
                  Updates ohne Neuinstallation
                </Badge>
                <Badge icon={<Smartphone className="w-4 h-4" />}>
                  Funktioniert auf Android 7+
                </Badge>
              </div>

              {/* Install steps */}
              <section className="mt-10 bg-primary-50/50 rounded-2xl p-6">
                <h3 className="font-bold text-gray-900 mb-3">Installation in 3 Schritten</h3>
                <ol className="space-y-2 text-sm text-gray-700">
                  <li className="flex gap-3">
                    <span className="flex-shrink-0 w-6 h-6 rounded-full bg-primary-600 text-white text-xs font-bold flex items-center justify-center">1</span>
                    <span>APK herunterladen (Button oben oder QR-Code scannen)</span>
                  </li>
                  <li className="flex gap-3">
                    <span className="flex-shrink-0 w-6 h-6 rounded-full bg-primary-600 text-white text-xs font-bold flex items-center justify-center">2</span>
                    <span>In den Downloads auf <em>mensaena-release.apk</em> tippen</span>
                  </li>
                  <li className="flex gap-3">
                    <span className="flex-shrink-0 w-6 h-6 rounded-full bg-primary-600 text-white text-xs font-bold flex items-center justify-center">3</span>
                    <span>Android fragt einmalig nach Erlaubnis – &quot;Installieren&quot; tippen, fertig</span>
                  </li>
                </ol>
              </section>

              {/* F-Droid (advanced) */}
              <details className="mt-6 group">
                <summary className="cursor-pointer flex items-center justify-between gap-3 px-5 py-4 bg-gray-50 hover:bg-gray-100 rounded-xl transition-colors">
                  <span className="font-semibold text-gray-800 text-sm">
                    Erweitert: Per F-Droid installieren (automatische Updates)
                  </span>
                  <ChevronDown className="w-4 h-4 text-gray-500 transition-transform group-open:rotate-180" />
                </summary>
                <div className="mt-4 px-5 py-4 bg-white border border-gray-200 rounded-xl text-sm text-gray-700 space-y-4">
                  <p>
                    F-Droid ist ein freier App-Store. Damit erhältst du automatische Updates,
                    ohne Google Play Konto.
                  </p>
                  <ol className="list-decimal list-inside space-y-1 text-xs">
                    <li>
                      <a href="https://f-droid.org" target="_blank" rel="noopener noreferrer" className="text-primary-700 underline">
                        F-Droid installieren
                      </a> (kostenlos, sicher)
                    </li>
                    <li>Auf den Button unten tippen</li>
                    <li>Repo bestätigen → Mensaena suchen → Installieren</li>
                  </ol>
                  <a
                    href={FDROID_DEEPLINK}
                    className="btn-outline w-full inline-flex items-center justify-center gap-2"
                  >
                    📦 F-Droid Repo hinzufügen
                  </a>
                </div>
              </details>
            </div>
          </div>

          {/* Privacy note */}
          <p className="text-xs text-gray-500 text-center mt-6 max-w-md mx-auto">
            Open Source · keine Tracker · DSGVO-konform · Quellcode auf{' '}
            <a
              href="https://github.com/manuelbrandner85/Mensaena"
              target="_blank"
              rel="noopener noreferrer"
              className="text-primary-700 underline"
            >
              GitHub
            </a>
          </p>
        </div>
      </main>
    </>
  )
}

function Badge({ icon, children }: { icon: React.ReactNode; children: React.ReactNode }) {
  return (
    <div className="flex items-center justify-center gap-2 px-4 py-2.5 bg-primary-50 rounded-xl border border-primary-100/60 text-primary-800 text-xs font-medium">
      {icon}
      <span>{children}</span>
    </div>
  )
}
