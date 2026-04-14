import type { Metadata, Viewport } from 'next'
import '@fontsource/inter/400.css'
import '@fontsource/inter/500.css'
import '@fontsource/inter/600.css'
import '@fontsource/inter/700.css'
// Display serif — used for editorial headlines (h1/h2)
import '@fontsource/fraunces/400.css'
import '@fontsource/fraunces/500.css'
import '@fontsource/fraunces/600.css'
import '@fontsource/fraunces/700.css'
// Mono — used for section labels, metadata, tags
import '@fontsource/jetbrains-mono/400.css'
import '@fontsource/jetbrains-mono/500.css'
import '@/styles/globals.css'
import { Toaster } from 'react-hot-toast'
import AppShellWrapper from '@/components/navigation/AppShellWrapper'
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
  themeColor: '#059669',
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

  manifest: '/manifest.json',

  appleWebApp: {
    capable: true,
    title: SITE_NAME,
    statusBarStyle: 'black-translucent',
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

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="de">
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

        {/* ── PWA ── */}
        <meta name="apple-mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
        <meta name="apple-mobile-web-app-title" content="Mensaena" />
        <meta name="mobile-web-app-capable" content="yes" />
        <meta name="application-name" content="Mensaena" />
        <meta name="msapplication-TileColor" content="#059669" />
        <meta name="msapplication-TileImage" content="/icons/icon-144x144.png" />
      </head>
      <body className="bg-background antialiased">
        {/* Skip-to-content accessibility link */}
        <a
          href="#main-content"
          className="sr-only focus:not-sr-only focus:fixed focus:top-2 focus:left-2 focus:z-[100] focus:bg-primary-600 focus:text-white focus:px-4 focus:py-2 focus:rounded-lg focus:text-sm focus:font-semibold focus:outline-none focus:ring-2 focus:ring-primary-400 focus:ring-offset-2"
        >
          Zum Hauptinhalt springen
        </a>

        <AppShellWrapper>{children}</AppShellWrapper>

        <Toaster
          position="top-right"
          toastOptions={{
            duration: 4000,
            style: {
              background: '#FAFAF7',
              color: '#0E1A19',
              border: '1px solid #E4E4DB',
              borderRadius: '14px',
              fontSize: '14px',
              fontFamily: 'Inter, sans-serif',
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
