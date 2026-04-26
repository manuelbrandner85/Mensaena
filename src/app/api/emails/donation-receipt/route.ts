import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { sendEmail } from '@/lib/email/send'
import { buildDonationReceiptEmail } from '@/lib/email/templates/donation-receipt'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDk4NzExOCwiZXhwIjoyMDkwNTYzMTE4fQ.t09nG5IbpDPAuBuTLuOedep9ZEmi1dcNjD0xsPzFZVQ'

const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
})

// ── Auth helper: verify caller is admin ─────────────────────

async function isAdmin(authHeader: string | null): Promise<boolean> {
  if (!authHeader?.startsWith('Bearer ')) return false
  const token = authHeader.slice(7)
  const { data: { user }, error } = await admin.auth.getUser(token)
  if (error || !user) return false
  const { data: profile } = await admin
    .from('profiles')
    .select('role')
    .eq('id', user.id)
    .maybeSingle()
  return profile?.role === 'admin'
}

// ── Sequential receipt number ────────────────────────────────

function generateReceiptNumber(): string {
  const year  = new Date().getFullYear()
  const rand  = Math.floor(Math.random() * 90000) + 10000
  return `SPENDE-${year}-${rand}`
}

// ── POST /api/emails/donation-receipt ───────────────────────

export async function POST(req: NextRequest) {
  // Only admins may send receipts
  if (!await isAdmin(req.headers.get('authorization'))) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  let body: {
    donorName?: string
    donorEmail?: string
    amount?: number
    donationDate?: string
    donorAddress?: string
    receiptNumber?: string
  }

  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ error: 'Invalid body' }, { status: 400 })
  }

  const { donorName, donorEmail, amount, donationDate, donorAddress, receiptNumber } = body

  if (!donorName || !donorEmail || !amount || !donationDate) {
    return NextResponse.json(
      { error: 'donorName, donorEmail, amount and donationDate are required' },
      { status: 400 },
    )
  }

  if (typeof amount !== 'number' || amount <= 0) {
    return NextResponse.json({ error: 'amount must be a positive number' }, { status: 400 })
  }

  const finalReceiptNumber = receiptNumber || generateReceiptNumber()

  const { subject, html } = buildDonationReceiptEmail({
    donorName,
    donorEmail,
    amount,
    donationDate,
    receiptNumber: finalReceiptNumber,
    donorAddress,
  })

  const result = await sendEmail({
    to: donorEmail,
    subject,
    html,
    fromName: 'Mensaena',
  })

  if (!result.ok) {
    return NextResponse.json({ error: result.error }, { status: 500 })
  }

  return NextResponse.json({
    ok: true,
    receiptNumber: finalReceiptNumber,
    sentTo: donorEmail,
  })
}
