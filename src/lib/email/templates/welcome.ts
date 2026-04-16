// ============================================================
// Welcome E-Mail Template – Mensaena
// Automatisch versendet bei jeder Neuregistrierung
// ============================================================

export interface WelcomeEmailData {
  name: string
  unsubscribeUrl: string
  loginUrl?: string
}

export function buildWelcomeEmail(data: WelcomeEmailData): { subject: string; html: string } {
  const { name, unsubscribeUrl, loginUrl = 'https://www.mensaena.de/auth?mode=login' } = data
  const firstName = name ? (name.split(' ')[0] || name) : ''

  const subject = firstName
    ? `Willkommen bei Mensaena, ${firstName}! 🌿`
    : 'Willkommen bei Mensaena! 🌿'

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

  <!-- HEADER -->
  <tr><td>
    <div style="background:linear-gradient(135deg,#1EAAA6 0%,#147170 100%);padding:44px 48px;text-align:center;">
      <table width="100%" cellpadding="0" cellspacing="0"><tr><td align="center">
        <div style="display:inline-block;background:rgba(255,255,255,0.15);border-radius:16px;padding:10px 20px;margin-bottom:16px;">
          <span style="color:#fff;font-size:28px;font-weight:800;letter-spacing:-1px;">Mensaena</span>
        </div>
        <p style="margin:0;color:rgba(255,255,255,0.85);font-size:13px;letter-spacing:0.5px;">Die Nachbarschaftshilfe-Plattform</p>
      </td></tr></table>
    </div>
  </td></tr>

  <!-- HERO TEXT -->
  <tr><td style="padding:44px 48px 28px;">
    <h1 style="margin:0 0 10px;color:#1EAAA6;font-size:28px;font-weight:800;letter-spacing:-0.5px;">${firstName ? `Herzlich willkommen, ${firstName}! 👋` : 'Herzlich willkommen! 👋'}</h1>
    <p style="margin:0 0 20px;color:#374151;font-size:15px;line-height:1.75;">
      Wir freuen uns sehr, dich in unserer Gemeinschaft begrüßen zu dürfen.
      Mensaena verbindet Menschen in deiner Nachbarschaft – zum gegenseitigen Helfen, Teilen und Wachsen.
    </p>
    <p style="margin:0;color:#374151;font-size:15px;line-height:1.75;">
      Dein Konto ist jetzt bereit. Entdecke, was die Plattform zu bieten hat:
    </p>
  </td></tr>

  <!-- FEATURE CARDS -->
  <tr><td style="padding:0 48px 32px;">
    <table width="100%" cellpadding="0" cellspacing="0">
      <tr>
        <td width="48%" style="background:#f0fdfc;border-radius:14px;padding:20px;vertical-align:top;">
          <div style="font-size:24px;margin-bottom:8px;">🗺️</div>
          <p style="margin:0 0 4px;color:#147170;font-size:13px;font-weight:700;">Interaktive Karte</p>
          <p style="margin:0;color:#4B5563;font-size:12px;line-height:1.6;">Finde Hilfsangebote und Community-Beiträge in deiner direkten Umgebung.</p>
        </td>
        <td width="4%"></td>
        <td width="48%" style="background:#f0fdfc;border-radius:14px;padding:20px;vertical-align:top;">
          <div style="font-size:24px;margin-bottom:8px;">🤝</div>
          <p style="margin:0 0 4px;color:#147170;font-size:13px;font-weight:700;">Hilfe geben & finden</p>
          <p style="margin:0;color:#4B5563;font-size:12px;line-height:1.6;">Biete deine Zeit, Ressourcen oder Fähigkeiten an – oder finde Unterstützung.</p>
        </td>
      </tr>
      <tr><td colspan="3" style="height:12px;"></td></tr>
      <tr>
        <td width="48%" style="background:#f0fdfc;border-radius:14px;padding:20px;vertical-align:top;">
          <div style="font-size:24px;margin-bottom:8px;">⏱️</div>
          <p style="margin:0 0 4px;color:#147170;font-size:13px;font-weight:700;">Zeitbank</p>
          <p style="margin:0;color:#4B5563;font-size:12px;line-height:1.6;">Tausche deine Zeit fair gegen die Zeit anderer – ganz ohne Geld.</p>
        </td>
        <td width="4%"></td>
        <td width="48%" style="background:#f0fdfc;border-radius:14px;padding:20px;vertical-align:top;">
          <div style="font-size:24px;margin-bottom:8px;">💬</div>
          <p style="margin:0 0 4px;color:#147170;font-size:13px;font-weight:700;">Direktnachrichten</p>
          <p style="margin:0;color:#4B5563;font-size:12px;line-height:1.6;">Schreib direkt mit Nachbarn, Helfern und lokalen Organisationen.</p>
        </td>
      </tr>
    </table>
  </td></tr>

  <!-- CTA BUTTON -->
  <tr><td style="padding:8px 48px 44px;text-align:center;">
    <a href="${loginUrl}"
       style="display:inline-block;background:linear-gradient(135deg,#1EAAA6 0%,#147170 100%);color:#ffffff;text-decoration:none;padding:17px 44px;border-radius:13px;font-size:16px;font-weight:700;letter-spacing:0.2px;box-shadow:0 5px 18px rgba(30,170,166,0.35);">
      Jetzt Mensaena erkunden →
    </a>
    <p style="margin:18px 0 0;color:#9CA3AF;font-size:12px;">
      Oder öffne <a href="https://www.mensaena.de" style="color:#1EAAA6;text-decoration:none;">www.mensaena.de</a> in deinem Browser
    </p>
  </td></tr>

  <!-- DIVIDER -->
  <tr><td style="padding:0 48px;">
    <hr style="border:none;border-top:1px solid #E5F7F7;margin:0;">
  </td></tr>

  <!-- FOOTER -->
  <tr><td style="background:#f8fffe;padding:24px 48px;border-radius:0 0 20px 20px;text-align:center;">
    <p style="margin:0 0 8px;color:#9CA3AF;font-size:11px;line-height:1.7;">
      Du erhältst diese E-Mail, weil du dich bei Mensaena registriert hast.
    </p>
    <p style="margin:0;color:#9CA3AF;font-size:11px;">
      <a href="${unsubscribeUrl}" style="color:#6B7280;text-decoration:underline;">E-Mails abbestellen</a>
      &nbsp;·&nbsp;
      <a href="https://www.mensaena.de/impressum" style="color:#6B7280;text-decoration:none;">Impressum</a>
      &nbsp;·&nbsp;
      <a href="https://www.mensaena.de/datenschutz" style="color:#6B7280;text-decoration:none;">Datenschutz</a>
    </p>
    <p style="margin:10px 0 0;color:#CBD5E1;font-size:10px;">© 2025 Mensaena – Nachbarschaftshilfe-Plattform</p>
  </td></tr>

</table>
</td></tr>
</table>
</body>
</html>`

  return { subject, html }
}
