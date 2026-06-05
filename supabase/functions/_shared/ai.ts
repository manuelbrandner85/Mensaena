// ════════════════════════════════════════════════════════════════════════
// _shared/ai.ts — gemeinsame KI-Fallback-Kette für ALLE Mensaena-Functions.
//
// Reihenfolge = Versuchsreihenfolge. Pro Anbieter Timeout (Default 12s).
// Bei Fehler/Rate-Limit/leerer Antwort -> nächster Anbieter.
//
// DATENSCHUTZ: Manche Gratis-Modelle nutzen Eingaben evtl. zum Training.
// Deshalb stehen gemini + groq (Training deaktivierbar / restriktiver) BEWUSST
// zuerst. Alle Schlüssel NUR aus Deno.env (Supabase Secrets) — nie im Repo.
// ════════════════════════════════════════════════════════════════════════

type ProviderFormat = 'gemini' | 'openai'
interface Provider {
  id: string
  format: ProviderFormat
  model: string
  keyEnv: string
  url: string
}

// Modellnamen als Konfig — sie ändern sich. Cerebras "llama-3.3-70b" ist
// aktuell bestätigt; bei "model not found" inference-docs.cerebras.ai/models.
export const AI_PROVIDERS: Provider[] = [
  {
    id: 'gemini',
    format: 'gemini',
    model: 'gemini-2.5-flash',
    keyEnv: 'GEMINI_API_KEY',
    url: 'https://generativelanguage.googleapis.com/v1beta/models/<model>:generateContent?key=<key>',
  },
  {
    id: 'groq',
    format: 'openai',
    model: 'llama-3.3-70b-versatile',
    keyEnv: 'GROQ_API_KEY',
    url: 'https://api.groq.com/openai/v1/chat/completions',
  },
  {
    id: 'cerebras',
    format: 'openai',
    model: 'llama-3.3-70b',
    keyEnv: 'CEREBRAS_API_KEY',
    url: 'https://api.cerebras.ai/v1/chat/completions',
  },
  {
    id: 'openrouter',
    format: 'openai',
    model: 'openrouter/free',
    keyEnv: 'OPENROUTER_API_KEY',
    url: 'https://openrouter.ai/api/v1/chat/completions',
  },
]

export interface AiOpts {
  timeoutMs?: number
  jsonMode?: boolean
  history?: { role: string; content: string }[]
}
export interface AiResult {
  text: string
  provider: string | null
}

/// Ruft die Anbieter-Kette der Reihe nach. Liefert erste nicht-leere Antwort.
export async function callAiChain(
  systemPrompt: string,
  userContent: string,
  opts: AiOpts = {},
): Promise<AiResult> {
  const timeoutMs = opts.timeoutMs ?? 12_000
  const history = (opts.history ?? []).filter(
    (m) => m && (m.role === 'user' || m.role === 'assistant') && m.content,
  )

  for (const p of AI_PROVIDERS) {
    const key = Deno.env.get(p.keyEnv)
    if (!key) continue
    const ctrl = new AbortController()
    const timer = setTimeout(() => ctrl.abort(), timeoutMs)
    try {
      let text = ''
      if (p.format === 'gemini') {
        const url = p.url.replace('<model>', p.model).replace('<key>', key)
        const contents = [
          ...history.map((m) => ({
            role: m.role === 'assistant' ? 'model' : 'user',
            parts: [{ text: m.content.toString().slice(0, 4000) }],
          })),
          { role: 'user', parts: [{ text: userContent }] },
        ]
        const body: Record<string, unknown> = {
          system_instruction: { parts: [{ text: systemPrompt }] },
          contents,
        }
        if (opts.jsonMode) {
          body.generationConfig = { responseMimeType: 'application/json' }
        }
        const r = await fetch(url, {
          method: 'POST',
          signal: ctrl.signal,
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(body),
        })
        if (!r.ok) throw new Error(`gemini ${r.status}`)
        const j = await r.json()
        text = j?.candidates?.[0]?.content?.parts?.[0]?.text ?? ''
      } else {
        const messages = [
          { role: 'system', content: systemPrompt },
          ...history.map((m) => ({
            role: m.role,
            content: m.content.toString().slice(0, 4000),
          })),
          { role: 'user', content: userContent },
        ]
        const body: Record<string, unknown> = { model: p.model, messages }
        if (opts.jsonMode) body.response_format = { type: 'json_object' }
        const r = await fetch(p.url, {
          method: 'POST',
          signal: ctrl.signal,
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${key}`,
          },
          body: JSON.stringify(body),
        })
        if (!r.ok) throw new Error(`${p.id} ${r.status}`)
        const j = await r.json()
        text = j?.choices?.[0]?.message?.content ?? ''
      }
      if (text && text.trim()) return { text: text.trim(), provider: p.id }
    } catch (_) {
      // fehlgeschlagen/Timeout/Rate-Limit -> nächster Anbieter
    } finally {
      clearTimeout(timer)
    }
  }
  return { text: '', provider: null }
}

/// Robustes JSON-Parsing für jsonMode-Antworten (entfernt ```json-Fences etc.).
export function parseAiJson<T>(raw: string): T | null {
  if (!raw) return null
  let s = raw.trim()
  const fence = s.match(/```(?:json)?\s*([\s\S]*?)```/)
  if (fence) s = fence[1].trim()
  const a = s.indexOf('{')
  const b = s.lastIndexOf('}')
  if (a >= 0 && b > a) s = s.slice(a, b + 1)
  try {
    return JSON.parse(s) as T
  } catch (_) {
    return null
  }
}
