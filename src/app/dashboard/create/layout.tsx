import type { Metadata } from 'next'

export const metadata: Metadata = { title: 'Beitrag erstellen – Mensaena' }

export default function Layout({ children }: { children: React.ReactNode }) {
  return <>{children}</>
}
