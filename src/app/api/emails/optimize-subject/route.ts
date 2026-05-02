import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { getApiClient, err } from '@/lib/supabase/api-auth'
import Anthropic from '@anthropic-ai/sdk'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY ?? ''

let _admin: ReturnType<typeof createClient> | null = null
function admin() {
  if (!_admin) _admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { autoRefreshToken: false, persistSession: false } })
  return _admin
}

// POST /api/emails/optimize-subject
// Body: { subject: string, preview_text?: string }
// Returns: { score: number, feedback: string, alternatives: string[] }
export async function POST(req: NextRequest) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()
  const { data: profile } = await supabase
    .from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!profile || !['admin', 'moderator'].includes(profile.role)) return err.forbidden()

  const { subject, preview_text } = await req.json().catch(() => ({ subject: '' }))
  if (!subject?.trim()) return err.bad('subject fehlt')

  // Historische Kampagnendaten für Kontext
  const { data: historicalCampaigns } = await admin
    .from('email_campaigns')
    .select('subject, open_count, sent_count')
    .eq('status', 'sent')
    .gt('sent_count', 0)
    .order('sent_at', { ascending: false })
    .limit(10)

  const historicalContext = (historicalCampaigns ?? [])
    .filter((c: { sent_count: number }) => c.sent_count > 0)
    .map((c: { subject: string; open_count: number; sent_count: number }) => {
      const rate = Math.round((c.open_count / c.sent_count) * 100)
      return `"${c.subject}" → ${rate}% Öffnungsrate`
    })
    .join('\n')

  let result: { score: number; feedback: string; alternatives: string[] }

  try {
    const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY })
    const response = await client.messages.create({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 400,
      messages: [{
        role: 'user',
        content: `Du bist ein Email-Marketing-Experte für eine Nachbarschaftshilfe-Plattform (Mensaena.de).

Analysiere diese Betreffzeile:
"${subject}"${preview_text ? `\nVorschautext: "${preview_text}"` : ''}

${historicalContext ? `Bisherige Kampagnen dieser Plattform:\n${historicalContext}\n` : ''}

Antworte NUR mit diesem JSON (kein Markdown, keine Erklärungen):
{
  "score": <0-100, geschätzte Öffnungsrate>,
  "feedback": "<ein Satz auf Deutsch warum>",
  "alternatives": ["<Alternative 1>", "<Alternative 2>", "<Alternative 3>"]
}`,
      }],
    })

    const text = response.content[0]?.type === 'text' ? response.content[0].text.trim() : ''
    const parsed = JSON.parse(text)
    result = {
      score: Math.min(100, Math.max(0, Number(parsed.score) || 30)),
      feedback: String(parsed.feedback || ''),
      alternatives: Array.isArray(parsed.alternatives) ? parsed.alternatives.slice(0, 3).map(String) : [],
    }
  } catch {
    // Fallback ohne AI
    const len = subject.length
    const hasPersonalization = /\{\{/.test(subject)
    const hasNumber = /\d/.test(subject)
    const hasQuestion = /\?/.test(subject)
    const score = Math.min(85, 25 + (len > 20 && len < 50 ? 20 : 0) + (hasPersonalization ? 15 : 0) + (hasNumber ? 10 : 0) + (hasQuestion ? 10 : 0))
    result = {
      score,
      feedback: len > 60 ? 'Betreffzeile zu lang (max. 50 Zeichen empfohlen).' : 'Personalisierung mit {{vorname}} kann die Öffnungsrate um bis zu 26% erhöhen.',
      alternatives: [
        `${subject} – für {{vorname}} in {{stadt}}`,
        `Neu für dich: ${subject}`,
        `${subject} 🏘️`,
      ],
    }
  }

  return NextResponse.json(result)
}
