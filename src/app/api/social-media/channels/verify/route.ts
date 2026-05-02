import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { getApiClient, err } from '@/lib/supabase/api-auth'
import { verifyChannel } from '@/lib/social-media/platforms'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY ?? ''

let _admin: ReturnType<typeof createClient> | null = null
function admin() {
  if (!_admin) _admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { autoRefreshToken: false, persistSession: false } })
  return _admin
}

// POST – Token verifizieren und Verbindungsstatus aktualisieren
export async function POST(req: NextRequest) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()
  const { data: profile } = await supabase
    .from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!profile || !['admin', 'moderator'].includes(profile.role)) {
    return err.forbidden()
  }

  const { platform } = await req.json() as { platform?: string }
  if (!platform) return NextResponse.json({ error: 'platform required' }, { status: 400 })

  // Kanal mit echtem Token laden (via admin client)
  const { data: channel } = await admin()
    .from('social_media_channels')
    .select('*')
    .eq('platform', platform)
    .maybeSingle()

  if (!channel) return NextResponse.json({ error: 'Kanal nicht gefunden' }, { status: 404 })

  const result = await verifyChannel(channel)

  // Status in DB aktualisieren
  await admin()
    .from('social_media_channels')
    .update({
      is_connected: result.ok,
      last_verified: new Date().toISOString(),
    })
    .eq('platform', platform)

  return NextResponse.json({
    ok: result.ok,
    platform,
    info: result.platformPostId || null,
    error: result.error || null,
  })
}
