/* ═══════════════════════════════════════════════════════════════════════
   SEND EMAIL – Supabase Edge Function
   Versendet E-Mails via SMTP (mail.lima-city.de:465).

   Environment Secrets (in Supabase Dashboard → Edge Functions → Secrets):
     SMTP_HOST     = mail.lima-city.de
     SMTP_PORT     = 465
     SMTP_USER     = Info@online.de  (oder deine Adresse)
     SMTP_PASSWORD = <dein SMTP-Passwort>
     SMTP_FROM     = Info@mensaena.de (Absenderadresse)

   Aufruf: POST /functions/v1/send-email
   Auth:   Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>
   Body:   { to, subject, html, fromName? }
   ═══════════════════════════════════════════════════════════════════════ */

// @ts-nocheck
import { serve } from 'https://deno.land/std@0.208.0/http/server.ts'

// ── CORS ────────────────────────────────────────────────────────────────
const ALLOWED_ORIGINS = ['https://mensaena.de', 'https://www.mensaena.de']

function corsHeaders(origin: string | null) {
  const allowed = origin && ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0]
  return {
    'Access-Control-Allow-Origin': allowed,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey',
  }
}

// ── SMTP Config aus Deno.env ────────────────────────────────────────────
const SMTP_HOST     = Deno.env.get('SMTP_HOST')     ?? 'mail.lima-city.de'
const SMTP_PORT     = parseInt(Deno.env.get('SMTP_PORT') ?? '465', 10)
const SMTP_USER     = Deno.env.get('SMTP_USER')     ?? ''
const SMTP_PASSWORD = Deno.env.get('SMTP_PASSWORD') ?? ''
const SMTP_FROM     = Deno.env.get('SMTP_FROM')     ?? SMTP_USER
const SERVICE_KEY   = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

// ── SMTP via Base64-encoded raw SMTP over TLS ───────────────────────────
// Wir nutzen den Deno smtp Client von deno.land/x
async function sendSmtpEmail(opts: {
  to: string
  subject: string
  html: string
  fromName: string
}) {
  // Dynamischer Import des SMTP-Clients
  const { SMTPClient } = await import('https://deno.land/x/denomailer@1.6.0/mod.ts')

  const client = new SMTPClient({
    connection: {
      hostname: SMTP_HOST,
      port: SMTP_PORT,
      tls: true,
      auth: {
        username: SMTP_USER,
        password: SMTP_PASSWORD,
      },
    },
  })

  await client.send({
    from: `${opts.fromName} <${SMTP_FROM}>`,
    to: opts.to,
    subject: opts.subject,
    html: opts.html,
  })

  await client.close()
}

// ── Handler ─────────────────────────────────────────────────────────────
serve(async (req: Request) => {
  const origin = req.headers.get('origin')
  const cors = corsHeaders(origin)

  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: cors })
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method Not Allowed' }), {
      status: 405, headers: { ...cors, 'Content-Type': 'application/json' },
    })
  }

  // Auth prüfen: nur mit Service Role Key
  const authHeader = req.headers.get('Authorization') ?? ''
  const token = authHeader.replace(/^Bearer\s+/i, '')
  if (!SERVICE_KEY || token !== SERVICE_KEY) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401, headers: { ...cors, 'Content-Type': 'application/json' },
    })
  }

  let body: { to?: string; subject?: string; html?: string; fromName?: string }
  try {
    body = await req.json()
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON body' }), {
      status: 400, headers: { ...cors, 'Content-Type': 'application/json' },
    })
  }

  const { to, subject, html, fromName = 'Mensaena' } = body

  if (!to || !subject || !html) {
    return new Response(JSON.stringify({ error: 'to, subject and html are required' }), {
      status: 400, headers: { ...cors, 'Content-Type': 'application/json' },
    })
  }

  // Sende E-Mail
  try {
    await sendSmtpEmail({ to, subject, html, fromName })
    return new Response(JSON.stringify({ ok: true }), {
      status: 200, headers: { ...cors, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err)
    console.error('[send-email] SMTP error:', msg)
    return new Response(JSON.stringify({ ok: false, error: msg }), {
      status: 500, headers: { ...cors, 'Content-Type': 'application/json' },
    })
  }
})
