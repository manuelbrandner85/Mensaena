import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDk4NzExOCwiZXhwIjoyMDkwNTYzMTE4fQ.t09nG5IbpDPAuBuTLuOedep9ZEmi1dcNjD0xsPzFZVQ'

const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
})

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

  const { error } = await admin.from('contact_messages').insert({
    name: name.trim(),
    email: email.trim().toLowerCase(),
    subject: subject.trim(),
    message: message.trim(),
  })

  if (error) {
    console.error('[contact] insert error:', error.message)
    return NextResponse.json({ error: 'Nachricht konnte nicht gespeichert werden.' }, { status: 500 })
  }

  return NextResponse.json({ ok: true })
}
