import type { Metadata, Viewport } from 'next'
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

  // ── Verification (placeholders) ──────────────────────────────────

  verification: {
    google: 'PLACEHOLDER_GOOGLE_VERIFICATION',
    other: {
      'msvalidate.01': 'PLACEHOLDER_BING_VERIFICATION',
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

        {/* ── Fonts ── */}
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        <link
          href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&display=swap"
          rel="stylesheet"
        />

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
              background: '#fff',
              color: '#1a1a1a',
              border: '1px solid #e8f5e9',
              borderRadius: '12px',
              fontSize: '14px',
              fontFamily: 'Inter, sans-serif',
            },
            success: {
              iconTheme: { primary: '#059669', secondary: '#fff' },
            },
            error: {
              iconTheme: { primary: '#C62828', secondary: '#fff' },
            },
          }}
        />
      </body>
    </html>
  )
}
