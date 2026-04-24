import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDk4NzExOCwiZXhwIjoyMDkwNTYzMTE4fQ.t09nG5IbpDPAuBuTLuOedep9ZEmi1dcNjD0xsPzFZVQ'

const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
})

// Transparentes 1x1 Pixel (GIF)
const PIXEL = Buffer.from('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7', 'base64')

// GET /api/emails/track/open?cid=xxx&email=xxx
// Tracking-Pixel: wird in E-Mail als <img> eingebettet
export async function GET(req: NextRequest) {
  const campaignId = req.nextUrl.searchParams.get('cid')
  const email = req.nextUrl.searchParams.get('email')

  if (campaignId && email) {
    const ua = req.headers.get('user-agent') || ''
    const ip = req.headers.get('cf-connecting-ip') || req.headers.get('x-forwarded-for')?.split(',')[0] || ''
    // IP hashen (Datenschutz)
    const ipHash = ip ? btoa(ip).slice(0, 12) : ''

    // Öffnung loggen (fire-and-forget)
    void (async () => {
      try {
        await admin.from('email_opens').insert({
          campaign_id: campaignId,
          email,
          user_agent: ua.slice(0, 200),
          ip_hash: ipHash,
        })
        await admin.rpc('increment_open_count', { cid: campaignId })
      } catch { /* fire-and-forget */ }
    })()
  }

  return new NextResponse(PIXEL, {
    status: 200,
    headers: {
      'Content-Type': 'image/gif',
      'Cache-Control': 'no-store, no-cache, must-revalidate, max-age=0',
    },
  })
}
