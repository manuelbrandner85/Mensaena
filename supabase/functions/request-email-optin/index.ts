// request-email-optin — Double-Opt-in Schritt 1: Bestätigungs-Mail senden.
//
// Der eingeloggte Nutzer fordert das E-Mail-Abo an (Settings-Toggle). Wir setzen
// subscribed=false + frischen confirm_token und senden eine Bestätigungs-Mail
// mit Link auf /api/emails/confirm?token=… . Erst der Klick aktiviert das Abo
// (Schritt 2, Next.js-Route). So ist die Einwilligung DSGVO-konform nachweisbar
// und es wird NICHTS ohne aktive Bestätigung versendet.
import { CORS, json, adminClient, getUser } from '../_shared/util.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const SITE = 'https://www.mensaena.de'

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  if (req.method !== 'POST') return json({ error: 'method' }, 405)

  const user = await getUser(req)
  if (!user) return json({ error: 'unauthorized' }, 401)
  const email = (user.email ?? '').trim()
  if (!email) return json({ error: 'no_email' }, 400)

  const admin = adminClient()
  const token = crypto.randomUUID()

  // Upsert: unbestätigter Eintrag mit frischem Bestätigungs-Token.
  const { error: upErr } = await admin
    .from('email_subscriptions')
    .upsert({
      user_id: user.id,
      email,
      subscribed: false,
      confirmed_at: null,
      confirm_token: token,
    }, { onConflict: 'user_id' })
  if (upErr) return json({ error: upErr.message }, 500)

  const link = `${SITE}/api/emails/confirm?token=${encodeURIComponent(token)}`
  const html = `
    <div style="font-family:system-ui,sans-serif;max-width:520px;margin:0 auto">
      <h2 style="color:#147170">Bitte bestätige deine E-Mail-Anmeldung</h2>
      <p style="font-size:15px;color:#3a3a3a;line-height:1.5">
        Du hast Mensaena-Infos &amp; Neuigkeiten per E-Mail angefordert.
        Klicke zur Bestätigung auf den Button — erst danach senden wir dir etwas.
      </p>
      <p style="margin:28px 0">
        <a href="${link}" style="background:#1EAAA6;color:#fff;text-decoration:none;
           padding:12px 22px;border-radius:10px;font-weight:600;display:inline-block">
          E-Mail-Anmeldung bestätigen
        </a>
      </p>
      <p style="font-size:13px;color:#6b665e;line-height:1.5">
        Wenn du das nicht warst, ignoriere diese Mail einfach — ohne Bestätigung
        passiert nichts.
      </p>
      <p style="font-size:12px;color:#6b665e;line-height:1.5">
        Fragen zum Datenschutz? Schreib uns an
        <a href="mailto:info@mensaena.de" style="color:#147170">info@mensaena.de</a>.
      </p>
    </div>`

  // Versand über die bestehende send-email-Function (service_role-Auth).
  try {
    const r = await fetch(`${SUPABASE_URL}/functions/v1/send-email`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${SERVICE_ROLE}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        to: email,
        subject: 'Bitte bestätige deine E-Mail-Anmeldung · Mensaena',
        html,
        category: 'confirm', // KEIN marketing-Footer-Abmeldelink nötig (Transaktion)
      }),
    })
    if (!r.ok) {
      const t = await r.text().catch(() => '')
      return json({ error: `send failed: ${t.slice(0, 160)}` }, 502)
    }
  } catch (e) {
    return json({ error: String(e) }, 502)
  }

  return json({ ok: true })
})
