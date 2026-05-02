import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { sendEmail } from '@/lib/email/send'
import { buildDonationReceiptEmail } from '@/lib/email/templates/donation-receipt'
import { calculateDonorTier } from '@/lib/donorTier'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY ?? ''

let _admin: ReturnType<typeof createClient> | null = null
function admin() {
  if (!_admin) _admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { autoRefreshToken: false, persistSession: false } })
  return _admin
}

// ── Auth helper: verify caller is admin ─────────────────────

async function isAdmin(authHeader: string | null): Promise<boolean> {
  if (!authHeader?.startsWith('Bearer ')) return false
  const token = authHeader.slice(7)
  const { data: { user }, error } = await admin().auth.getUser(token)
  if (error || !user) return false
  const { data: profile } = await admin()
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

// ── Award supporter badge to a user ─────────────────────────

async function awardSupporterBadge(userId: string): Promise<void> {
  const { data: badge } = await admin()
    .from('badges')
    .select('id')
    .eq('requirement_type', 'supporter')
    .maybeSingle()

  if (!badge) return

  await admin()
    .from('user_badges')
    .upsert({ user_id: userId, badge_id: badge.id }, { onConflict: 'user_id,badge_id', ignoreDuplicates: true })
}

// ── Update donor stats + recalculate tier ───────────────────

async function updateDonorStats(userId: string, amount: number): Promise<void> {
  const { data: profile } = await admin()
    .from('profiles')
    .select('donation_count, donation_total')
    .eq('id', userId)
    .maybeSingle()

  const newCount = ((profile?.donation_count as number) ?? 0) + 1
  const newTotal = ((profile?.donation_total as number) ?? 0) + amount
  const newTier  = calculateDonorTier(newCount, newTotal)

  await admin().from('profiles').update({
    donation_count: newCount,
    donation_total: newTotal,
    donor_tier: newTier,
  }).eq('id', userId)
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
    userId?: string
  }

  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ error: 'Invalid body' }, { status: 400 })
  }

  const { donorName, donorEmail, amount, donationDate, donorAddress, receiptNumber, userId } = body

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

  // Award badge + update donor tier if a userId was provided
  if (userId) {
    await awardSupporterBadge(userId)
    await updateDonorStats(userId, amount)
  }

  return NextResponse.json({
    ok: true,
    receiptNumber: finalReceiptNumber,
    sentTo: donorEmail,
    badgeAwarded: !!userId,
  })
}
