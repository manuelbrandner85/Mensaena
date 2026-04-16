import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { getApiClient, err } from '@/lib/supabase/api-auth'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDk4NzExOCwiZXhwIjoyMDkwNTYzMTE4fQ.t09nG5IbpDPAuBuTLuOedep9ZEmi1dcNjD0xsPzFZVQ'
const CF_ACCOUNT_ID = process.env.CLOUDFLARE_ACCOUNT_ID || ''
const CF_API_TOKEN  = process.env.CLOUDFLARE_API_TOKEN || ''

const dbAdmin = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
})

const AI_MODEL = '@cf/meta/llama-3.3-70b-instruct-fp8-fast'

// POST – KI-generierte Social-Media-Beiträge
export async function POST(req: NextRequest) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()
  const { data: profile } = await supabase
    .from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!profile || !['admin', 'moderator'].includes(profile.role)) return err.forbidden()

  const { platforms, topic } = await req.json() as {
    platforms?: string[]
    topic?: string
  }

  const selectedPlatforms = platforms?.length ? platforms : ['facebook', 'instagram', 'x', 'linkedin']

  // Aktuelle Plattform-Aktivität laden (letzte 7 Tage)
  const since = new Date()
  since.setDate(since.getDate() - 7)
  const sinceISO = since.toISOString()

  const [postsRes, eventsRes, membersRes] = await Promise.all([
    dbAdmin.from('posts').select('title, category').gte('created_at', sinceISO).limit(10),
    dbAdmin.from('events').select('title').gte('created_at', sinceISO).limit(5),
    dbAdmin.from('profiles').select('id', { count: 'exact', head: true }),
  ])

  const recentPosts = (postsRes.data ?? []).map(p => `- ${p.title} (${p.category})`).join('\n')
  const recentEvents = (eventsRes.data ?? []).map(e => `- ${e.title}`).join('\n')
  const memberCount = membersRes.count ?? 0

  const activityContext = `
Aktuelle Plattform-Daten (letzte 7 Tage):
- ${memberCount} registrierte Mitglieder
${recentPosts ? `Neue Beiträge:\n${recentPosts}` : 'Keine neuen Beiträge'}
${recentEvents ? `Neue Events:\n${recentEvents}` : 'Keine neuen Events'}
${topic ? `\nGewünschtes Thema: ${topic}` : ''}
`

  const systemPrompt = `Du bist ein professioneller Social-Media-Manager für Mensaena – eine deutsche Nachbarschaftshilfe-Plattform (www.mensaena.de).

Deine Aufgabe: Erstelle professionelle, ansprechende Social-Media-Beiträge auf Deutsch.

Markenidentität:
- Name: Mensaena
- Claim: "Freiheit beginnt im Bewusstsein"
- Werte: Gemeinschaft, Nachhilfe, Nachhaltigkeit, lokales Handeln
- Ton: Warm, einladend, professionell, nicht werblich
- Farbe: Teal (#1EAAA6)

Regeln:
- Verwende passende Emojis (nicht überladen)
- Füge relevante Hashtags hinzu
- Passe den Stil an die jeweilige Plattform an
- Erwähne immer www.mensaena.de
- Keine erfundenen Statistiken oder Features

Antworte AUSSCHLIESSLICH im folgenden JSON-Format (keine Erklärungen, kein Markdown):
{
  "posts": [
    {
      "platform": "facebook",
      "content": "...",
      "hashtags": ["nachbarschaftshilfe", "mensaena", ...]
    }
  ]
}`

  const userPrompt = `Erstelle je einen professionellen Social-Media-Beitrag für diese Plattformen: ${selectedPlatforms.join(', ')}.

${activityContext}

Wichtig:
- Facebook: 2-4 Absätze, Emojis, Call-to-Action
- Instagram: Knackige Caption, viele Hashtags (bis 30)
- X/Twitter: Max 250 Zeichen (Platz für Link), knackig und einladend
- LinkedIn: Professioneller Ton, Business-orientiert

Antworte NUR mit validem JSON.`

  try {
    let responseText = ''

    // Workers AI Binding via OpenNext Cloudflare Context
    let aiBinding: { run: (model: string, input: Record<string, unknown>) => Promise<unknown> } | undefined
    try {
      const { getCloudflareContext } = await import('@opennextjs/cloudflare')
      const ctx = await getCloudflareContext({ async: true })
      aiBinding = (ctx.env as Record<string, unknown>).AI as typeof aiBinding
    } catch {
      // Fallback: globalThis (ältere Versionen)
      aiBinding = (globalThis as Record<string, unknown>).AI as typeof aiBinding
    }

    if (aiBinding?.run) {
      const result = await aiBinding.run(AI_MODEL, {
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt },
        ],
        max_tokens: 2000,
      }) as { response?: string }
      responseText = result?.response || ''
    }
    // REST API Fallback (lokale Entwicklung)
    else if (CF_ACCOUNT_ID && CF_API_TOKEN) {
      const aiRes = await fetch(
        `https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT_ID}/ai/run/${AI_MODEL}`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${CF_API_TOKEN}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            messages: [
              { role: 'system', content: systemPrompt },
              { role: 'user', content: userPrompt },
            ],
            max_tokens: 2000,
            stream: false,
          }),
        },
      )
      if (!aiRes.ok) throw new Error(`AI API: ${await aiRes.text()}`)
      const aiData = await aiRes.json() as { result?: { response?: string }; errors?: Array<{ message: string }> }
      if (aiData.errors?.length) throw new Error(aiData.errors[0].message)
      responseText = aiData.result?.response || ''
    } else {
      return NextResponse.json({
        error: 'Workers AI nicht verfügbar. Bitte auf Cloudflare Workers deployen.',
      }, { status: 500 })
    }

    if (!responseText) {
      return NextResponse.json({ error: 'KI hat keine Antwort generiert' }, { status: 500 })
    }

    // JSON aus Antwort extrahieren
    let parsed: { posts: Array<{ platform: string; content: string; hashtags?: string[] }> }
    try {
      const jsonMatch = responseText.match(/\{[\s\S]*\}/)
      parsed = JSON.parse(jsonMatch?.[0] || responseText)
    } catch {
      return NextResponse.json({
        error: 'KI-Antwort konnte nicht als JSON gelesen werden',
        raw: responseText,
      }, { status: 500 })
    }

    return NextResponse.json({
      ok: true,
      posts: parsed.posts || [],
      activity: {
        posts: postsRes.data?.length ?? 0,
        events: eventsRes.data?.length ?? 0,
        members: memberCount,
      },
    })
  } catch (e) {
    return NextResponse.json({
      error: e instanceof Error ? e.message : 'AI-Fehler',
    }, { status: 500 })
  }
}
