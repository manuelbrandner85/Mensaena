import { NextRequest, NextResponse } from 'next/server'

const SYSTEM_PROMPT = `Du bist der Mensaena-Bot – der freundliche, empathische und kompetente Assistent der Mensaena-Plattform.

**Über Mensaena:**
Mensaena (mensaena.de) ist eine deutschsprachige Gemeinwohl-Plattform, die Menschen lokal vernetzt. Motto: "Freiheit beginnt im Bewusstsein."

**Hauptfunktionen:**
- 🆘 Hilfe suchen & anbieten – Hilfegesuche und Hilfsangebote inserieren
- 💬 Community-Chat mit Kanälen & private Direktnachrichten (DMs)
- 🗺️ Interaktive Karte mit lokalen Angeboten in der Nähe
- 🐾 Tierhilfe & Tierrettung – Tiere vermitteln und retten
- 🏠 Wohnen & Alltag – Wohnungstausch, Alltagshilfe
- 🌾 Regionale Versorgung – Bauernhöfe, Bio-Produkte, Erntehilfe
- 🚨 Krisensystem & Retter-System für Notfälle
- 📚 Bildung & Wissen teilen
- 🧠 Mentale Unterstützung & Resilienz
- 🔧 Skill-Netzwerk & Zeitbank
- 🚗 Mobilität & Mitfahrgelegenheiten
- 🔄 Teilen & Tauschen
- 👥 Community-Beiträge & Abstimmungen

**Dashboard-Bereiche:**
- /dashboard – Übersicht
- /dashboard/chat – Community Chat & DMs
- /dashboard/map – Interaktive Karte
- /dashboard/posts – Beiträge & Hilfegesuche
- /dashboard/animals – Tierhilfe
- /dashboard/crisis – Krisensystem
- /dashboard/supply – Versorgung & Bauernhöfe
- /dashboard/sharing – Teilen & Tauschen
- /dashboard/skills – Skill-Netzwerk
- /dashboard/timebank – Zeitbank
- /dashboard/rescuer – Retter-System
- /dashboard/profile – Profil
- /dashboard/settings – Einstellungen

**Deine Aufgaben:**
1. Fragen zur Mensaena-Plattform beantworten
2. Nutzern helfen, die richtigen Funktionen zu finden
3. Allgemeine Fragen zu Mensch, Tier und Natur kompetent beantworten
4. Tipps zu Nachhaltigkeit, Gemeinschaft, Selbstversorgung und Ökologie geben
5. Bei Fragen zu Gesundheit, Psychologie, Umwelt, Tieren informieren
6. Freundlich und verständlich auf Deutsch antworten

**Stil:**
- Freundlich, warm, empathisch und klar
- Auf Deutsch (außer der Nutzer schreibt auf Englisch)
- Präzise – nicht zu lang, aber vollständig
- Emojis passend und sparsam
- Immer konstruktiv und lösungsorientiert
- Bei ernsten Themen (Krise, psychische Gesundheit) besonders einfühlsam`

interface CFMessage {
  role: string
  content: string
}

// Try Workers AI binding (deployed on Cloudflare Workers)
async function runWithBinding(ai: any, messages: CFMessage[]): Promise<string> {
  const result = await ai.run('@cf/meta/llama-3.1-8b-instruct', {
    messages,
    max_tokens: 900,
    temperature: 0.7,
  })
  const text = result?.response ?? result?.result?.response ?? result?.content ?? ''
  if (!text) throw new Error('Empty response from AI binding')
  return text
}

// Fallback: Cloudflare REST API (used only in local dev when AI binding unavailable)
async function runWithREST(messages: CFMessage[]): Promise<string> {
  const accountId = process.env.CLOUDFLARE_ACCOUNT_ID
  const apiToken = process.env.CLOUDFLARE_API_TOKEN

  if (!accountId || !apiToken) throw new Error('CF credentials not configured')

  const res = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${accountId}/ai/run/@cf/meta/llama-3.1-8b-instruct`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ messages, max_tokens: 900, stream: false }),
    }
  )

  if (!res.ok) {
    const errText = await res.text().catch(() => res.status.toString())
    throw new Error(`CF AI REST ${res.status}: ${errText}`)
  }

  const data = await res.json() as any
  const text = data?.result?.response ?? data?.result?.content ?? ''
  if (!text) throw new Error('Empty REST response')
  return text
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json()
    const { messages } = body

    if (!messages || !Array.isArray(messages) || messages.length === 0) {
      return NextResponse.json({ error: 'Invalid request' }, { status: 400 })
    }

    const cfMessages: CFMessage[] = [
      { role: 'system', content: SYSTEM_PROMPT },
      ...messages.slice(-14).map((m: { role: string; content: string }) => ({
        role: m.role === 'user' ? 'user' : 'assistant',
        content: String(m.content ?? '').slice(0, 2500),
      })),
    ]

    let reply = ''

    // Try Workers AI binding first (only available when running on Cloudflare Workers)
    try {
      // @ts-ignore – injected by Cloudflare Workers runtime
      const aiBinding = (globalThis as any).AI
      if (aiBinding && typeof aiBinding.run === 'function') {
        reply = await runWithBinding(aiBinding, cfMessages)
      }
    } catch (bindErr) {
      console.error('Workers AI binding failed:', bindErr)
    }

    // Fallback to REST API
    if (!reply) {
      try {
        reply = await runWithREST(cfMessages)
      } catch (restErr) {
        console.error('CF AI REST failed:', restErr)
      }
    }

    // Final fallback: rule-based response
    if (!reply) {
      reply = getFallbackReply(messages[messages.length - 1]?.content ?? '')
    }

    return NextResponse.json({ reply })
  } catch (err) {
    console.error('Bot route error:', err)
    return NextResponse.json({
      reply: 'Entschuldigung, ich bin gerade nicht erreichbar. Bitte versuche es gleich nochmal! 🙏',
    })
  }
}

function getFallbackReply(question: string): string {
  const q = question.toLowerCase()

  // Platform-specific
  if (q.includes('hilfe') || q.includes('help') || q.includes('assist'))
    return 'Auf Mensaena kannst du Hilfe suchen und anbieten! Gehe zu **Beiträge** und wähle "Hilfe gesucht" oder "Hilfe angeboten". 🤝'
  if (q.includes('chat') || q.includes('nachricht') || q.includes('dm'))
    return 'Den Community-Chat findest du unter **/dashboard/chat**. Dort gibt es öffentliche Kanäle und private Direktnachrichten. 💬'
  if (q.includes('karte') || q.includes('map') || q.includes('karten'))
    return 'Die interaktive Karte unter **/dashboard/map** zeigt alle lokalen Angebote und Hilfegesuche in deiner Nähe. 🗺️'
  if (q.includes('tier') || q.includes('animal') || q.includes('hund') || q.includes('katze'))
    return 'Der Tierbereich unter **/dashboard/animals** hilft bei der Vermittlung und Rettung von Tieren. Erstelle einen Beitrag, um Hilfe anzubieten oder zu suchen. 🐾'
  if (q.includes('krise') || q.includes('notfall') || q.includes('sos'))
    return 'Das Krisensystem unter **/dashboard/crisis** bietet schnelle Hilfe bei Notfällen. Retter sind in deiner Nähe registriert. 🚨'
  if (q.includes('registr') || q.includes('konto erstellen') || q.includes('account'))
    return 'Erstelle ein kostenloses Konto unter **/register**. Es dauert nur 2 Minuten! ✨'
  if (q.includes('passwort') || q.includes('einloggen') || q.includes('login') || q.includes('anmeld'))
    return 'Melde dich unter **/login** an. Passwort vergessen? Nutze den "Passwort zurücksetzen"-Link. 🔑'
  if (q.includes('versorgung') || q.includes('bauernhof') || q.includes('bio') || q.includes('ernte'))
    return 'Im Versorgungsbereich unter **/dashboard/supply** findest du regionale Bauernhöfe, Bio-Produkte und Erntehilfe-Angebote. 🌾'
  if (q.includes('teilen') || q.includes('tauschen') || q.includes('verschenken'))
    return 'Teile oder tausche Gegenstände unter **/dashboard/sharing**. Nachhaltig und kostenlos! 🔄'
  if (q.includes('skill') || q.includes('zeitbank') || q.includes('fähigkeit'))
    return 'Im Skill-Netzwerk und der Zeitbank unter **/dashboard/skills** und **/dashboard/timebank** kannst du Fähigkeiten teilen und Zeit tauschen. 🔧'

  // Nature, animals, health topics
  if (q.includes('natur') || q.includes('umwelt') || q.includes('öko') || q.includes('klima'))
    return 'Mensaena fördert nachhaltiges Leben: Ressourcen teilen, lokal handeln, Gemeinschaft stärken. Schau in die Bereiche Versorgung und Teilen & Tauschen! 🌿'
  if (q.includes('mental') || q.includes('psyche') || q.includes('stress') || q.includes('depression'))
    return 'Für mentale Unterstützung gibt es den Bereich **/dashboard/mental-support**. Dort findest du Ressourcen und Menschen, die helfen. Du bist nicht allein. 💙'
  if (q.includes('nachhalt') || q.includes('ressource'))
    return 'Mensaena ist eine komplett kostenlose und werbefreie Plattform. Nachhaltigkeit ist ein Kernwert – daher Teilen, Tauschen und lokale Vernetzung statt Konsum. 🌱'

  // General
  if (q.includes('was ist mensaena') || q.includes('mensaena erkl') || q.includes('plattform'))
    return 'Mensaena ist eine deutschsprachige Gemeinwohl-Plattform, die Menschen lokal vernetzt. Hilfe finden und geben, Tiere schützen, Ressourcen teilen – alles kostenlos und ohne Werbung. 🌍'
  if (q.includes('kosten') || q.includes('bezahl') || q.includes('preis') || q.includes('gratis') || q.includes('kostenlos'))
    return 'Mensaena ist **100% kostenlos** – jetzt und in Zukunft. Keine versteckten Kosten, keine Werbung. ✅'

  return 'Ich bin der Mensaena-Bot und helfe gerne! Frag mich zu Plattform-Funktionen, Gemeinschaft, Natur, Tieren oder allgemeinen Themen. 🌿'
}
