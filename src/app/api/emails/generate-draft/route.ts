import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { buildNewsletterEmail } from '@/lib/email/templates/newsletter'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY ?? ''
const CRON_SECRET  = process.env.CRON_SECRET || ''
const BASE_URL     = process.env.NEXT_PUBLIC_APP_URL || 'https://www.mensaena.de'

let _admin: ReturnType<typeof createClient> | null = null
function admin() {
  if (!_admin) _admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { autoRefreshToken: false, persistSession: false } })
  return _admin
}

function getWeekLabel(): string {
  const now = new Date()
  // Wochennummer (ISO)
  const jan4 = new Date(now.getFullYear(), 0, 4)
  const week = Math.ceil(((now.getTime() - jan4.getTime()) / 86400000 + jan4.getDay() + 1) / 7)
  // Wochenbeginn (Montag) und -ende (Sonntag)
  const day = now.getDay() || 7
  const monday = new Date(now)
  monday.setDate(now.getDate() - day + 1)
  const sunday = new Date(monday)
  sunday.setDate(monday.getDate() + 6)
  const fmt = (d: Date) =>
    `${d.getDate()}.${d.getMonth() + 1}.${d.getFullYear()}`
  return `KW ${week} · ${fmt(monday)}–${fmt(sunday)}`
}

// POST /api/emails/generate-draft – Wöchentlichen Newsletter-Entwurf generieren
// Gesichert per CRON_SECRET Header oder intern via Cloudflare Cron Trigger
export async function POST(req: NextRequest) {
  // Auth: Cloudflare Cron sendet keinen Auth-Header, stattdessen CF-Worker-Header
  // Zusätzlich kann CRON_SECRET gesetzt werden
  const secret = req.headers.get('x-cron-secret')
  const cfWorker = req.headers.get('x-cloudflare-worker')

  if (CRON_SECRET && secret !== CRON_SECRET && secret !== 'manual' && !cfWorker) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  // Optionales freies Thema
  let freeTopic = ''
  try {
    const body = await req.json().catch(() => ({}))
    freeTopic = (body?.topic as string) || ''
  } catch { /* kein Body */ }

  // ── Freies Thema: eigener Pfad, Return Early ──────────────
  if (freeTopic) {
    let aiSections: Array<{ emoji: string; title: string; items: string[] }> | null = null
    let aiSubjectLine = ''
    let aiIntro = ''
    let aiHighlightTitle = ''
    let aiHighlightText = ''

    // KI versuchen
    let aiBinding: { run: (model: string, input: Record<string, unknown>) => Promise<unknown> } | undefined
    try {
      const { getCloudflareContext } = await import('@opennextjs/cloudflare')
      const ctx = await getCloudflareContext({ async: true })
      aiBinding = (ctx.env as Record<string, unknown>).AI as typeof aiBinding
    } catch {
      aiBinding = (globalThis as Record<string, unknown>).AI as typeof aiBinding
    }

    if (aiBinding?.run) {
      try {
        const aiResult = await aiBinding.run('@cf/meta/llama-3.3-70b-instruct-fp8-fast', {
          messages: [
            { role: 'system', content: `Du bist ein professioneller Newsletter-Autor für Mensaena, eine deutsche Nachbarschaftshilfe-Plattform. Erstelle einen einzigartigen, kreativen Newsletter auf Deutsch zum gegebenen Thema. Jeder Newsletter muss anders sein! Antworte NUR mit validem JSON: {"subject":"...","intro":"...","sections":[{"emoji":"...","title":"...","items":["...","..."]}],"highlightTitle":"...","highlightText":"..."}` },
            { role: 'user', content: `Erstelle einen professionellen, einzigartigen Newsletter zum Thema: "${freeTopic}". Sei kreativ und abwechslungsreich. 3-4 Sections mit je 2-3 konkreten, thematisch passenden Items. Betreff soll kurz, einladend und einzigartig sein. Timestamp für Einzigartigkeit: ${Date.now()}` },
          ],
          max_tokens: 1500,
        }) as { response?: string }

        const jsonMatch = (aiResult.response || '').match(/\{[\s\S]*\}/)
        if (jsonMatch) {
          const parsed = JSON.parse(jsonMatch[0])
          aiSections = parsed.sections
          aiSubjectLine = parsed.subject || ''
          aiIntro = parsed.intro || ''
          aiHighlightTitle = parsed.highlightTitle || ''
          aiHighlightText = parsed.highlightText || ''
        }
      } catch (e) {
        console.warn('[generate-draft] AI failed for free topic:', e)
      }
    }

    // Fallback ohne KI: themenspezifische Inhalte generieren
    if (!aiSections) {
      const t = freeTopic.toLowerCase()
      // Themen-Kategorien erkennen und passende Inhalte generieren
      if (t.includes('sommer') || t.includes('hitze') || t.includes('grillen') || t.includes('freibad')) {
        aiSubjectLine = `Sommer in der Nachbarschaft: ${freeTopic} ☀️`
        aiIntro = `Der Sommer ist da! Hier sind Ideen, wie du <strong>${freeTopic}</strong> mit deinen Nachbarn erleben kannst:`
        aiSections = [
          { emoji: '☀️', title: 'Sommer-Aktivitäten', items: ['Nachbarschafts-Grillabend organisieren', 'Gemeinsamer Ausflug ins Freibad oder an den See', 'Straßenfest oder Hofflohmarkt planen'] },
          { emoji: '🌿', title: 'Garten & Natur', items: ['Gemeinschaftsgarten-Treffen starten', 'Gießdienst für Nachbarn im Urlaub anbieten', 'Kräuter und Gemüse tauschen'] },
          { emoji: '🍉', title: 'Gemeinsam genießen', items: ['Eis-Nachmittag für Familien im Hof', 'Sommerliche Rezepte teilen', 'Picknick im Park organisieren'] },
        ]
      } else if (t.includes('winter') || t.includes('weihnacht') || t.includes('advent') || t.includes('schnee') || t.includes('kalt')) {
        aiSubjectLine = `Winterzeit bei Mensaena: ${freeTopic} ❄️`
        aiIntro = `In der kalten Jahreszeit ist Nachbarschaftshilfe besonders wichtig. Hier sind Ideen rund um <strong>${freeTopic}</strong>:`
        aiSections = [
          { emoji: '❄️', title: 'Winterhilfe', items: ['Schneeschippen für ältere Nachbarn anbieten', 'Gemeinsamer Winterspaziergang', 'Warme Mahlzeiten für Bedürftige kochen'] },
          { emoji: '🎄', title: 'Gemeinschaft erleben', items: ['Nachbarschafts-Adventskalender organisieren', 'Gemeinsames Plätzchen-Backen', 'Weihnachtsmarkt-Besuch als Gruppe'] },
          { emoji: '💝', title: 'Füreinander da sein', items: ['Einsame Nachbarn zum Kaffee einladen', 'Wunschbaum-Aktion für Kinder starten', 'Winterkleidung spenden und tauschen'] },
        ]
      } else if (t.includes('sicher') || t.includes('schutz') || t.includes('einbruch') || t.includes('notfall')) {
        aiSubjectLine = `Sicherheit in der Nachbarschaft: ${freeTopic} 🔒`
        aiIntro = `Sicherheit geht uns alle an. Hier sind wichtige Informationen zum Thema <strong>${freeTopic}</strong>:`
        aiSections = [
          { emoji: '🔒', title: 'Prävention', items: ['Aufmerksame Nachbarschaft: aufeinander achten', 'Beleuchtung und Sichtbarkeit verbessern', 'Notfallnummern austauschen'] },
          { emoji: '🤝', title: 'Gemeinsam sicher', items: ['Nachbarschafts-Whatsapp-Gruppe für Sicherheit', 'Gegenseitige Briefkasten-Leerung im Urlaub', 'Verdächtiges Verhalten gemeinsam melden'] },
          { emoji: '📞', title: 'Im Notfall', items: ['Polizei: 110 · Feuerwehr: 112', 'Mensaena Krisenmodul nutzen', 'Erste-Hilfe-Kurs in der Nachbarschaft'] },
        ]
      } else if (t.includes('kinder') || t.includes('familie') || t.includes('eltern') || t.includes('jugend') || t.includes('schule')) {
        aiSubjectLine = `Familien & Kinder: ${freeTopic} 👨‍👩‍👧‍👦`
        aiIntro = `Familien sind das Herzstück jeder Nachbarschaft. Entdecke Möglichkeiten rund um <strong>${freeTopic}</strong>:`
        aiSections = [
          { emoji: '👶', title: 'Für Familien', items: ['Spielgruppen und Babysitter-Netzwerk aufbauen', 'Kinderkleidung und Spielzeug tauschen', 'Gemeinsame Spielplatz-Nachmittage'] },
          { emoji: '📚', title: 'Lernen & Wachsen', items: ['Nachhilfe unter Nachbarn organisieren', 'Lese-Patenschaften für Kinder', 'Talente teilen: Musikunterricht, Basteln, Sport'] },
          { emoji: '🎉', title: 'Zusammen feiern', items: ['Kinderfeste im Innenhof planen', 'Ferienaktionen für Nachbarschaftskinder', 'Laternenumzug oder Ostereiersuche'] },
        ]
      } else if (t.includes('umwelt') || t.includes('nachhaltig') || t.includes('klima') || t.includes('müll') || t.includes('recycl') || t.includes('bio')) {
        aiSubjectLine = `Nachhaltigkeit: ${freeTopic} 🌍`
        aiIntro = `Gemeinsam für eine bessere Zukunft! Hier sind Aktionen und Tipps zum Thema <strong>${freeTopic}</strong>:`
        aiSections = [
          { emoji: '♻️', title: 'Im Alltag', items: ['Repair-Café in der Nachbarschaft starten', 'Gemeinsame Müllsammel-Aktion organisieren', 'Unverpackt-Einkauf als Gruppe'] },
          { emoji: '🌱', title: 'Grüne Nachbarschaft', items: ['Bienen-freundliche Balkone gestalten', 'Gemeinschaftsgarten oder Urban Gardening', 'Regenwasser sammeln und teilen'] },
          { emoji: '🚲', title: 'Mobilität', items: ['Fahrrad-Werkstatt im Hinterhof', 'Fahrgemeinschaften bilden', 'Lastenrad für die Nachbarschaft anschaffen'] },
        ]
      } else if (t.includes('gesund') || t.includes('sport') || t.includes('fitness') || t.includes('yoga') || t.includes('wohlbefinden') || t.includes('mental')) {
        aiSubjectLine = `Gesundheit & Wohlbefinden: ${freeTopic} 💪`
        aiIntro = `Gesundheit beginnt in der Gemeinschaft. Entdecke Angebote rund um <strong>${freeTopic}</strong>:`
        aiSections = [
          { emoji: '🏃', title: 'Aktiv werden', items: ['Lauftreff oder Walking-Gruppe gründen', 'Yoga im Park mit Nachbarn', 'Gemeinsame Fitness-Challenge starten'] },
          { emoji: '🧘', title: 'Mentale Gesundheit', items: ['Gesprächsrunden für Austausch organisieren', 'Achtsamkeits-Spaziergänge in der Natur', 'Einsamkeit bekämpfen: offene Türen'] },
          { emoji: '🥗', title: 'Gesund leben', items: ['Kochkurse mit regionalen Zutaten', 'Gesunde Rezepte in der Community teilen', 'Obstbäume und Kräuter gemeinsam ernten'] },
        ]
      } else if (t.includes('tier') || t.includes('hund') || t.includes('katze') || t.includes('haustier')) {
        aiSubjectLine = `Tierfreunde aufgepasst: ${freeTopic} 🐾`
        aiIntro = `Tierliebhaber in der Nachbarschaft, vereinigt euch! Alles zum Thema <strong>${freeTopic}</strong>:`
        aiSections = [
          { emoji: '🐕', title: 'Gemeinsam für Tiere', items: ['Gassi-Gemeinschaft für Hundebesitzer', 'Katzensitter-Netzwerk in der Nachbarschaft', 'Tierfutter-Spenden sammeln'] },
          { emoji: '🏠', title: 'Tierschutz', items: ['Tierheim-Besuche als Gruppe organisieren', 'Futterplätze für Wildvögel aufstellen', 'Igel-freundliche Gärten gestalten'] },
          { emoji: '❤️', title: 'Verantwortung', items: ['Tier-Notfall-Kontakte austauschen', 'Urlaubsbetreuung gegenseitig anbieten', 'Erfahrungen und Tierarzt-Tipps teilen'] },
        ]
      } else if (t.includes('kochen') || t.includes('essen') || t.includes('rezept') || t.includes('food') || t.includes('küche')) {
        aiSubjectLine = `Kulinarisches: ${freeTopic} 🍳`
        aiIntro = `Essen verbindet! Entdecke leckere Ideen rund um <strong>${freeTopic}</strong> in deiner Nachbarschaft:`
        aiSections = [
          { emoji: '👨‍🍳', title: 'Gemeinsam kochen', items: ['Nachbarschafts-Kochclub gründen', 'Kulturelle Kochabende: Rezepte aus aller Welt', 'Suppen-Sonntag für den ganzen Block'] },
          { emoji: '🥧', title: 'Teilen & Tauschen', items: ['Überschüssige Ernte mit Nachbarn teilen', 'Marmeladen- und Einmach-Workshop', 'Gemeinsamer Einkauf beim Bauernhof'] },
          { emoji: '📖', title: 'Rezepte & Inspiration', items: ['Nachbarschafts-Kochbuch zusammenstellen', 'Lieblings-Rezepte in der Community posten', 'Saisonale Menüs gemeinsam planen'] },
        ]
      } else {
        // Generischer aber trotzdem sinnvoller Fallback
        aiSubjectLine = `Mensaena-News: ${freeTopic} 🌿`
        aiIntro = `Wir haben spannende Neuigkeiten zum Thema <strong>${freeTopic}</strong> für dich zusammengestellt:`
        aiSections = [
          { emoji: '📢', title: `${freeTopic} – Was gibt es Neues?`, items: [
            `Aktuelle Beiträge und Diskussionen rund um "${freeTopic}" in der Community`,
            'Neue Ideen und Vorschläge von deinen Nachbarn',
            'Erfahrungsberichte und Best Practices',
          ]},
          { emoji: '💡', title: 'So kannst du mitmachen', items: [
            `Teile deine eigenen Erfahrungen zu "${freeTopic}" als Beitrag`,
            'Gründe eine Gruppe für Gleichgesinnte',
            'Biete dein Wissen in der Zeitbank an',
          ]},
          { emoji: '🗓️', title: 'Nächste Schritte', items: [
            `Erstelle ein Event zum Thema "${freeTopic}" in deiner Nachbarschaft`,
            'Vernetze dich über die Karte mit Nachbarn in deiner Nähe',
            'Nutze den Chat für schnellen Austausch',
          ]},
        ]
        aiHighlightTitle = `Werde aktiv zu "${freeTopic}"!`
        aiHighlightText = 'Deine Nachbarschaft wartet auf deine Ideen. Starte jetzt einen Beitrag oder tritt einer Gruppe bei.'
      }
    }

    const { subject, html } = buildNewsletterEmail({
      weekLabel: freeTopic,
      intro: aiIntro,
      sections: aiSections,
      highlightTitle: aiHighlightTitle || undefined,
      highlightText: aiHighlightText || undefined,
      unsubscribeUrl: `${BASE_URL}/unsubscribe?token=UNSUBSCRIBE_URL`,
    })

    const { data, error } = await admin()
      .from('email_campaigns')
      .insert({
        type: 'newsletter',
        status: 'draft',
        subject: aiSubjectLine || subject,
        preview_text: freeTopic,
        html_content: html,
        auto_generated: true,
      })
      .select().single()

    if (error) return NextResponse.json({ error: error.message }, { status: 500 })
    return NextResponse.json({ ok: true, campaign_id: data.id, subject: data.subject, topic: freeTopic })
  }

  // ── Wochenrückblick: Daten der letzten 7 Tage sammeln ─────
  const since = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString()

  const [postsRes, eventsRes, groupsRes, challengesRes, usersRes] = await Promise.all([
    admin().from('posts').select('title, type').gte('created_at', since).eq('status', 'active').limit(5),
    admin().from('events').select('title, category').gte('created_at', since).limit(5),
    admin().from('groups').select('name, category').gte('created_at', since).limit(4),
    admin().from('challenges').select('title, category').gte('created_at', since).limit(4),
    admin().from('profiles').select('id').gte('created_at', since),
  ])

  const newUsers    = usersRes.data?.length ?? 0
  const newPosts    = postsRes.data?.length ?? 0
  const newEvents   = eventsRes.data?.length ?? 0
  const newGroups   = groupsRes.data?.length ?? 0
  const newChallenges = challengesRes.data?.length ?? 0

  // Sections aufbauen
  const sections = []

  if (newPosts > 0) {
    sections.push({
      emoji: '📝',
      title: `${newPosts} neue Beiträge in der Community`,
      items: (postsRes.data ?? []).map(p =>
        p.title ? `${p.title} (${p.type})` : `Neuer ${p.type}-Beitrag`
      ),
    })
  }

  if (newEvents > 0) {
    sections.push({
      emoji: '📅',
      title: `${newEvents} neue Events & Veranstaltungen`,
      items: (eventsRes.data ?? []).map(e =>
        e.title ? `${e.title}` : `Neue Veranstaltung (${e.category})`
      ),
    })
  }

  if (newGroups > 0) {
    sections.push({
      emoji: '👥',
      title: `${newGroups} neue Gruppen gegründet`,
      items: (groupsRes.data ?? []).map(g =>
        g.name ? `${g.name} (${g.category})` : `Neue ${g.category}-Gruppe`
      ),
    })
  }

  if (newChallenges > 0) {
    sections.push({
      emoji: '🏆',
      title: `${newChallenges} neue Challenges`,
      items: (challengesRes.data ?? []).map(c =>
        c.title ? c.title : `Neue ${c.category}-Challenge`
      ),
    })
  }

  // Fallback wenn wenig Aktivität
  if (sections.length === 0) {
    sections.push({
      emoji: '🌱',
      title: 'Die Community wächst weiter',
      items: [
        'Schau vorbei und entdecke aktuelle Hilfsangebote in deiner Umgebung',
        'Trage dich für die Zeitbank ein und tausche deine Fähigkeiten',
        'Finde lokale Events und Aktionen in deiner Stadt',
      ],
    })
  }

  const weekLabel = getWeekLabel()
  const intro = newUsers > 0
    ? `Diese Woche sind <strong>${newUsers} neue Mitglieder</strong> zu Mensaena gestoßen. Hier ist, was in deiner Nachbarschaft passiert ist:`
    : 'Hier ist eine Zusammenfassung der Aktivitäten in deiner Mensaena-Community diese Woche:'

  const { subject, html } = buildNewsletterEmail({
    weekLabel,
    intro,
    sections,
    highlightTitle: newUsers > 5 ? `${newUsers} neue Mitglieder diese Woche!` : undefined,
    highlightText: newUsers > 5
      ? 'Die Mensaena-Community wächst. Heiß die Neuen willkommen und vernetze dich.'
      : undefined,
    // Platzhalter – wird beim Senden personalisiert ersetzt
    unsubscribeUrl: `${BASE_URL}/unsubscribe?token=UNSUBSCRIBE_URL`,
  })

  // Als Entwurf speichern
  const { data, error } = await admin()
    .from('email_campaigns')
    .insert({
      type: 'newsletter',
      status: 'draft',
      subject,
      preview_text: `Mensaena Wochennews · ${weekLabel}`,
      html_content: html,
      auto_generated: true,
    })
    .select()
    .single()

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 })
  }

  // Re-Engagement Followups verarbeiten (fällige Mails senden)
  try {
    const followupUrl = new URL('/api/emails/process-followups', BASE_URL)
    await fetch(followupUrl.toString(), {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-cron-secret': CRON_SECRET,
      },
    })
  } catch (e) {
    console.warn('[generate-draft] followup processing failed:', e)
  }

  return NextResponse.json({
    ok: true,
    campaign_id: data.id,
    subject: data.subject,
    week: weekLabel,
  })
}
