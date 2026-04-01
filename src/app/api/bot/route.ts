import { NextRequest, NextResponse } from 'next/server'

const SYSTEM_PROMPT = `Du bist der Mensaena-Bot, der freundliche und hilfreiche Assistent der Mensaena-Plattform.

**Über Mensaena:**
Mensaena (mensaena.de) ist eine deutschsprachige Gemeinwohl-Plattform, die Menschen in ihrer Nachbarschaft vernetzt. Das Motto lautet: "Freiheit beginnt im Bewusstsein."

**Hauptfunktionen der Plattform:**
- 🆘 Hilfe suchen & anbieten (Hilfe-Gesuche und Hilfe-Angebote inserieren)
- 💬 Community-Chat & Direktnachrichten (DMs) mit mehreren Kanälen
- 🗺️ Interaktive Karte mit lokalen Angeboten
- 🐾 Tierhilfe & Tierrettung
- 🏠 Wohnen & Alltag (Wohnungstausch, Alltag)
- 🌾 Regionale Versorgung & Erntehilfe (Bauernhöfe, Bio-Produkte)
- 🚨 Krisensystem & Retter-System für Notfälle
- 📚 Bildung & Wissen teilen
- 🧠 Mentale Unterstützung & Resilienz
- 🔧 Skill-Netzwerk & Zeitbank
- 🚗 Mobilität & Mitfahrgelegenheiten
- 🔄 Teilen & Tauschen
- 👥 Community-Beiträge & Abstimmungen

**Deine Aufgaben:**
1. Fragen über die Mensaena-Plattform beantworten
2. Nutzern helfen, die richtigen Funktionen zu finden
3. Allgemeine Fragen zu Mensch, Tier und Natur beantworten
4. Tipps zu Nachhaltigkeit, Gemeinschaft und Selbstversorgung geben
5. Bei technischen Problemen weiterhelfen

**Dein Stil:**
- Freundlich, warm und empathisch
- Auf Deutsch antworten (außer der Nutzer schreibt auf Englisch)
- Präzise und hilfreich, nicht zu lang
- Emojis sparsam aber passend einsetzen
- Immer konstruktiv und lösungsorientiert`

export async function POST(req: NextRequest) {
  try {
    const { messages } = await req.json()

    if (!messages || !Array.isArray(messages)) {
      return NextResponse.json({ error: 'Invalid request' }, { status: 400 })
    }

    const accountId = process.env.CLOUDFLARE_ACCOUNT_ID || 'accac25964381d7a5200932dac6d270d'
    const apiToken = process.env.CLOUDFLARE_API_TOKEN || 'p4cO2neOtyGQykWkmG2Rl_iVCOO2uW9aIaisVJ48'

    const cfMessages = [
      { role: 'system', content: SYSTEM_PROMPT },
      ...messages.slice(-12).map((m: { role: string; content: string }) => ({
        role: m.role === 'user' ? 'user' : 'assistant',
        content: String(m.content).slice(0, 2000),
      })),
    ]

    const response = await fetch(
      `https://api.cloudflare.com/client/v4/accounts/${accountId}/ai/run/@cf/meta/llama-3.1-8b-instruct`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${apiToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ messages: cfMessages, max_tokens: 800, stream: false }),
      }
    )

    if (!response.ok) {
      const errText = await response.text()
      console.error('CF AI error:', response.status, errText)
      // Fallback: simple rule-based response
      return NextResponse.json({ reply: getFallbackReply(messages[messages.length - 1]?.content ?? '') })
    }

    const data = await response.json() as any
    const reply = data?.result?.response ?? data?.result?.content ?? getFallbackReply('')

    return NextResponse.json({ reply })
  } catch (err) {
    console.error('Bot error:', err)
    return NextResponse.json({
      reply: 'Entschuldigung, ich bin gerade nicht erreichbar. Bitte versuche es später nochmal! 🙏'
    })
  }
}

function getFallbackReply(question: string): string {
  const q = question.toLowerCase()
  if (q.includes('hilfe') || q.includes('help')) return 'Auf Mensaena kannst du Hilfe suchen oder anbieten! Gehe zu "Beitrag erstellen" und wähle den Typ "Hilfe gesucht" oder "Hilfe anbieten". 🤝'
  if (q.includes('chat') || q.includes('nachricht')) return 'Der Community-Chat ist unter /dashboard/chat erreichbar. Du findest dort öffentliche Kanäle (Allgemein, Hilfe, Tiere...) und private Direktnachrichten. 💬'
  if (q.includes('karte') || q.includes('map')) return 'Die interaktive Karte zeigt alle lokalen Angebote in deiner Nähe. Zu finden unter /dashboard/map. 🗺️'
  if (q.includes('tier') || q.includes('animal')) return 'Der Tierbereich hilft bei der Vermittlung und Rettung von Tieren. Zu finden unter /dashboard/animals. 🐾'
  if (q.includes('krise') || q.includes('notfall')) return 'Das Krisensystem ist für dringende Hilfe gedacht. Unter /dashboard/crisis findest du Notfall-Ressourcen und Helfer. 🚨'
  return 'Ich bin der Mensaena-Bot und helfe dir gerne! Frage mich zu Plattform-Funktionen, Gemeinschaft, Natur oder Tieren. Wie kann ich dir helfen? 🌿'
}
