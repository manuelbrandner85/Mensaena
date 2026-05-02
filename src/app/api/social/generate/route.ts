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

// POST /api/social/generate
// Body: { campaign_id?, subject?, html_content?, platforms? }
// Returns: { post_id, content, hashtags, platforms }
export async function POST(req: NextRequest) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()
  const { data: profile } = await supabase.from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!profile || !['admin', 'moderator'].includes(profile.role)) return err.forbidden()

  const body = await req.json().catch(() => ({}))
  let { subject, html_content, campaign_id } = body
  const platforms: string[] = body.platforms ?? ['facebook', 'instagram']

  // Kampagne nachladen falls nur ID gegeben
  if (campaign_id && (!subject || !html_content)) {
    const { data: campaign } = await admin().from('email_campaigns').select('subject, html_content').eq('id', campaign_id).maybeSingle()
    if (campaign) { subject = campaign.subject; html_content = campaign.html_content }
  }

  if (!subject) return err.bad('subject oder campaign_id erforderlich')

  // HTML zu Plain Text vereinfachen für KI-Kontext
  const plainText = (html_content ?? '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 800)

  const prompt = `Du bist Social-Media-Manager für Mensaena, eine Nachbarschaftshilfe-Plattform.

E-Mail Betreff: "${subject}"
E-Mail Inhalt (Zusammenfassung): "${plainText}"

Erstelle passende Social-Media-Posts für: ${platforms.join(', ')}.

Regeln:
- Facebook: max 500 Zeichen, persönlich, Community-Gefühl
- Instagram: max 300 Zeichen + Emojis, visuell, inspirierend
- Ton: warm, einladend, auf Deutsch
- Keine Links in den Posts

Antworte NUR mit diesem JSON:
{
  "facebook": "<Post-Text für Facebook>",
  "instagram": "<Post-Text für Instagram>",
  "hashtags": ["#Nachbarschaft", "#Mensaena", "<2-3 weitere relevante>"]
}`

  let facebook = ''
  let instagram = ''
  let hashtags: string[] = ['#Nachbarschaft', '#Mensaena', '#Gemeinschaft']

  try {
    const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY })
    const response = await client.messages.create({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 500,
      messages: [{ role: 'user', content: prompt }],
    })
    const text = response.content[0]?.type === 'text' ? response.content[0].text.trim() : ''
    const parsed = JSON.parse(text)
    facebook  = parsed.facebook  ?? ''
    instagram = parsed.instagram ?? ''
    hashtags  = Array.isArray(parsed.hashtags) ? parsed.hashtags : hashtags
  } catch {
    // Fallback
    facebook  = `📢 ${subject} – Jetzt auf Mensaena entdecken!`
    instagram = `✨ ${subject} 🏘️ #Mensaena`
  }

  // Post als Draft in social_media_posts speichern
  const content = platforms.includes('facebook') ? facebook : instagram
  const { data: post, error } = await admin().from('social_media_posts').insert({
    content,
    platforms,
    hashtags,
    status: 'draft',
    auto_generated: true,
    ai_prompt: subject,
    source_campaign_id: campaign_id ?? null,
    created_by: user.id,
  }).select('id').single()

  if (error) return err.internal(error.message)

  return NextResponse.json({
    ok: true,
    post_id: post.id,
    facebook,
    instagram,
    hashtags,
    platforms,
  })
}
