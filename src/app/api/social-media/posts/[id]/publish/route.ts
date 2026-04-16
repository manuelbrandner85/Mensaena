import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { getApiClient, err } from '@/lib/supabase/api-auth'
import { publishToChannel } from '@/lib/social-media/platforms'
import { deleteStorageImages } from '@/lib/social-media/storage'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDk4NzExOCwiZXhwIjoyMDkwNTYzMTE4fQ.t09nG5IbpDPAuBuTLuOedep9ZEmi1dcNjD0xsPzFZVQ'

const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
})

// POST – Post an ausgewählte Plattformen veröffentlichen
export async function POST(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()
  const { data: profile } = await supabase
    .from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!profile || !['admin', 'moderator'].includes(profile.role)) return err.forbidden()

  const { id } = await params

  // Post laden
  const { data: post } = await admin
    .from('social_media_posts')
    .select('*')
    .eq('id', id)
    .maybeSingle()

  if (!post) return err.notFound('Post nicht gefunden')
  if (post.status === 'published') return NextResponse.json({ error: 'Bereits veröffentlicht' }, { status: 409 })

  // Status auf "publishing"
  await admin.from('social_media_posts').update({ status: 'publishing' }).eq('id', id)

  // Alle verbundenen Kanäle laden (mit echten Tokens via admin client)
  const { data: channels } = await admin
    .from('social_media_channels')
    .select('*')
    .eq('is_connected', true)
    .in('platform', post.platforms)

  if (!channels?.length) {
    await admin.from('social_media_posts').update({ status: 'failed' }).eq('id', id)
    return NextResponse.json({
      error: 'Keine verbundenen Kanäle für die gewählten Plattformen',
    }, { status: 400 })
  }

  // Content mit Hashtags zusammenbauen
  const hashtags = (post.hashtags || []).map((t: string) => `#${t.replace(/^#/, '')}`).join(' ')
  const fullContent = hashtags ? `${post.content}\n\n${hashtags}` : post.content

  let published = 0
  let failed = 0
  const logs: Array<{
    post_id: string
    platform: string
    status: string
    platform_post_id: string | null
    error_msg: string | null
  }> = []

  for (const channel of channels) {
    const result = await publishToChannel(
      channel,
      fullContent,
      post.media_urls?.[0],
    )

    logs.push({
      post_id: id,
      platform: channel.platform,
      status: result.ok ? 'sent' : 'failed',
      platform_post_id: result.platformPostId || null,
      error_msg: result.ok ? null : (result.error || null),
    })

    if (result.ok) published++
    else failed++

    await new Promise(r => setTimeout(r, 300))
  }

  // Logs speichern
  if (logs.length) {
    await admin.from('social_media_post_logs').insert(logs)
  }

  // Post-Status aktualisieren
  await admin
    .from('social_media_posts')
    .update({
      status: published > 0 ? 'published' : 'failed',
      published_at: published > 0 ? new Date().toISOString() : null,
    })
    .eq('id', id)

  // Nach erfolgreichem Publish: generierte Bilder aus Storage löschen
  if (published > 0 && post.media_urls?.length) {
    await deleteStorageImages(admin, post.media_urls)
  }

  return NextResponse.json({ ok: true, published, failed, total: channels.length })
}
