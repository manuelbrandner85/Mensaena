import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { sendEmail } from '@/lib/email/send'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY ?? ''

let _admin: ReturnType<typeof createClient> | null = null
function admin() {
  if (!_admin) _admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { autoRefreshToken: false, persistSession: false } })
  return _admin
}

function escapeHtml(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')
}

interface ContactBody {
  name?: string
  email?: string
  subject?: string
  message?: string
}

export async function POST(req: NextRequest) {
  let body: ContactBody
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ error: 'Invalid body' }, { status: 400 })
  }

  const { name, email, subject, message } = body

  if (!name?.trim() || !email?.trim() || !subject?.trim() || !message?.trim()) {
    return NextResponse.json({ error: 'Alle Felder sind Pflicht.' }, { status: 422 })
  }
  if (name.trim().length > 100 || subject.trim().length > 200 || message.trim().length > 5000) {
    return NextResponse.json({ error: 'Eingabe zu lang.' }, { status: 422 })
  }
  if (message.trim().length < 10) {
    return NextResponse.json({ error: 'Nachricht zu kurz (min. 10 Zeichen).' }, { status: 422 })
  }
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email.trim())) {
    return NextResponse.json({ error: 'Ungültige E-Mail-Adresse.' }, { status: 422 })
  }

  // Rate limit: max 3 messages per email per 24 hours
  const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString()
  const { count } = await admin
    .from('contact_messages')
    .select('*', { count: 'exact', head: true })
    .eq('email', email.trim().toLowerCase())
    .gte('created_at', since)
  if ((count ?? 0) >= 3) {
    return NextResponse.json(
      { error: 'Zu viele Nachrichten. Bitte versuche es morgen erneut.' },
      { status: 429 }
    )
  }

  const { error } = await admin().from('contact_messages').insert({
    name: name.trim(),
    email: email.trim().toLowerCase(),
    subject: subject.trim(),
    message: message.trim(),
  })

  if (error) {
    console.error('[contact] insert error:', error.message)
    return NextResponse.json({ error: 'Nachricht konnte nicht gespeichert werden.' }, { status: 500 })
  }

  // Notify admins — fire-and-forget, don't block the response
  sendEmail({
    to: 'info@mensaena.de',
    subject: `[Kontakt] ${subject.trim()} – ${name.trim()}`,
    html: `
      <p><strong>Von:</strong> ${escapeHtml(name.trim())} &lt;${escapeHtml(email.trim())}&gt;</p>
      <p><strong>Betreff:</strong> ${escapeHtml(subject.trim())}</p>
      <hr/>
      <p>${escapeHtml(message.trim()).replace(/\n/g, '<br/>')}</p>
      <hr/>
      <p style="font-size:12px;color:#888;">Nachricht über das Kontaktformular auf mensaena.de</p>
    `,
    fromName: 'Mensaena Kontaktformular',
  }).catch(() => { /* ignore email errors */ })

  return NextResponse.json({ ok: true })
}
