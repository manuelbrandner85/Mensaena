import { NextRequest, NextResponse } from 'next/server'
import { getApiClient } from '@/lib/supabase/api-auth'

// Bot-Feedback Endpoint. Persistiert 👍/👎-Signale in public.bot_feedback
// (RLS: anyone can insert, only admins can read). Anonyme Nutzer bekommen
// user_id=null — so bleibt das Feedback offen für Gäste. Wir loggen zusätzlich
// in `wrangler tail`, damit operativ schnell sichtbar ist, ob etwas reinläuft.

interface FeedbackBody {
  messageId?: string
  rating?: 'up' | 'down'
  question?: string
  answer?: string
  route?: string
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json() as FeedbackBody
    const { messageId, rating, question, answer, route } = body

    if (rating !== 'up' && rating !== 'down') {
      return NextResponse.json({ ok: false, error: 'invalid rating' }, { status: 400 })
    }

    // User aus dem Supabase-Cookie — darf fehlen (anonymes Feedback ist ok)
    let userId: string | null = null
    try {
      const { user } = await getApiClient()
      userId = user?.id ?? null
    } catch (err) {
      console.warn('[bot-feedback] getApiClient failed:', err)
    }

    console.log('[bot-feedback]', JSON.stringify({
      ts: new Date().toISOString(),
      userId,
      messageId,
      rating,
      route,
      q: (question ?? '').slice(0, 200),
      a: (answer ?? '').slice(0, 200),
    }))

    try {
      const { supabase } = await getApiClient()
      const { error } = await supabase.from('bot_feedback').insert({
        user_id: userId,
        message_id: messageId ?? null,
        rating,
        question: (question ?? '').slice(0, 2000),
        answer: (answer ?? '').slice(0, 4000),
        route: route ?? null,
      })
      if (error) {
        // Niemals die UI brechen — nur loggen.
        console.error('[bot-feedback] insert failed:', error.message)
      }
    } catch (err) {
      console.error('[bot-feedback] supabase error:', err)
    }

    return NextResponse.json({ ok: true })
  } catch (err) {
    console.error('bot feedback error:', err)
    return NextResponse.json({ ok: false }, { status: 500 })
  }
}
