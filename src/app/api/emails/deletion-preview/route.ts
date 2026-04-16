import { NextRequest, NextResponse } from 'next/server'
import {
  buildDeletionConfirmEmail,
  buildReengagement1,
  buildReengagement2,
  buildReengagement3,
  buildReengagement4,
} from '@/lib/email/templates/deletion'

// GET /api/emails/deletion-preview?type=confirm|re1|re2|re3|re4
// Rendert Vorschau der Lösch-/Re-Engagement-Mails
export async function GET(req: NextRequest) {
  const type = req.nextUrl.searchParams.get('type') || 'confirm'

  const data = {
    name: 'Maria',
    unsubscribeUrl: 'https://www.mensaena.de/api/emails/deletion-unsubscribe?token=preview',
  }

  const builders: Record<string, () => { subject: string; html: string }> = {
    confirm: () => buildDeletionConfirmEmail(data),
    re1: () => buildReengagement1(data),
    re2: () => buildReengagement2(data),
    re3: () => buildReengagement3(data),
    re4: () => buildReengagement4(data),
  }

  const builder = builders[type]
  if (!builder) {
    return NextResponse.json({ error: 'Invalid type. Use: confirm, re1, re2, re3, re4' }, { status: 400 })
  }

  const { html } = builder()
  return new NextResponse(html, {
    status: 200,
    headers: { 'Content-Type': 'text/html; charset=utf-8' },
  })
}
