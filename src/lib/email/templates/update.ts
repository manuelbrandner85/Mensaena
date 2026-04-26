// ============================================================
// Update/Ankündigungs-Template – Mensaena
// Für neue Features, wichtige Ankündigungen, Sonderaktionen
// ============================================================

export interface UpdateFeature {
  emoji: string
  title: string
  description: string
}

export interface UpdateEmailData {
  title: string               // Hauptüberschrift der Ankündigung
  subtitle?: string           // kurze Unterzeile
  bodyText: string            // Haupttext
  features?: UpdateFeature[]  // optionale Feature-Liste
  ctaLabel?: string           // Button-Text
  ctaUrl?: string             // Button-Ziel
  unsubscribeUrl: string
}

export function buildUpdateEmail(data: UpdateEmailData): { subject: string; html: string } {
  const {
    title,
    subtitle,
    bodyText,
    features = [],
    ctaLabel = 'Jetzt entdecken',
    ctaUrl = 'https://www.mensaena.de',
    unsubscribeUrl,
  } = data

  const subject = `Mensaena Update: ${title}`

  const featuresBlock = features.length > 0 ? `
    <tr><td style="padding:0 0 28px;">
      <table width="100%" cellpadding="0" cellspacing="0">
        ${features.map(f => `
        <tr><td style="padding:0 0 12px;">
          <table width="100%" cellpadding="0" cellspacing="0" style="background:#f0fdfc;border-radius:12px;padding:0;">
            <tr>
              <td width="52" style="padding:18px 0 18px 20px;vertical-align:top;">
                <span style="font-size:22px;">${f.emoji}</span>
              </td>
              <td style="padding:18px 16px 18px 0;vertical-align:top;">
                <p style="margin:0 0 4px;color:#147170;font-size:13px;font-weight:700;">${f.title}</p>
                <p style="margin:0;color:#4B5563;font-size:12px;line-height:1.6;">${f.description}</p>
              </td>
            </tr>
          </table>
        </td></tr>`).join('')}
      </table>
    </td></tr>` : ''

  const html = `<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1.0">
  <title>${subject}</title>
</head>
<body style="margin:0;padding:0;background:#EEF9F9;font-family:Arial,Helvetica,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#EEF9F9;padding:40px 16px;">
<tr><td align="center">
<table width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background:#ffffff;border-radius:20px;overflow:hidden;box-shadow:0 6px 30px rgba(30,170,166,0.12);">

  <!-- HEADER mit Badge -->
  <tr><td>
    <div style="background:linear-gradient(135deg,#1EAAA6 0%,#147170 100%);padding:40px 48px;text-align:center;">
      <div style="margin-bottom:14px;">
        <span style="background:rgba(255,255,255,0.2);color:#ffffff;font-size:11px;font-weight:700;padding:5px 14px;border-radius:20px;letter-spacing:1px;text-transform:uppercase;">✦ Mensaena Update</span>
      </div>
      <h1 style="margin:0 0 8px;color:#ffffff;font-size:26px;font-weight:800;letter-spacing:-0.5px;">${title}</h1>
      ${subtitle ? `<p style="margin:0;color:rgba(255,255,255,0.82);font-size:14px;">${subtitle}</p>` : ''}
    </div>
  </td></tr>

  <!-- BODY TEXT -->
  <tr><td style="padding:40px 48px ${features.length > 0 ? '24px' : '36px'};">
    <p style="margin:0;color:#374151;font-size:15px;line-height:1.8;">${bodyText}</p>
  </td></tr>

  ${features.length > 0 ? `
  <!-- FEATURES -->
  <tr><td style="padding:0 48px 8px;">
    <table width="100%" cellpadding="0" cellspacing="0">
      ${featuresBlock}
    </table>
  </td></tr>` : ''}

  <!-- CTA -->
  <tr><td style="padding:16px 48px 44px;text-align:center;">
    <a href="${ctaUrl}"
       style="display:inline-block;background:linear-gradient(135deg,#1EAAA6 0%,#147170 100%);color:#ffffff;text-decoration:none;padding:17px 48px;border-radius:13px;font-size:16px;font-weight:700;letter-spacing:0.2px;box-shadow:0 5px 18px rgba(30,170,166,0.35);">
      ${ctaLabel} →
    </a>
  </td></tr>

  <!-- DIVIDER -->
  <tr><td style="padding:0 48px;">
    <hr style="border:none;border-top:1px solid #E5F7F7;margin:0;">
  </td></tr>

  <!-- FOOTER -->
  <tr><td style="background:#f8fffe;padding:22px 48px;border-radius:0 0 20px 20px;text-align:center;">
    <p style="margin:0 0 6px;color:#9CA3AF;font-size:11px;">
      Du erhältst diese E-Mail als Mensaena-Mitglied.
    </p>
    <p style="margin:0;color:#9CA3AF;font-size:11px;">
      <a href="${unsubscribeUrl}" style="color:#6B7280;text-decoration:underline;">E-Mails abbestellen</a>
      &nbsp;·&nbsp;
      <a href="https://www.mensaena.de/impressum" style="color:#6B7280;text-decoration:none;">Impressum</a>
      &nbsp;·&nbsp;
      <a href="https://www.mensaena.de/datenschutz" style="color:#6B7280;text-decoration:none;">Datenschutz</a>
    </p>
    <p style="margin:8px 0 0;color:#CBD5E1;font-size:10px;">© 2026 Mensaena – Nachbarschaftshilfe-Plattform</p>
  </td></tr>

</table>
</td></tr>
</table>
</body>
</html>`

  return { subject, html }
}
