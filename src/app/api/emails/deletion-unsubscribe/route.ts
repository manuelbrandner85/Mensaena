import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDk4NzExOCwiZXhwIjoyMDkwNTYzMTE4fQ.t09nG5IbpDPAuBuTLuOedep9ZEmi1dcNjD0xsPzFZVQ'

const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
})

// GET /api/emails/deletion-unsubscribe?token=xxx
// Stoppt alle Re-Engagement-Mails für gelöschte User
export async function GET(req: NextRequest) {
  const token = req.nextUrl.searchParams.get('token')
  if (!token) {
    return NextResponse.json({ error: 'Token fehlt' }, { status: 400 })
  }

  const { data, error } = await admin
    .from('email_deletion_followups')
    .update({ completed: true })
    .eq('unsubscribe_token', token)
    .eq('completed', false)
    .select('email')
    .maybeSingle()

  if (error) {
    return NextResponse.json({ error: 'Fehler beim Abbestellen' }, { status: 500 })
  }

  if (!data) {
    return NextResponse.json({ error: 'Token ungültig oder bereits abbestellt' }, { status: 404 })
  }

  return NextResponse.json({ ok: true, email: data.email })
}
