// ============================================================
// E-Mail Sende-Utility – ruft die Supabase Edge Function auf
// ============================================================

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL ||
  'https://huaqldjkgyosefzfhjnf.supabase.co'

const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY ||
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDk4NzExOCwiZXhwIjoyMDkwNTYzMTE4fQ.t09nG5IbpDPAuBuTLuOedep9ZEmi1dcNjD0xsPzFZVQ'

export interface SendEmailPayload {
  to: string
  subject: string
  html: string
  fromName?: string
}

export interface SendEmailResult {
  ok: boolean
  error?: string
}

export async function sendEmail(payload: SendEmailPayload): Promise<SendEmailResult> {
  const url = `${SUPABASE_URL}/functions/v1/send-email`

  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      },
      body: JSON.stringify(payload),
    })

    if (!res.ok) {
      const text = await res.text().catch(() => res.statusText)
      return { ok: false, error: text }
    }

    return { ok: true }
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err)
    return { ok: false, error: msg }
  }
}

/** Versendet eine E-Mail an mehrere Empfänger (sequenziell, mit Delay) */
export async function sendEmailBatch(
  recipients: Array<{ email: string; name?: string }>,
  subject: string,
  buildHtml: (email: string, name: string) => string,
  delayMs = 200,
): Promise<{ sent: number; failed: number; errors: string[] }> {
  let sent = 0
  let failed = 0
  const errors: string[] = []

  for (const recipient of recipients) {
    const html = buildHtml(recipient.email, recipient.name || recipient.email)
    const result = await sendEmail({ to: recipient.email, subject, html })

    if (result.ok) {
      sent++
    } else {
      failed++
      errors.push(`${recipient.email}: ${result.error}`)
    }

    if (delayMs > 0) {
      await new Promise(resolve => setTimeout(resolve, delayMs))
    }
  }

  return { sent, failed, errors }
}
