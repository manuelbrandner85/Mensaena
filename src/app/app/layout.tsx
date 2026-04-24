import type { Metadata } from 'next'

// Server-Layout für /app – stellt die Metadata bereit, da die page.tsx
// bewusst ein Client Component ist (siehe Kommentar dort).
export const metadata: Metadata = {
  title: 'Mensaena App – Android installieren',
  description:
    'Mensaena als Android App installieren. QR-Code scannen oder direkt herunterladen.',
  openGraph: {
    title: 'Mensaena App installieren',
    description:
      'QR-Code scannen oder Direktdownload – kostenlos für Android.',
  },
}

export default function AppLayout({ children }: { children: React.ReactNode }) {
  return children
}
