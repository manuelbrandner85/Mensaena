import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { getApiClient, err } from '@/lib/supabase/api-auth'
import { deleteStorageImages } from '@/lib/social-media/storage'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY ?? ''

let _admin: ReturnType<typeof createClient> | null = null
function admin() {
  if (!_admin) _admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { autoRefreshToken: false, persistSession: false } })
  return _admin
}

// PUT – Post bearbeiten
export async function PUT(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()
  const { data: profile } = await supabase
    .from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!profile || !['admin', 'moderator'].includes(profile.role)) return err.forbidden()

  const { id } = await params
  const body = await req.json() as {
    content?: string
    platforms?: string[]
    hashtags?: string[]
    media_urls?: string[]
    scheduled_at?: string | null
  }

  const { data, error: dbErr } = await supabase
    .from('social_media_posts')
    .update({
      ...(body.content !== undefined && { content: body.content }),
      ...(body.platforms && { platforms: body.platforms }),
      ...(body.hashtags && { hashtags: body.hashtags }),
      ...(body.media_urls !== undefined && { media_urls: body.media_urls }),
      ...(body.scheduled_at !== undefined && {
        scheduled_at: body.scheduled_at,
        status: body.scheduled_at ? 'scheduled' : 'draft',
      }),
    })
    .eq('id', id)
    .in('status', ['draft', 'scheduled'])
    .select()
    .single()

  if (dbErr) return err.internal(dbErr.message)
  if (!data) return err.notFound('Post nicht gefunden oder bereits veröffentlicht')
  return NextResponse.json(data)
}

// DELETE – Post löschen + Bilder aus Supabase Storage entfernen
export async function DELETE(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()
  const { data: profile } = await supabase
    .from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!profile || !['admin', 'moderator'].includes(profile.role)) return err.forbidden()

  const { id } = await params

  // Post laden um media_urls zu bekommen
  const { data: post } = await admin()
    .from('social_media_posts')
    .select('media_urls')
    .eq('id', id)
    .maybeSingle()

  // Bilder aus Supabase Storage löschen
  if (post?.media_urls?.length) {
    await deleteStorageImages(admin, post.media_urls)
  }

  const { error: dbErr } = await admin()
    .from('social_media_posts')
    .delete()
    .eq('id', id)

  if (dbErr) return err.internal(dbErr.message)
  return NextResponse.json({ ok: true })
}
