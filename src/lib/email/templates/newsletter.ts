// ============================================================
// Newsletter Template – Mensaena
// Wöchentlich auto-generiert aus Plattform-Aktivität
// ============================================================

export interface NewsletterSection {
  emoji: string
  title: string
  items: string[]
}

export interface NewsletterEmailData {
  weekLabel: string            // z.B. "KW 17 · 21.–27. April 2026"
  intro: string                // kurzer Einleitungstext
  sections: NewsletterSection[]
  highlightTitle?: string
  highlightText?: string
  unsubscribeUrl: string
  editedByAdmin?: boolean
}

export function buildNewsletterEmail(data: NewsletterEmailData): { subject: string; html: string } {
  const { weekLabel, intro, sections, highlightTitle, highlightText, unsubscribeUrl } = data

  const subject = `Mensaena Wochennews · ${weekLabel}`

  const renderSection = (s: NewsletterSection) => `
    <tr><td style="padding:0 0 24px;">
      <table width="100%" cellpadding="0" cellspacing="0" style="background:#f8fffe;border-radius:14px;overflow:hidden;">
        <tr><td style="background:#E0F7F6;padding:14px 22px;">
          <span style="font-size:18px;">${s.emoji}</span>
          <span style="color:#147170;font-size:14px;font-weight:700;margin-left:8px;">${s.title}</span>
        </td></tr>
        <tr><td style="padding:16px 22px;">
          <ul style="margin:0;padding-left:18px;color:#374151;font-size:13px;line-height:2.0;">
            ${s.items.map(i => `<li>${i}</li>`).join('\n            ')}
          </ul>
        </td></tr>
      </table>
    </td></tr>`

  const highlightBlock = highlightTitle && highlightText ? `
  <!-- HIGHLIGHT BOX -->
  <tr><td style="padding:0 48px 32px;">
    <div style="background:linear-gradient(135deg,#1EAAA6 0%,#147170 100%);border-radius:16px;padding:28px 32px;text-align:center;">
      <p style="margin:0 0 8px;color:rgba(255,255,255,0.85);font-size:12px;font-weight:600;letter-spacing:1px;text-transform:uppercase;">Highlight der Woche</p>
      <h3 style="margin:0 0 10px;color:#ffffff;font-size:20px;font-weight:800;">${highlightTitle}</h3>
      <p style="margin:0;color:rgba(255,255,255,0.88);font-size:14px;line-height:1.65;">${highlightText}</p>
    </div>
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

  <!-- HEADER -->
  <tr><td>
    <div style="background:linear-gradient(135deg,#1EAAA6 0%,#147170 100%);padding:36px 48px 28px;">
      <table width="100%" cellpadding="0" cellspacing="0">
        <tr>
          <td>
            <span style="color:#ffffff;font-size:22px;font-weight:800;letter-spacing:-0.5px;">Mensaena</span>
            <p style="margin:2px 0 0;color:rgba(255,255,255,0.75);font-size:11px;">Deine Nachbarschaft · Diese Woche</p>
          </td>
          <td align="right">
            <span style="background:rgba(255,255,255,0.18);color:#ffffff;font-size:11px;font-weight:600;padding:5px 12px;border-radius:20px;">${weekLabel}</span>
          </td>
        </tr>
      </table>
    </div>
  </td></tr>

  <!-- INTRO -->
  <tr><td style="padding:36px 48px 24px;">
    <h2 style="margin:0 0 12px;color:#111827;font-size:22px;font-weight:800;">Was diese Woche los war 📋</h2>
    <p style="margin:0;color:#374151;font-size:14px;line-height:1.75;">${intro}</p>
  </td></tr>

  ${highlightBlock}

  <!-- SECTIONS -->
  <tr><td style="padding:0 48px 8px;">
    <table width="100%" cellpadding="0" cellspacing="0">
      ${sections.map(renderSection).join('')}
    </table>
  </td></tr>

  <!-- CTA -->
  <tr><td style="padding:8px 48px 44px;text-align:center;">
    <a href="https://www.mensaena.de"
       style="display:inline-block;background:linear-gradient(135deg,#1EAAA6 0%,#147170 100%);color:#ffffff;text-decoration:none;padding:15px 40px;border-radius:12px;font-size:15px;font-weight:700;box-shadow:0 4px 16px rgba(30,170,166,0.3);">
      Zur Plattform →
    </a>
  </td></tr>

  <!-- DIVIDER -->
  <tr><td style="padding:0 48px;">
    <hr style="border:none;border-top:1px solid #E5F7F7;margin:0;">
  </td></tr>

  <!-- FOOTER -->
  <tr><td style="background:#f8fffe;padding:22px 48px;border-radius:0 0 20px 20px;text-align:center;">
    <p style="margin:0 0 6px;color:#9CA3AF;font-size:11px;">
      Du erhältst diesen Newsletter wöchentlich als Mensaena-Mitglied.
    </p>
    <p style="margin:0;color:#9CA3AF;font-size:11px;">
      <a href="${unsubscribeUrl}" style="color:#6B7280;text-decoration:underline;">Newsletter abbestellen</a>
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
