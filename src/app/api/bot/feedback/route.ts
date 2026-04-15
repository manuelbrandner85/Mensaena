import { NextRequest, NextResponse } from 'next/server'

// Bot-Feedback Endpoint. Aktuell wird ausschließlich auf der Server-Seite
// geloggt (Cloudflare Workers → wrangler tail), ohne DB-Persistenz. Damit
// können wir Daumen-hoch/Daumen-runter-Signale sammeln, ohne gleich eine
// neue Tabelle + Migration zu brauchen. Kann später auf Supabase umgezogen
// werden, indem hier ein Insert in `bot_feedback` ergänzt wird.

export const runtime = 'edge'

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

    console.log('[bot-feedback]', JSON.stringify({
      ts: new Date().toISOString(),
      messageId,
      rating,
      route,
      q: (question ?? '').slice(0, 200),
      a: (answer ?? '').slice(0, 200),
    }))

    return NextResponse.json({ ok: true })
  } catch (err) {
    console.error('bot feedback error:', err)
    return NextResponse.json({ ok: false }, { status: 500 })
  }
}
