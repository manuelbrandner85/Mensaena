/* ═══════════════════════════════════════════════════════════════════════
   SEND EMAIL – Supabase Edge Function
   Versendet E-Mails primär via Resend (HTTP API, Domain hallo@mensaena.de),
   Fallback SMTP (Lima-City). Resend wurde gewählt, weil:
     • DNS-only Setup (SPF/DKIM/DMARC bei Cloudflare hinterlegen)
     • Webhooks für open/click/bounce (Tracking ohne eigene Infrastruktur)
     • Großzügiges Free-Tier für Nonprofit-Volumen
     • Bessere Zustellraten als generischer SMTP

   Environment Secrets (Supabase Dashboard → Edge Functions → Secrets):
     MAIL_API_KEY   = re_xxx  (Resend API Key, BEVORZUGT)
     MAIL_FROM      = "Mensaena <hallo@mensaena.de>" (Default)
     -- Fallback SMTP (genutzt nur wenn MAIL_API_KEY fehlt) --
     SMTP_HOST/PORT/USER/PASSWORD/SMTP_FROM

   Aufruf: POST /functions/v1/send-email
   Auth:   Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>
   Body:   { to, subject, html, text?, fromName?, category? }
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

// ── Config ───────────────────────────────────────────────────────────────
const MAIL_API_KEY = Deno.env.get('MAIL_API_KEY') ?? ''
const MAIL_FROM    = Deno.env.get('MAIL_FROM')    ?? 'Mensaena <hallo@mensaena.de>'
const SMTP_HOST     = Deno.env.get('SMTP_HOST')     ?? 'mail.lima-city.de'
const SMTP_PORT     = parseInt(Deno.env.get('SMTP_PORT') ?? '465', 10)
const SMTP_USER     = Deno.env.get('SMTP_USER')     ?? ''
const SMTP_PASSWORD = Deno.env.get('SMTP_PASSWORD') ?? ''
const SMTP_FROM     = Deno.env.get('SMTP_FROM')     ?? SMTP_USER
const SERVICE_KEY   = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

// Pflicht-Footer (DSGVO): Absender + Abmeldung + Impressum.
function appendFooter(html: string, category?: string) {
  const unsub = category === 'reactivation'
    ? 'https://www.mensaena.de/unsubscribe?kind=reactivation'
    : 'https://www.mensaena.de/unsubscribe?kind=marketing'
  return `${html}<hr style="margin:32px 0;border:0;border-top:1px solid #e6e3df"><p style="font-size:12px;color:#6b665e;line-height:1.5">Mensaena · <a href="mailto:info@mensaena.de" style="color:#6b665e">info@mensaena.de</a> · <a href="https://www.mensaena.de/impressum" style="color:#6b665e">Impressum</a> · <a href="${unsub}" style="color:#6b665e">Abmelden</a></p>`
}

async function sendViaResend(opts: {
  to: string; subject: string; html: string; text?: string; from: string; category?: string
}) {
  const r = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${MAIL_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: opts.from,
      to: opts.to,
      subject: opts.subject,
      html: opts.html,
      text: opts.text,
      tags: opts.category ? [{ name: 'category', value: opts.category }] : undefined,
    }),
  })
  if (!r.ok) {
    const t = await r.text().catch(() => '')
    throw new Error(`resend ${r.status}: ${t.slice(0, 200)}`)
  }
  return await r.json().catch(() => ({}))
}

async function sendViaSmtp(opts: {
  to: string; subject: string; html: string; fromName: string
}) {
  const { SMTPClient } = await import('https://deno.land/x/denomailer@1.6.0/mod.ts')
  const client = new SMTPClient({
    connection: {
      hostname: SMTP_HOST,
      port: SMTP_PORT,
      tls: true,
      auth: { username: SMTP_USER, password: SMTP_PASSWORD },
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

  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors })
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method Not Allowed' }), {
      status: 405, headers: { ...cors, 'Content-Type': 'application/json' },
    })
  }

  const authHeader = req.headers.get('Authorization') ?? ''
  const token = authHeader.replace(/^Bearer\s+/i, '')
  if (!SERVICE_KEY || token !== SERVICE_KEY) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401, headers: { ...cors, 'Content-Type': 'application/json' },
    })
  }

  let body: { to?: string; subject?: string; html?: string; text?: string; fromName?: string; category?: string }
  try { body = await req.json() } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON body' }), {
      status: 400, headers: { ...cors, 'Content-Type': 'application/json' },
    })
  }

  const { to, subject, html, text, fromName = 'Mensaena', category } = body
  if (!to || !subject || !html) {
    return new Response(JSON.stringify({ error: 'to, subject and html are required' }), {
      status: 400, headers: { ...cors, 'Content-Type': 'application/json' },
    })
  }

  const finalHtml = appendFooter(html, category)
  try {
    if (MAIL_API_KEY) {
      const result = await sendViaResend({
        to, subject, html: finalHtml, text,
        from: MAIL_FROM, category,
      })
      return new Response(JSON.stringify({ ok: true, provider: 'resend', id: result?.id }), {
        status: 200, headers: { ...cors, 'Content-Type': 'application/json' },
      })
    }
    // Fallback: SMTP (alter Pfad)
    await sendViaSmtp({ to, subject, html: finalHtml, fromName })
    return new Response(JSON.stringify({ ok: true, provider: 'smtp' }), {
      status: 200, headers: { ...cors, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err)
    console.error('[send-email] error:', msg)
    return new Response(JSON.stringify({ ok: false, error: msg }), {
      status: 500, headers: { ...cors, 'Content-Type': 'application/json' },
    })
  }
})
