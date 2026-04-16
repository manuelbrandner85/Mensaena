import { NextRequest, NextResponse } from 'next/server'
import { getApiClient, err } from '@/lib/supabase/api-auth'

// GET – Alle Posts laden
export async function GET() {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()
  const { data: profile } = await supabase
    .from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!profile || !['admin', 'moderator'].includes(profile.role)) return err.forbidden()

  const { data, error: dbErr } = await supabase
    .from('social_media_posts')
    .select('*, social_media_post_logs(*)')
    .order('created_at', { ascending: false })
    .limit(100)

  if (dbErr) return err.internal(dbErr.message)
  return NextResponse.json(data ?? [])
}

// POST – Neuen Post erstellen
export async function POST(req: NextRequest) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()
  const { data: profile } = await supabase
    .from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!profile || !['admin', 'moderator'].includes(profile.role)) return err.forbidden()

  const body = await req.json() as {
    content?: string
    platforms?: string[]
    hashtags?: string[]
    media_urls?: string[]
    scheduled_at?: string
    auto_generated?: boolean
    ai_prompt?: string
  }

  if (!body.content) {
    return NextResponse.json({ error: 'content required' }, { status: 400 })
  }

  const { data, error: dbErr } = await supabase
    .from('social_media_posts')
    .insert({
      content: body.content,
      platforms: body.platforms || [],
      hashtags: body.hashtags || [],
      media_urls: body.media_urls || [],
      scheduled_at: body.scheduled_at || null,
      status: body.scheduled_at ? 'scheduled' : 'draft',
      auto_generated: body.auto_generated || false,
      ai_prompt: body.ai_prompt || null,
      created_by: user.id,
    })
    .select()
    .single()

  if (dbErr) return err.internal(dbErr.message)
  return NextResponse.json(data)
}
