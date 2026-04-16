import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { getApiClient, err } from '@/lib/supabase/api-auth'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDk4NzExOCwiZXhwIjoyMDkwNTYzMTE4fQ.t09nG5IbpDPAuBuTLuOedep9ZEmi1dcNjD0xsPzFZVQ'

const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
})

async function requireAdmin() {
  const { supabase, user } = await getApiClient()
  if (!user) return { error: err.unauthorized() }
  const { data: profile } = await supabase
    .from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!profile || !['admin', 'moderator'].includes(profile.role)) {
    return { error: err.forbidden() }
  }
  return { user }
}

// PUT /api/emails/campaigns/[id] – Kampagne bearbeiten
export async function PUT(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { error: authError } = await requireAdmin()
  if (authError) return authError

  const { id } = await params
  let body: { subject?: string; preview_text?: string; html_content?: string }
  try { body = await req.json() } catch { return err.bad('Invalid body') }

  const updates: Record<string, string> = {}
  if (body.subject)      updates.subject      = body.subject
  if (body.preview_text !== undefined) updates.preview_text = body.preview_text ?? ''
  if (body.html_content) updates.html_content = body.html_content

  if (Object.keys(updates).length === 0) {
    return err.bad('Keine Felder zum Aktualisieren')
  }

  const { data, error } = await admin
    .from('email_campaigns')
    .update(updates)
    .eq('id', id)
    .eq('status', 'draft') // nur Entwürfe bearbeitbar
    .select()
    .maybeSingle()

  if (error) return err.internal(error.message)
  if (!data) return err.notFound('Kampagne nicht gefunden oder bereits gesendet')
  return NextResponse.json(data)
}

// DELETE /api/emails/campaigns/[id] – Entwurf löschen
export async function DELETE(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { error: authError } = await requireAdmin()
  if (authError) return authError

  const { id } = await params

  const { error } = await admin
    .from('email_campaigns')
    .delete()
    .eq('id', id)
    .eq('status', 'draft')

  if (error) return err.internal(error.message)
  return NextResponse.json({ ok: true })
}
