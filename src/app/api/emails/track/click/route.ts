import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY ?? ''

let _admin: ReturnType<typeof createClient> | null = null
function admin() {
  if (!_admin) _admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { autoRefreshToken: false, persistSession: false } })
  return _admin
}

// GET /api/emails/track/click?cid=xxx&email=xxx&url=xxx
// Loggt den Klick und leitet auf die Ziel-URL weiter
export async function GET(req: NextRequest) {
  const campaignId = req.nextUrl.searchParams.get('cid')
  const email = req.nextUrl.searchParams.get('email')
  const url = req.nextUrl.searchParams.get('url')

  if (campaignId && email && url) {
    const ua = req.headers.get('user-agent') || ''
    const ip = req.headers.get('cf-connecting-ip') || req.headers.get('x-forwarded-for')?.split(',')[0] || ''
    const ipHash = ip ? btoa(ip).slice(0, 12) : ''

    void (async () => {
      try {
        await admin().from('email_clicks').insert({
          campaign_id: campaignId,
          email,
          url,
          user_agent: ua.slice(0, 200),
          ip_hash: ipHash,
        })
        await admin().rpc('increment_click_count', { cid: campaignId })
      } catch { /* fire-and-forget */ }
    })()

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return NextResponse.redirect(url, { status: 302 })
    }
  }

  return NextResponse.redirect(process.env.NEXT_PUBLIC_APP_URL || 'https://www.mensaena.de', { status: 302 })
}
