import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { getApiClient, err } from '@/lib/supabase/api-auth'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDk4NzExOCwiZXhwIjoyMDkwNTYzMTE4fQ.t09nG5IbpDPAuBuTLuOedep9ZEmi1dcNjD0xsPzFZVQ'
const UNSPLASH_KEY = process.env.UNSPLASH_ACCESS_KEY || ''

const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
})

// POST /api/social-media/images – Bild generieren oder Stock-Foto suchen
export async function POST(req: NextRequest) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()
  const { data: profile } = await supabase
    .from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!profile || !['admin', 'moderator'].includes(profile.role)) return err.forbidden()

  const { mode, prompt, query } = await req.json() as {
    mode: 'ai' | 'unsplash'
    prompt?: string   // für AI-Generierung
    query?: string    // für Unsplash-Suche
  }

  if (mode === 'ai') {
    return handleAiImage(prompt || 'community neighborhood help platform, friendly, teal colors')
  }

  if (mode === 'unsplash') {
    return handleUnsplash(query || 'community neighborhood')
  }

  return NextResponse.json({ error: 'mode must be "ai" or "unsplash"' }, { status: 400 })
}

// ── KI-Bild via Workers AI ──────────────────────────────────────
async function handleAiImage(prompt: string) {
  const AI_MODEL = '@cf/stabilityai/stable-diffusion-xl-base-1.0'

  // Workers AI Binding via OpenNext Cloudflare Context
  let aiBinding: { run: (model: string, input: Record<string, unknown>) => Promise<unknown> } | undefined
  try {
    const { getCloudflareContext } = await import('@opennextjs/cloudflare')
    const ctx = await getCloudflareContext({ async: true })
    aiBinding = (ctx.env as Record<string, unknown>).AI as typeof aiBinding
  } catch {
    aiBinding = (globalThis as Record<string, unknown>).AI as typeof aiBinding
  }

  if (!aiBinding?.run) {
    return NextResponse.json({
      error: 'KI-Bildgenerierung ist nur auf Cloudflare Workers verfügbar.',
    }, { status: 500 })
  }

  // Prompt auf Englisch optimieren – Mensaena-Markenidentität
  const enhancedPrompt = `Professional social media marketing image for Mensaena, a German neighborhood help community platform. ${prompt}. Style: warm and inviting, teal (#1EAAA6) and white color palette, soft natural lighting, diverse friendly people helping each other, community spirit, modern and clean aesthetic, professional photography quality, instagram-ready, 4k resolution`
  const negativePrompt = 'text, watermark, logo, letters, words, blurry, low quality, distorted, ugly, nsfw, cartoon, anime, dark, depressing, violent, weapons'

  try {
    const result = await aiBinding.run(AI_MODEL, {
      prompt: enhancedPrompt,
      negative_prompt: negativePrompt,
      width: 1024,
      height: 1024,
      num_steps: 20,
    })

    // Result ist ein ArrayBuffer/Uint8Array mit PNG-Daten
    let imageBytes: Uint8Array
    if (result instanceof ReadableStream) {
      const reader = result.getReader()
      const chunks: Uint8Array[] = []
      let done = false
      while (!done) {
        const { value, done: d } = await reader.read()
        if (value) chunks.push(value)
        done = d
      }
      const totalLength = chunks.reduce((sum, c) => sum + c.length, 0)
      imageBytes = new Uint8Array(totalLength)
      let offset = 0
      for (const chunk of chunks) {
        imageBytes.set(chunk, offset)
        offset += chunk.length
      }
    } else if (result instanceof ArrayBuffer) {
      imageBytes = new Uint8Array(result)
    } else {
      imageBytes = result as Uint8Array
    }

    // In Supabase Storage hochladen
    const fileName = `social-media/ai-${Date.now()}.png`
    const { error: uploadErr } = await admin.storage
      .from('public')
      .upload(fileName, imageBytes, {
        contentType: 'image/png',
        upsert: true,
      })

    if (uploadErr) {
      // Falls Bucket nicht existiert, erstellen und nochmal versuchen
      if (uploadErr.message?.includes('not found') || uploadErr.message?.includes('Bucket')) {
        await admin.storage.createBucket('public', { public: true })
        const { error: retryErr } = await admin.storage
          .from('public')
          .upload(fileName, imageBytes, { contentType: 'image/png', upsert: true })
        if (retryErr) {
          return NextResponse.json({ error: `Upload fehlgeschlagen: ${retryErr.message}` }, { status: 500 })
        }
      } else {
        return NextResponse.json({ error: `Upload fehlgeschlagen: ${uploadErr.message}` }, { status: 500 })
      }
    }

    const { data: urlData } = admin.storage.from('public').getPublicUrl(fileName)

    return NextResponse.json({
      ok: true,
      url: urlData.publicUrl,
      source: 'ai',
      prompt: enhancedPrompt,
    })
  } catch (e) {
    return NextResponse.json({
      error: e instanceof Error ? e.message : 'Bildgenerierung fehlgeschlagen',
    }, { status: 500 })
  }
}

// ── Stock-Fotos (Pexels als Fallback, Unsplash mit API-Key) ─────
async function handleUnsplash(query: string) {
  // Fallback ohne Unsplash API-Key: Pexels API (kostenlos, kein Key nötig für Demo)
  if (!UNSPLASH_KEY) {
    // Pexels kostenlose Suche
    try {
      const pexelsRes = await fetch(
        `https://api.pexels.com/v1/search?query=${encodeURIComponent(query + ' community')}&per_page=6&orientation=square`,
        { headers: { 'Authorization': 'ycFymMfQvhBP04MHZqJfG61afHFVvSIPdFG9bLstBHFmwsFNrpuV4Jhv' } },
      )
      if (pexelsRes.ok) {
        const pData = await pexelsRes.json() as {
          photos: Array<{ id: number; src: { medium: string; large: string }; photographer: string; photographer_url: string; alt: string | null }>
        }
        const photos = (pData.photos || []).map(p => ({
          id: String(p.id),
          url: p.src.large,
          thumb: p.src.medium,
          author: p.photographer,
          authorUrl: p.photographer_url,
          alt: p.alt,
        }))
        return NextResponse.json({ ok: true, photos, source: 'pexels' })
      }
    } catch { /* Pexels Fallback fehlgeschlagen */ }

    // Letzter Fallback: Lorem Picsum (Placeholder-Bilder)
    const photos = Array.from({ length: 6 }, (_, i) => ({
      id: `picsum-${i}`,
      url: `https://picsum.photos/seed/${encodeURIComponent(query)}-${i}/1024/1024`,
      thumb: `https://picsum.photos/seed/${encodeURIComponent(query)}-${i}/400/400`,
      author: 'Lorem Picsum',
      authorUrl: 'https://picsum.photos',
    }))
    return NextResponse.json({ ok: true, photos, source: 'unsplash-source' })
  }

  try {
    const searchUrl = `https://api.unsplash.com/search/photos?query=${encodeURIComponent(query)}&per_page=6&orientation=squarish&client_id=${UNSPLASH_KEY}`
    const res = await fetch(searchUrl)
    if (!res.ok) throw new Error(`Unsplash API: ${res.status}`)
    const data = await res.json() as {
      results: Array<{
        id: string
        urls: { regular: string; small: string; thumb: string }
        user: { name: string; links: { html: string } }
        alt_description: string | null
      }>
    }

    const photos = data.results.map(p => ({
      id: p.id,
      url: p.urls.regular,
      thumb: p.urls.small,
      author: p.user.name,
      authorUrl: p.user.links.html,
      alt: p.alt_description,
    }))

    return NextResponse.json({ ok: true, photos, source: 'unsplash' })
  } catch (e) {
    return NextResponse.json({
      error: e instanceof Error ? e.message : 'Unsplash-Suche fehlgeschlagen',
    }, { status: 500 })
  }
}
