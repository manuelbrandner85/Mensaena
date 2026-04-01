import type { Metadata } from 'next'
import '@/styles/globals.css'
import { Toaster } from 'react-hot-toast'
import MensaenaBot from '@/components/bot/MensaenaBot'

export const metadata: Metadata = {
  title: 'Mensaena – die Gemeinwohl Plattform',
  description: 'Mensaena verbindet Menschen lokal, organisiert Hilfe, fördert nachhaltige Ressourcennutzung und stärkt das Gemeinwohl.',
  keywords: 'Gemeinwohl, Hilfe, Tauschen, Teilen, Gemeinschaft, lokal, nachhaltig',
  openGraph: {
    title: 'Mensaena – die Gemeinwohl Plattform',
    description: 'Menschen verbinden. Hilfe organisieren. Ressourcen teilen.',
    type: 'website',
    locale: 'de_DE',
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
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        <link
          href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&display=swap"
          rel="stylesheet"
        />
      </head>
      <body className="bg-background antialiased">
        {children}
        <MensaenaBot />
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
              iconTheme: { primary: '#66BB6A', secondary: '#fff' },
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
