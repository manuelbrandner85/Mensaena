import { NextRequest, NextResponse } from 'next/server'
import { getApiClient, err } from '@/lib/supabase/api-auth'

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
    scheduled_at?: string | null
  }

  const { data, error: dbErr } = await supabase
    .from('social_media_posts')
    .update({
      ...(body.content !== undefined && { content: body.content }),
      ...(body.platforms && { platforms: body.platforms }),
      ...(body.hashtags && { hashtags: body.hashtags }),
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

// DELETE – Post löschen
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
  const { error: dbErr } = await supabase
    .from('social_media_posts')
    .delete()
    .eq('id', id)

  if (dbErr) return err.internal(dbErr.message)
  return NextResponse.json({ ok: true })
}
