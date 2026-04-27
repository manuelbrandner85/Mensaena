import type { Metadata, Viewport } from 'next'
import { Inter, Fraunces, JetBrains_Mono } from 'next/font/google'
import '@/styles/globals.css'

// next/font self-hosts Google Fonts at build time and swap-loads them to
// improve LCP. Single CSS file, preload hints, and correct subset pruning
// replace ~10 @fontsource CSS imports.
const inter = Inter({
  subsets: ['latin'],
  weight: ['400', '500', '600', '700'],
  variable: '--font-inter',
  display: 'swap',
  preload: true,
})

const fraunces = Fraunces({
  subsets: ['latin'],
  weight: ['400', '500', '600', '700'],
  variable: '--font-display',
  display: 'swap',
  preload: true,
})

const jetbrainsMono = JetBrains_Mono({
  subsets: ['latin'],
  weight: ['400', '500'],
  variable: '--font-mono',
  display: 'swap',
  preload: false,
})
import { Toaster } from 'react-hot-toast'
import { NextIntlClientProvider } from 'next-intl'
import { getMessages } from 'next-intl/server'
import AppShellWrapper from '@/components/navigation/AppShellWrapper'
import NativeBridge from '@/components/native/NativeBridge'
import LocationAutoSync from '@/components/native/LocationAutoSync'
import CapacitorPushBridge from '@/components/native/CapacitorPushBridge'
import CookieBanner from '@/components/shared/CookieBanner'
import {
  SITE_URL,
  SITE_NAME,
  SITE_DESCRIPTION,
  DEFAULT_OG_IMAGE,
  TWITTER_HANDLE,
  SUPABASE_PROJECT_URL,
} from '@/lib/seo'

// ── Viewport ─────────────────────────────────────────────────────────

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  maximumScale: 5,
  viewportFit: 'cover',
  themeColor: '#0a1420',
}

// ── Global metadata (defaults + template) ────────────────────────────

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),

  title: {
    default: `${SITE_NAME} – Nachbarschaftshilfe neu gedacht`,
    template: `%s | ${SITE_NAME}`,
  },

  description: SITE_DESCRIPTION,

  keywords: [
    'Nachbarschaftshilfe',
    'Nachbarn helfen',
    'Gemeinschaft',
    'Hilfe anbieten',
    'Hilfe suchen',
    'Werkzeug leihen',
    'Nachbarschaft',
    'ehrenamtlich',
    'kostenlos',
    'gemeinnützig',
    'Deutschland',
    'DSGVO',
  ],

  authors: [{ name: SITE_NAME, url: SITE_URL }],
  creator: SITE_NAME,
  publisher: SITE_NAME,

  formatDetection: {
    telephone: false,
    email: false,
    address: false,
  },


  // ── OpenGraph ────────────────────────────────────────────────────

  openGraph: {
    type: 'website',
    locale: 'de_DE',
    url: SITE_URL,
    siteName: SITE_NAME,
    title: `${SITE_NAME} – Nachbarschaftshilfe neu gedacht`,
    description: SITE_DESCRIPTION,
    images: [
      {
        url: DEFAULT_OG_IMAGE,
        width: 1200,
        height: 630,
        alt: `${SITE_NAME} – Nachbarschaftshilfe neu gedacht`,
      },
    ],
  },

  // ── Twitter ──────────────────────────────────────────────────────

  twitter: {
    card: 'summary_large_image',
    title: `${SITE_NAME} – Nachbarschaftshilfe neu gedacht`,
    description: SITE_DESCRIPTION,
    images: [DEFAULT_OG_IMAGE],
    creator: TWITTER_HANDLE,
  },

  // ── Robots ───────────────────────────────────────────────────────

  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-video-preview': -1,
      'max-image-preview': 'large',
      'max-snippet': -1,
    },
  },

  // ── Alternates ───────────────────────────────────────────────────

  alternates: {
    canonical: SITE_URL,
    languages: {
      de: SITE_URL,
      'x-default': SITE_URL,
    },
  },

  category: 'community',
}

// ── Layout ───────────────────────────────────────────────────────────

export default async function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const messages = await getMessages()
  return (
    <html
      lang="de"
      className={`${inter.variable} ${fraunces.variable} ${jetbrainsMono.variable}`}
    >
      <head>
        {/* ── Favicon & Icons ── */}
        <link rel="icon" href="/favicon.ico" sizes="48x48" />
        <link rel="icon" href="/favicon-16x16.png" type="image/png" sizes="16x16" />
        <link rel="icon" href="/favicon-32x32.png" type="image/png" sizes="32x32" />
        <link rel="apple-touch-icon" href="/apple-touch-icon.png" sizes="180x180" />
        <link rel="apple-touch-icon" sizes="152x152" href="/icons/icon-152x152.png" />
        <link rel="apple-touch-icon" sizes="192x192" href="/icons/icon-192x192.png" />

        {/* ── Preconnect ── */}
        <link rel="preconnect" href={SUPABASE_PROJECT_URL} />
        <link rel="dns-prefetch" href={SUPABASE_PROJECT_URL} />

        {/* ── Mobile Optimierung ── */}
        <meta name="application-name" content="Mensaena" />

        {/* ── Schema.org JSON-LD für Google-Ranking ── */}
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{
            __html: JSON.stringify({
              '@context': 'https://schema.org',
              '@type': 'WebSite',
              name: 'Mensaena',
              url: 'https://www.mensaena.de',
              description: 'Nachbarschaftshilfe neu gedacht. Mensaena verbindet Nachbarn für gegenseitige Hilfe – kostenlos, gemeinnützig und DSGVO-konform.',
              inLanguage: 'de',
              potentialAction: {
                '@type': 'SearchAction',
                target: { '@type': 'EntryPoint', urlTemplate: 'https://www.mensaena.de/search?q={search_term_string}' },
                'query-input': 'required name=search_term_string',
              },
            }),
          }}
        />
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{
            __html: JSON.stringify({
              '@context': 'https://schema.org',
              '@type': 'WebApplication',
              name: 'Mensaena',
              url: 'https://www.mensaena.de',
              description: 'Nachbarschaftshilfe-Plattform – Nachbarn helfen Nachbarn. Finde Hilfe, biete Unterstützung, vernetze dich lokal.',
              applicationCategory: 'SocialNetworkingApplication',
              operatingSystem: 'Web, Android',
              offers: { '@type': 'Offer', price: '0', priceCurrency: 'EUR' },
              author: { '@type': 'Organization', name: 'Mensaena', url: 'https://www.mensaena.de' },
              inLanguage: 'de',
              featureList: ['Nachbarschaftshilfe', 'Community-Karte', 'Drip-E-Mails', 'Gruppen', 'Marktplatz', 'Zeitbank'],
            }),
          }}
        />
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{
            __html: JSON.stringify({
              '@context': 'https://schema.org',
              '@type': 'Organization',
              '@id': 'https://www.mensaena.de/#organization',
              name: 'Mensaena',
              url: 'https://www.mensaena.de',
              logo: {
                '@type': 'ImageObject',
                url: 'https://www.mensaena.de/icons/icon-512x512.png',
                width: 512,
                height: 512,
              },
              description: 'Gemeinnützige Nachbarschaftshilfe-Plattform für Deutschland.',
              foundingDate: '2024',
              areaServed: { '@type': 'Country', name: 'Deutschland' },
              contactPoint: {
                '@type': 'ContactPoint',
                email: 'info@mensaena.de',
                contactType: 'customer service',
                availableLanguage: 'German',
              },
            }),
          }}
        />
      </head>
      <body className="bg-background antialiased">
        {/* Skip-to-content accessibility link */}
        <a
          href="#main-content"
          className="sr-only focus:not-sr-only focus:fixed focus:top-2 focus:left-2 focus:z-[100] focus:bg-primary-600 focus:text-white focus:px-4 focus:py-2 focus:rounded-lg focus:text-sm focus:font-semibold focus:outline-none focus:ring-2 focus:ring-primary-400 focus:ring-offset-2"
        >
          Zum Hauptinhalt springen
        </a>

        <NativeBridge />
        <LocationAutoSync />
        <CapacitorPushBridge />
        <NextIntlClientProvider messages={messages}>
          <AppShellWrapper>{children}</AppShellWrapper>
        </NextIntlClientProvider>

        <CookieBanner />
        <Toaster
          position="top-right"
          containerStyle={{ zIndex: 100000 }}
          toastOptions={{
            duration: 4000,
            style: {
              background: '#FAFAF7',
              color: '#0E1A19',
              border: '1px solid #E4E4DB',
              borderRadius: '14px',
              fontSize: '14px',
              fontFamily: 'var(--font-inter), system-ui, sans-serif',
              boxShadow: '0 1px 2px rgba(15,23,42,0.04), 0 12px 32px -16px rgba(15,23,42,0.10)',
            },
            success: {
              iconTheme: { primary: '#1EAAA6', secondary: '#FAFAF7' },
            },
            error: {
              iconTheme: { primary: '#C62828', secondary: '#FAFAF7' },
            },
          }}
        />
      </body>
    </html>
  )
}
