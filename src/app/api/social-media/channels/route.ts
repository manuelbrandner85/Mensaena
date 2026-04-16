import { NextRequest, NextResponse } from 'next/server'
import { getApiClient, err } from '@/lib/supabase/api-auth'
import { verifyChannel } from '@/lib/social-media/platforms'

async function requireAdmin() {
  const { supabase, user } = await getApiClient()
  if (!user) return { error: err.unauthorized() }
  const { data: profile } = await supabase
    .from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!profile || !['admin', 'moderator'].includes(profile.role)) {
    return { error: err.forbidden() }
  }
  return { supabase, user }
}

// GET – Alle Kanäle laden (Tokens werden maskiert)
export async function GET() {
  const auth = await requireAdmin()
  if ('error' in auth && auth.error) return auth.error
  const { supabase } = auth as { supabase: ReturnType<typeof getApiClient> extends Promise<infer U> ? U extends { supabase: infer S } ? S : never : never; user: unknown }

  const { supabase: sb } = await getApiClient()
  const { data, error: dbErr } = await sb
    .from('social_media_channels')
    .select('*')
    .order('platform')

  if (dbErr) return err.internal(dbErr.message)

  // Tokens maskieren für Frontend
  const masked = (data ?? []).map(ch => ({
    ...ch,
    access_token: ch.access_token ? '••••' + ch.access_token.slice(-4) : null,
    api_key: ch.api_key ? '••••' + ch.api_key.slice(-4) : null,
    api_secret: ch.api_secret ? '••••' + ch.api_secret.slice(-4) : null,
  }))

  return NextResponse.json(masked)
}

// POST – Kanal erstellen oder aktualisieren
export async function POST(req: NextRequest) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()
  const { data: profile } = await supabase
    .from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!profile || !['admin', 'moderator'].includes(profile.role)) {
    return err.forbidden()
  }

  let body: {
    platform?: string
    label?: string
    access_token?: string
    api_key?: string
    api_secret?: string
    page_id?: string
    config?: Record<string, unknown>
  }
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ error: 'Invalid body' }, { status: 400 })
  }

  if (!body.platform || !['facebook', 'instagram', 'x', 'linkedin', 'pinterest', 'tiktok', 'threads', 'mastodon', 'telegram'].includes(body.platform)) {
    return NextResponse.json({ error: 'Ungültige Plattform' }, { status: 400 })
  }

  // Upsert (one channel per platform)
  const { data, error: dbErr } = await supabase
    .from('social_media_channels')
    .upsert({
      platform: body.platform,
      label: body.label || body.platform,
      access_token: body.access_token || null,
      api_key: body.api_key || null,
      api_secret: body.api_secret || null,
      page_id: body.page_id || null,
      config: body.config || {},
      is_connected: false,
      created_by: user.id,
    }, { onConflict: 'platform' })
    .select()
    .single()

  if (dbErr) return err.internal(dbErr.message)
  return NextResponse.json(data)
}

// DELETE – Kanal entfernen
export async function DELETE(req: NextRequest) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()
  const { data: profile } = await supabase
    .from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!profile || !['admin', 'moderator'].includes(profile.role)) {
    return err.forbidden()
  }

  const platform = req.nextUrl.searchParams.get('platform')
  if (!platform) return NextResponse.json({ error: 'platform required' }, { status: 400 })

  const { error: dbErr } = await supabase
    .from('social_media_channels')
    .delete()
    .eq('platform', platform)

  if (dbErr) return err.internal(dbErr.message)
  return NextResponse.json({ ok: true })
}
