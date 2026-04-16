import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { getApiClient, err } from '@/lib/supabase/api-auth'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDk4NzExOCwiZXhwIjoyMDkwNTYzMTE4fQ.t09nG5IbpDPAuBuTLuOedep9ZEmi1dcNjD0xsPzFZVQ'

const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
})

async function requireAdmin(req: NextRequest) {
  const { supabase, user } = await getApiClient()
  if (!user) return { error: err.unauthorized() }
  const { data: profile } = await supabase
    .from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!profile || !['admin', 'moderator'].includes(profile.role)) {
    return { error: err.forbidden() }
  }
  return { user }
}

// GET /api/emails/campaigns – Admin: listet alle Kampagnen
export async function GET(req: NextRequest) {
  const { error: authError } = await requireAdmin(req)
  if (authError) return authError

  const status = req.nextUrl.searchParams.get('status') // 'draft' | 'sent' | null
  let query = admin
    .from('email_campaigns')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(100)

  if (status) query = query.eq('status', status)

  const { data, error } = await query
  if (error) return err.internal(error.message)
  return NextResponse.json(data)
}

// POST /api/emails/campaigns – Admin: neue Kampagne erstellen
export async function POST(req: NextRequest) {
  const { error: authError, user } = await requireAdmin(req)
  if (authError) return authError

  let body: {
    type?: string
    subject?: string
    preview_text?: string
    html_content?: string
    auto_generated?: boolean
  }
  try { body = await req.json() } catch { return err.bad('Invalid body') }

  const { type = 'custom', subject, preview_text, html_content } = body
  if (!subject || !html_content) {
    return err.bad('subject und html_content sind erforderlich')
  }

  const { data, error } = await admin
    .from('email_campaigns')
    .insert({
      type,
      subject,
      preview_text,
      html_content,
      status: 'draft',
      auto_generated: body.auto_generated ?? false,
      created_by: user!.id,
    })
    .select()
    .single()

  if (error) return err.internal(error.message)
  return NextResponse.json(data, { status: 201 })
}
