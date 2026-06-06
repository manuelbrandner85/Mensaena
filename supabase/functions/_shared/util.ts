// ════════════════════════════════════════════════════════════════════════
// _shared/util.ts — gemeinsame Helfer für alle KI-Functions.
// CORS, JSON-Response, Auth (getUser), Rate-Limit, Analytics-Logging.
// ════════════════════════════════════════════════════════════════════════
import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2'

export const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

export const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const ANON = Deno.env.get('SUPABASE_ANON_KEY') ?? ''

/// Admin-Client (service_role, bypassed RLS) — für Reads/Writes serverseitig.
export function adminClient(): SupabaseClient {
  return createClient(SUPABASE_URL, SERVICE_ROLE, {
    auth: { persistSession: false },
  })
}

/// Nutzer aus dem Auth-Token. null wenn nicht eingeloggt.
export async function getUser(req: Request) {
  const authHeader = req.headers.get('Authorization') ?? ''
  const c = createClient(SUPABASE_URL, ANON, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  })
  const { data } = await c.auth.getUser()
  return data?.user ?? null
}

/// Eigenes Rate-Limit je Aktion. true = erlaubt.
export async function checkRate(
  admin: SupabaseClient,
  uid: string,
  action: string,
  maxPerMinute: number,
  maxPerHour: number,
): Promise<boolean> {
  try {
    const { data } = await admin.rpc('check_rate_limit', {
      p_user_id: uid,
      p_action: action,
      p_max_per_hour: maxPerHour,
      p_max_per_minute: maxPerMinute,
    })
    return data !== false // fail-open bei null/Fehler
  } catch (_) {
    return true
  }
}

/// Analytics-Insert (NUR Metadaten, kein Klartext). feature = welche Funktion.
export async function logAi(
  admin: SupabaseClient,
  opts: {
    userId: string | null
    feature: string
    provider?: string | null
    navKey?: string | null
    hadKnowledge?: boolean
    lang?: string
  },
) {
  try {
    await admin.from('ai_chat_analytics').insert({
      user_id: opts.userId,
      feature: opts.feature,
      provider: opts.provider ?? null,
      nav_key: opts.navKey ?? null,
      had_knowledge: opts.hadKnowledge ?? false,
      lang: opts.lang ?? 'de',
    })
  } catch (_) {
    // best-effort
  }
}

/// Freundliche Rate-Limit-Meldung (DE).
export const RATE_LIMIT_MSG =
  'Einen kurzen Moment bitte 🌱 Du hast die KI gerade oft genutzt — ' +
  'versuch es in einer Minute noch einmal.'
