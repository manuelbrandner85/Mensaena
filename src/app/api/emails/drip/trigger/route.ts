import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { sendEmail } from '@/lib/email/send'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDk4NzExOCwiZXhwIjoyMDkwNTYzMTE4fQ.t09nG5IbpDPAuBuTLuOedep9ZEmi1dcNjD0xsPzFZVQ'
const BASE_URL     = process.env.NEXT_PUBLIC_APP_URL || 'https://www.mensaena.de'
const CRON_SECRET  = process.env.CRON_SECRET || ''

const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
})

// POST /api/emails/drip/trigger
// Called by Cloudflare Cron or manually. Processes all due drip enrollments.
export async function POST(req: NextRequest) {
  const secret = req.headers.get('x-cron-secret')
  const cfWorker = req.headers.get('x-cloudflare-worker')
  if (CRON_SECRET && secret !== CRON_SECRET && secret !== 'manual' && !cfWorker) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  const now = new Date().toISOString()

  // Fällige Enrollments laden
  const { data: enrollments, error } = await admin
    .from('drip_enrollments')
    .select(`
      id, user_id, email, current_step, drip_campaign_id,
      drip_campaigns!inner(id, active, name),
      profiles:user_id(name, location, email)
    `)
    .eq('completed', false)
    .lte('next_send_at', now)
    .limit(100)

  if (error) return NextResponse.json({ error: error.message }, { status: 500 })

  let sent = 0
  let skipped = 0

  for (const enrollment of (enrollments ?? [])) {
    const campaign = enrollment.drip_campaigns as { id: string; active: boolean; name: string }
    if (!campaign?.active) { skipped++; continue }

    // Nächsten Step laden
    const { data: step } = await admin
      .from('drip_steps')
      .select('*')
      .eq('drip_campaign_id', enrollment.drip_campaign_id)
      .eq('step_order', enrollment.current_step)
      .maybeSingle()

    if (!step) {
      // Keine weiteren Steps → als abgeschlossen markieren
      await admin.from('drip_enrollments').update({ completed: true }).eq('id', enrollment.id)
      continue
    }

    // Personalisierung
    const prof = enrollment.profiles as { name?: string; location?: string } | null
    const vorname = prof?.name?.split(' ')[0] ?? 'Nachbar'
    const html = step.html_content
      .replace(/\{\{vorname\}\}/gi, vorname)
      .replace(/\{\{name\}\}/gi, prof?.name ?? 'Nachbar')
      .replace(/\{\{stadt\}\}/gi, prof?.location ?? 'deiner Stadt')

    const result = await sendEmail({
      to: enrollment.email,
      subject: step.subject,
      html,
      fromName: 'Mensaena',
    })

    if (result.ok) {
      // Nächsten Step berechnen
      const { data: nextStep } = await admin
        .from('drip_steps')
        .select('delay_days')
        .eq('drip_campaign_id', enrollment.drip_campaign_id)
        .eq('step_order', enrollment.current_step + 1)
        .maybeSingle()

      if (nextStep) {
        const nextSend = new Date()
        nextSend.setDate(nextSend.getDate() + nextStep.delay_days)
        await admin.from('drip_enrollments').update({
          current_step: enrollment.current_step + 1,
          next_send_at: nextSend.toISOString(),
        }).eq('id', enrollment.id)
      } else {
        await admin.from('drip_enrollments').update({ completed: true }).eq('id', enrollment.id)
      }
      sent++
    }
  }

  return NextResponse.json({ ok: true, sent, skipped, total: enrollments?.length ?? 0 })
}

// POST /api/emails/drip/trigger?action=enroll
// Body: { drip_campaign_id, user_id, email }
export async function PUT(req: NextRequest) {
  const body = await req.json().catch(() => ({}))
  const { drip_campaign_id, user_id, email } = body

  if (!drip_campaign_id || !user_id || !email) {
    return NextResponse.json({ error: 'drip_campaign_id, user_id, email required' }, { status: 400 })
  }

  // Ersten Step laden für initial delay
  const { data: firstStep } = await admin
    .from('drip_steps')
    .select('delay_days')
    .eq('drip_campaign_id', drip_campaign_id)
    .eq('step_order', 0)
    .maybeSingle()

  const nextSend = new Date()
  if (firstStep?.delay_days) nextSend.setDate(nextSend.getDate() + firstStep.delay_days)

  const { error } = await admin.from('drip_enrollments').upsert({
    drip_campaign_id,
    user_id,
    email,
    current_step: 0,
    next_send_at: nextSend.toISOString(),
    completed: false,
  }, { onConflict: 'drip_campaign_id,user_id', ignoreDuplicates: true })

  if (error) return NextResponse.json({ error: error.message }, { status: 500 })
  return NextResponse.json({ ok: true })
}
