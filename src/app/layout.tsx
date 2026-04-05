import type { Metadata } from 'next'
import '@/styles/globals.css'
import { Toaster } from 'react-hot-toast'
import AppShellWrapper from '@/components/navigation/AppShellWrapper'

export const metadata: Metadata = {
  title: 'Mensaena – Nachbarschaftshilfe neu gedacht',
  description:
    'Mensaena verbindet Menschen in deiner Nachbarschaft – kostenlos, gemeinnützig und von der Gemeinschaft getragen. Hilfe anbieten, Hilfe finden, Nachbarn kennenlernen.',
  keywords:
    'Nachbarschaftshilfe, Gemeinwohl, Hilfe, Tauschen, Teilen, Gemeinschaft, lokal, nachhaltig, Nachbarn',
  openGraph: {
    title: 'Mensaena – Nachbarschaftshilfe neu gedacht',
    description:
      'Menschen verbinden. Hilfe organisieren. Ressourcen teilen. Kostenlos & gemeinnützig.',
    url: 'https://mensaena.de',
    siteName: 'Mensaena',
    type: 'website',
    locale: 'de_DE',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Mensaena – Nachbarschaftshilfe neu gedacht',
    description:
      'Menschen verbinden. Hilfe organisieren. Ressourcen teilen. Kostenlos & gemeinnützig.',
  },
  robots: {
    index: true,
    follow: true,
  },
  alternates: {
    canonical: 'https://mensaena.de',
  },
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="de">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link
          rel="preconnect"
          href="https://fonts.gstatic.com"
          crossOrigin="anonymous"
        />
        <link
          href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&display=swap"
          rel="stylesheet"
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

        <AppShellWrapper>
          {children}
        </AppShellWrapper>

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
