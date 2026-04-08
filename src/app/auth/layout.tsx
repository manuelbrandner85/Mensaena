import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Anmelden oder Registrieren',
  description:
    'Melde dich bei Mensaena an oder erstelle ein kostenloses Konto, um Nachbarschaftshilfe zu organisieren.',
  robots: { index: false, follow: false },
}

export default function AuthLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return <>{children}</>
}
