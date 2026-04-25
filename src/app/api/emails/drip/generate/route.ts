import { NextRequest, NextResponse } from 'next/server'
import { getApiClient, err } from '@/lib/supabase/api-auth'
import Anthropic from '@anthropic-ai/sdk'

// POST /api/emails/drip/generate
// Body: { name, trigger_type, description?, num_steps? }
// Returns: { steps: [{ delay_days, subject, html_content }] }
export async function POST(req: NextRequest) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()
  const { data: profile } = await supabase.from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!profile || !['admin', 'moderator'].includes(profile.role)) return err.forbidden()

  const body = await req.json().catch(() => ({}))
  const { name, trigger_type, description, num_steps = 5 } = body

  if (!trigger_type) return err.bad('trigger_type fehlt')

  const triggerContext: Record<string, string> = {
    on_register: 'Neue Nutzer die sich gerade bei der Nachbarschaftshilfe-Plattform Mensaena registriert haben. Ziel: Onboarding, erste Schritte zeigen, Community-Gefühl aufbauen.',
    on_inactive: 'Nutzer die seit 30+ Tagen inaktiv waren. Ziel: Reaktivierung, Neugier wecken, Anreize zurückzukehren.',
    manual: `Manuell gestarteter Funnel: "${name || 'Kampagne'}". ${description || ''}`,
  }

  const delays: Record<string, number[]> = {
    on_register: [0, 2, 5, 10, 21],
    on_inactive: [0, 3, 7, 14, 30],
    manual: [0, 3, 7, 14, 21],
  }

  const stepDelays = delays[trigger_type] ?? delays.manual
  const steps = Math.min(num_steps, stepDelays.length)

  const prompt = `Du bist ein Email-Marketing-Experte für Mensaena, eine Nachbarschaftshilfe-Plattform.

Erstelle eine Drip-E-Mail-Sequenz für folgenden Kontext:
${triggerContext[trigger_type] ?? trigger_type}
${description ? `Zusätzliche Info: ${description}` : ''}

Erstelle genau ${steps} E-Mails. Die Verzögerungen in Tagen sind: ${stepDelays.slice(0, steps).join(', ')}.

Antworte NUR mit diesem JSON (kein Markdown, keine Erklärungen):
{
  "steps": [
    {
      "delay_days": <Zahl>,
      "subject": "<Betreffzeile mit {{vorname}} Personalisierung>",
      "html_content": "<vollständiges HTML-Email mit <html><body> Tags, Mensaena-Branding (#1EAAA6 teal), freundlicher Ton auf Deutsch, schließe mit: <p><a href='UNSUBSCRIBE_URL'>Abmelden</a></p></body></html>>"
    }
  ]
}`

  try {
    const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY })
    const response = await client.messages.create({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 4000,
      messages: [{ role: 'user', content: prompt }],
    })

    const text = response.content[0]?.type === 'text' ? response.content[0].text.trim() : ''
    const parsed = JSON.parse(text)

    if (!Array.isArray(parsed.steps)) throw new Error('Ungültige KI-Antwort')

    const result = parsed.steps.slice(0, steps).map((s: { delay_days?: number; subject?: string; html_content?: string }, i: number) => ({
      delay_days: typeof s.delay_days === 'number' ? s.delay_days : stepDelays[i] ?? 0,
      subject: String(s.subject || `Schritt ${i + 1}`),
      html_content: String(s.html_content || '<p>Inhalt folgt</p>'),
    }))

    return NextResponse.json({ steps: result })
  } catch {
    return NextResponse.json({ error: 'KI-Generierung fehlgeschlagen' }, { status: 500 })
  }
}
