import { NextRequest, NextResponse } from 'next/server'

const CATEGORIES = [
  'nachbarschaftshilfe', 'lebensmittelrettung', 'tierschutz', 'wohnen',
  'mobilität', 'teilen', 'gesundheit', 'bildung', 'umwelt', 'gemeinschaft',
  'krise', 'senioren', 'kinder', 'handwerk', 'general',
]

// POST /api/posts/ai-assist – KI-gesteuerte Beitrags-Vorschläge
export async function POST(req: NextRequest) {
  const { input, type } = await req.json() as { input?: string; type?: string }
  if (!input?.trim()) {
    return NextResponse.json({ error: 'Eingabe fehlt' }, { status: 400 })
  }

  // Workers AI Binding versuchen
  let aiBinding: { run: (model: string, opts: Record<string, unknown>) => Promise<unknown> } | undefined
  try {
    const { getCloudflareContext } = await import('@opennextjs/cloudflare')
    const ctx = await getCloudflareContext({ async: true })
    aiBinding = (ctx.env as Record<string, unknown>).AI as typeof aiBinding
  } catch {
    aiBinding = (globalThis as Record<string, unknown>).AI as typeof aiBinding
  }

  if (aiBinding?.run) {
    try {
      const result = await aiBinding.run('@cf/meta/llama-3.3-70b-instruct-fp8-fast', {
        messages: [
          { role: 'system', content: `Du bist ein Assistent für Mensaena, eine deutsche Nachbarschaftshilfe-Plattform. Hilf beim Erstellen von Beiträgen. Antworte NUR mit JSON: {"titles":["...","...","..."],"description":"...","category":"..."}. Kategorie muss eine von: ${CATEGORIES.join(', ')} sein.` },
          { role: 'user', content: `Erstelle 3 Titel-Vorschläge, eine passende Beschreibung (2-3 Sätze, freundlich, konkret) und empfiehl eine Kategorie für diesen Beitrag: "${input}". Beitragstyp: ${type || 'allgemein'}. Zeitstempel: ${Date.now()}` },
        ],
        max_tokens: 500,
      }) as { response?: string }

      const jsonMatch = (result.response || '').match(/\{[\s\S]*\}/)
      if (jsonMatch) {
        const parsed = JSON.parse(jsonMatch[0])
        return NextResponse.json({
          titles: parsed.titles || [],
          description: parsed.description || '',
          category: parsed.category || '',
        })
      }
    } catch (e) {
      console.warn('[ai-assist] AI failed:', e)
    }
  }

  // Fallback ohne KI
  const t = input.toLowerCase()
  let category = 'general'
  if (t.includes('einkauf') || t.includes('hilfe') || t.includes('unterstütz')) category = 'nachbarschaftshilfe'
  else if (t.includes('essen') || t.includes('lebensmittel') || t.includes('kochen')) category = 'lebensmittelrettung'
  else if (t.includes('tier') || t.includes('hund') || t.includes('katze')) category = 'tierschutz'
  else if (t.includes('wohn') || t.includes('zimmer') || t.includes('unterkunft')) category = 'wohnen'
  else if (t.includes('fahr') || t.includes('transport') || t.includes('mitfahr')) category = 'mobilität'
  else if (t.includes('kind') || t.includes('baby') || t.includes('schule')) category = 'kinder'
  else if (t.includes('senior') || t.includes('älter') || t.includes('rente')) category = 'senioren'

  return NextResponse.json({
    titles: [
      `${input} – Nachbarschaftshilfe gesucht`,
      `Wer kann helfen? ${input}`,
      `${input} in meiner Nachbarschaft`,
    ],
    description: `Ich suche Unterstützung zum Thema "${input}". Wenn du in der Nähe bist und helfen kannst, melde dich gerne bei mir. Gemeinsam schaffen wir das!`,
    category,
  })
}
