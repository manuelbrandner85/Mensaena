import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { getApiClient, err } from '@/lib/supabase/api-auth'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY ?? ''

let _admin: ReturnType<typeof createClient> | null = null
function admin() {
  if (!_admin) _admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { autoRefreshToken: false, persistSession: false } })
  return _admin
}

// POST /api/social-media/upload – Bild vom Gerät hochladen
export async function POST(req: NextRequest) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()
  const { data: profile } = await supabase
    .from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!profile || !['admin', 'moderator'].includes(profile.role)) return err.forbidden()

  const formData = await req.formData()
  const file = formData.get('file') as File | null

  if (!file) {
    return NextResponse.json({ error: 'Keine Datei hochgeladen' }, { status: 400 })
  }

  // Dateityp prüfen
  if (!file.type.startsWith('image/')) {
    return NextResponse.json({ error: 'Nur Bilder erlaubt (JPG, PNG, WebP)' }, { status: 400 })
  }

  // Max 10MB
  if (file.size > 10 * 1024 * 1024) {
    return NextResponse.json({ error: 'Datei zu groß (max. 10 MB)' }, { status: 400 })
  }

  const ext = file.name.split('.').pop() || 'jpg'
  const fileName = `social-media/upload-${Date.now()}.${ext}`
  const buffer = await file.arrayBuffer()

  const { error: uploadErr } = await admin().storage
    .from('public')
    .upload(fileName, buffer, {
      contentType: file.type,
      upsert: true,
    })

  if (uploadErr) {
    // Bucket erstellen falls nicht vorhanden
    if (uploadErr.message?.includes('not found') || uploadErr.message?.includes('Bucket')) {
      await admin().storage.createBucket('public', { public: true })
      const { error: retryErr } = await admin().storage
        .from('public')
        .upload(fileName, buffer, { contentType: file.type, upsert: true })
      if (retryErr) {
        return NextResponse.json({ error: `Upload: ${retryErr.message}` }, { status: 500 })
      }
    } else {
      return NextResponse.json({ error: `Upload: ${uploadErr.message}` }, { status: 500 })
    }
  }

  const { data: urlData } = admin().storage.from('public').getPublicUrl(fileName)

  return NextResponse.json({ ok: true, url: urlData.publicUrl })
}
