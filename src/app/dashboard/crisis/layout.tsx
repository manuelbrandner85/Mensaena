import type { Metadata } from 'next'

export const metadata: Metadata = { title: 'Notfallhilfe – Mensaena' }

export default function Layout({ children }: { children: React.ReactNode }) {
  return <>{children}</>
}
