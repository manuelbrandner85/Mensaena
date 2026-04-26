import type { Metadata } from 'next'
import SpendenClient from './SpendenClient'

/**
 * Spenden – Server-Wrapper mit SEO-Metadata.
 * Die interaktive UI lebt in SpendenClient.tsx (use client). Open-Graph-
 * und Twitter-Card-Tags sorgen für saubere Social-Previews, wenn jemand
 * den Spenden-Link in WhatsApp, Telegram, Slack oder X teilt.
 */
export const metadata: Metadata = {
  title: 'Spenden – Mensaena unterstützen',
  description:
    'Mensaena ist 100 % werbefrei und für alle kostenlos. Damit das so bleibt, finanzieren wir uns ausschließlich durch Spenden – per QR-Code, IBAN oder Spendenbescheinigung.',
  alternates: { canonical: '/spenden' },
  openGraph: {
    title: 'Mensaena unterstützen – werbefrei. spendenfinanziert.',
    description:
      'Drei Euro halten Mensaena einen Monat lang am Laufen – pro 60 Nachbar:innen. Werbefrei. 100 % transparent. Für immer.',
    url: 'https://www.mensaena.de/spenden',
    type: 'website',
    images: [
      {
        url: '/mensaena-logo.png',
        width: 1200,
        height: 630,
        alt: 'Mensaena – Damit Nachbarschaft möglich bleibt.',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Mensaena unterstützen',
    description:
      'Werbefrei. Spendenfinanziert. Für immer. Drei Euro halten Mensaena einen Monat lang am Laufen – pro 60 Nachbar:innen.',
    images: ['/mensaena-logo.png'],
  },
  robots: { index: true, follow: true },
}

export default function SpendenPage() {
  return <SpendenClient />
}
