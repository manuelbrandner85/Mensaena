// ════════════════════════════════════════════════════════════════════════
// admin-dev-chat — Chatbot-Modus für den Godmode-Dev-Agenten.
//
// Der Admin beschreibt eine Aufgabe in natürlicher Sprache. Statt sofort einen
// Auftrag rauszuschicken, antwortet die KI wie ein Chatbot (wie Claude hier):
// sie präzisiert, fragt ggf. nach, und wenn die Aufgabe klar ist, fasst sie sie
// als konkreten Umsetzungsauftrag zusammen und bittet um Bestätigung (Ja/Nein).
// Erst bei „Ja" ruft der Client admin-dev-agent (createDevTask) auf.
//
// Body: { messages: [{role:'user'|'assistant', content:string}, ...] }
// Antwort: { ok, reply, ready, instruction }
//   ready=true  → die KI hat einen umsetzbaren Auftrag formuliert (instruction).
//
// Nur role='admin'. Nutzt die gemeinsame KI-Kette (_shared/ai.ts).
// ════════════════════════════════════════════════════════════════════════
import { CORS, json, getUser, adminClient } from '../_shared/util.ts'
import { callAiChain, parseAiJson } from '../_shared/ai.ts'

const SYSTEM = `Du bist der Mensaena Dev-Assistent ("Godmode").
Mensaena ist eine Nachbarschaftshilfe-App (Flutter, Deutsch + 6 Sprachen).
Ein Admin beschreibt eine Entwicklungs-Aufgabe (Feature, Bugfix, UI/UX,
Performance, Datenbank, Neuerung). Verhalte dich wie ein Chat-Assistent:
- Antworte freundlich und kurz auf Deutsch.
- Wenn etwas unklar ist, stelle GENAU EINE präzise Rückfrage.
- Wenn die Aufgabe klar genug ist, fasse sie als konkreten, umsetzbaren
  Auftrag für einen Entwickler-Agenten zusammen (mit Dateibezug, wenn möglich)
  und bitte den Admin ausdrücklich um Bestätigung ("Soll ich das so umsetzen?").
- Beachte die Projektregeln: i18n-Pflicht (alle Strings via .tr() in 7 Sprachen),
  Supabase-Stream-Limits, Design teal/primary (keine emerald-Farben).

Antworte AUSSCHLIESSLICH als JSON:
{"reply":"<deine Nachricht auf Deutsch>","ready":<true|false>,"instruction":"<bei ready=true: der vollständige, präzise Auftrag auf Deutsch; sonst leer>"}
ready=true NUR, wenn du einen vollständigen, umsetzbaren Auftrag hast und den
Admin gerade um Bestätigung bittest.`

interface ChatMsg {
  role: string
  content: string
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const user = await getUser(req)
  if (!user) return json({ error: 'unauthorized' }, 401)

  const admin = adminClient()
  const { data: prof } = await admin
    .from('profiles').select('role').eq('id', user.id).maybeSingle()
  if (!prof || prof.role !== 'admin') return json({ error: 'forbidden' }, 403)

  const body = await req.json().catch(() => ({}))
  const rawMsgs: ChatMsg[] = Array.isArray(body?.messages) ? body.messages : []
  const msgs = rawMsgs
    .filter((m) => m && (m.role === 'user' || m.role === 'assistant') && m.content)
    .map((m) => ({ role: m.role, content: String(m.content).slice(0, 4000) }))
    .slice(-12)

  if (msgs.length === 0) return json({ error: 'no_message' }, 400)

  // Letzte User-Nachricht = aktueller Input; Rest = Verlauf.
  const last = msgs[msgs.length - 1]
  const history = msgs.slice(0, -1)

  const { text, provider } = await callAiChain(SYSTEM, last.content, {
    history,
    jsonMode: true,
    timeoutMs: 20_000,
  })

  if (!text) {
    return json({
      ok: true,
      reply: 'Die KI ist gerade nicht erreichbar. Bitte versuch es gleich nochmal.',
      ready: false,
      instruction: '',
      provider: null,
    })
  }

  const parsed = parseAiJson<{ reply?: string; ready?: boolean; instruction?: string }>(text)
  if (!parsed || !parsed.reply) {
    // Fallback: Klartext als Antwort, nicht ready.
    return json({ ok: true, reply: text.slice(0, 1500), ready: false, instruction: '', provider })
  }

  return json({
    ok: true,
    reply: String(parsed.reply).slice(0, 2000),
    ready: parsed.ready === true && !!parsed.instruction,
    instruction: parsed.instruction ? String(parsed.instruction).slice(0, 2000) : '',
    provider,
  })
})
