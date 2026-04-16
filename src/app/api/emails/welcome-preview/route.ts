import { NextResponse } from 'next/server'
import { buildWelcomeEmail } from '@/lib/email/templates/welcome'

// GET /api/emails/welcome-preview – Rendert Welcome-Mail für Admin-Vorschau
export async function GET() {
  const { html } = buildWelcomeEmail({
    name: 'Maria',
    unsubscribeUrl: 'https://www.mensaena.de/unsubscribe?token=preview',
  })
  return new NextResponse(html, {
    status: 200,
    headers: { 'Content-Type': 'text/html; charset=utf-8' },
  })
}
