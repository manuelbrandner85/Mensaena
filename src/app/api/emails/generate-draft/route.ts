import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { buildNewsletterEmail } from '@/lib/email/templates/newsletter'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDk4NzExOCwiZXhwIjoyMDkwNTYzMTE4fQ.t09nG5IbpDPAuBuTLuOedep9ZEmi1dcNjD0xsPzFZVQ'
const CRON_SECRET  = process.env.CRON_SECRET || ''
const BASE_URL     = process.env.NEXT_PUBLIC_APP_URL || 'https://www.mensaena.de'

const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
})

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

  // Daten der letzten 7 Tage sammeln
  const since = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString()

  const [postsRes, eventsRes, groupsRes, challengesRes, usersRes] = await Promise.all([
    admin.from('posts').select('title, type').gte('created_at', since).eq('status', 'active').limit(5),
    admin.from('events').select('title, category').gte('created_at', since).limit(5),
    admin.from('groups').select('name, category').gte('created_at', since).limit(4),
    admin.from('challenges').select('title, category').gte('created_at', since).limit(4),
    admin.from('profiles').select('id').gte('created_at', since),
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

  // Freies Thema: KI generiert Sections per AI
  if (freeTopic) {
    let aiBinding: { run: (model: string, input: Record<string, unknown>) => Promise<unknown> } | undefined
    try {
      const { getCloudflareContext } = await import('@opennextjs/cloudflare')
      const ctx = await getCloudflareContext({ async: true })
      aiBinding = (ctx.env as Record<string, unknown>).AI as typeof aiBinding
    } catch {
      aiBinding = (globalThis as Record<string, unknown>).AI as typeof aiBinding
    }

    if (aiBinding?.run) {
      const aiResult = await aiBinding.run('@cf/meta/llama-3.3-70b-instruct-fp8-fast', {
        messages: [
          { role: 'system', content: 'Du bist ein professioneller Newsletter-Autor für Mensaena, eine deutsche Nachbarschaftshilfe-Plattform. Erstelle einen Newsletter auf Deutsch. Antworte NUR mit JSON: {"subject":"...","intro":"...","sections":[{"emoji":"...","title":"...","items":["...","..."]}],"highlightTitle":"...","highlightText":"..."}' },
          { role: 'user', content: `Erstelle einen professionellen Newsletter zum Thema: "${freeTopic}". Der Newsletter soll 3-4 Sections mit je 2-3 Items haben. Betreff soll kurz und ansprechend sein.` },
        ],
        max_tokens: 1500,
      }) as { response?: string }

      try {
        const jsonMatch = (aiResult.response || '').match(/\{[\s\S]*\}/)
        const parsed = JSON.parse(jsonMatch?.[0] || '{}')
        const { subject: aiSubject, html: aiHtml } = buildNewsletterEmail({
          weekLabel: freeTopic,
          intro: parsed.intro || `Newsletter zum Thema: ${freeTopic}`,
          sections: parsed.sections || sections,
          highlightTitle: parsed.highlightTitle,
          highlightText: parsed.highlightText,
          unsubscribeUrl: `${BASE_URL}/unsubscribe?token=UNSUBSCRIBE_URL`,
        })

        const { data, error } = await admin
          .from('email_campaigns')
          .insert({
            type: 'newsletter',
            status: 'draft',
            subject: parsed.subject || aiSubject,
            preview_text: freeTopic,
            html_content: aiHtml,
            auto_generated: true,
          })
          .select().single()

        if (error) return NextResponse.json({ error: error.message }, { status: 500 })
        return NextResponse.json({ ok: true, campaign_id: data.id, subject: data.subject, topic: freeTopic })
      } catch {
        // AI-Parsing fehlgeschlagen → normaler Fallback
      }
    }
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
  const { data, error } = await admin
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
