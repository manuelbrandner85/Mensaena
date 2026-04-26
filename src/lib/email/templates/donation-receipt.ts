// ============================================================
// Spendenbescheinigung – Mensaena
// Wird auf Anfrage des Spenders per E-Mail versendet.
// ============================================================

export interface DonationReceiptData {
  donorName: string
  donorEmail: string
  amount: number          // in EUR
  donationDate: string    // ISO string, z.B. "2026-04-26"
  receiptNumber: string   // z.B. "SPENDE-2026-001"
  /** Optionale Adresse des Spenders für die Bescheinigung */
  donorAddress?: string
}

function formatDate(iso: string): string {
  const d = new Date(iso)
  return d.toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit', year: 'numeric' })
}

function formatAmount(eur: number): string {
  return eur.toLocaleString('de-DE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

export function buildDonationReceiptEmail(
  data: DonationReceiptData,
): { subject: string; html: string } {
  const { donorName, donorEmail, amount, donationDate, receiptNumber, donorAddress } = data
  const formattedDate   = formatDate(donationDate)
  const formattedAmount = formatAmount(amount)

  const subject = `Deine Spendenbescheinigung von Mensaena – ${formattedDate}`

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
    <div style="background:linear-gradient(135deg,#1EAAA6 0%,#147170 100%);padding:36px 48px;text-align:center;">
      <table width="100%" cellpadding="0" cellspacing="0"><tr><td align="center">
        <div style="display:inline-block;background:rgba(255,255,255,0.15);border-radius:16px;padding:10px 24px;margin-bottom:14px;">
          <span style="color:#fff;font-size:30px;font-weight:800;letter-spacing:-1px;">Mensaena</span>
        </div>
        <p style="margin:0;color:rgba(255,255,255,0.85);font-size:13px;letter-spacing:0.5px;">
          Die Nachbarschaftshilfe-Plattform
        </p>
        <div style="margin-top:20px;display:inline-block;background:rgba(255,255,255,0.2);border-radius:50px;padding:8px 22px;">
          <span style="color:#fff;font-size:13px;font-weight:700;letter-spacing:0.5px;">💚 Spendenbescheinigung</span>
        </div>
      </td></tr></table>
    </div>
  </td></tr>

  <!-- HERO TEXT -->
  <tr><td style="padding:36px 48px 0;">
    <div style="text-align:center;margin-bottom:24px;">
      <div style="display:inline-block;width:72px;height:72px;background:linear-gradient(135deg,#f0fdfc 0%,#d0f5f3 100%);border:2px solid #1EAAA6;border-radius:50%;line-height:72px;font-size:32px;text-align:center;">
        💚
      </div>
    </div>
    <h1 style="margin:0 0 10px;color:#0E1A19;font-size:26px;font-weight:800;text-align:center;letter-spacing:-0.5px;">
      Vielen Dank für deine Unterstützung!
    </h1>
    <p style="margin:0 0 6px;color:#374151;font-size:15px;line-height:1.8;text-align:center;">
      Liebe/r ${donorName},
    </p>
    <p style="margin:0;color:#4B5563;font-size:14px;line-height:1.8;text-align:center;">
      deine Spende hilft uns, Mensaena als kostenlose und werbefreie Nachbarschaftshilfe-Plattform am Laufen zu halten. Das bedeutet uns sehr viel.
    </p>
  </td></tr>

  <!-- BESCHEINIGUNG BOX -->
  <tr><td style="padding:28px 48px;">
    <div style="background:linear-gradient(135deg,#f0fdfc 0%,#f8fffe 100%);border:1.5px solid #1EAAA6;border-radius:16px;padding:28px 32px;">

      <!-- Titel -->
      <div style="text-align:center;margin-bottom:24px;padding-bottom:16px;border-bottom:1px solid #d0f5f3;">
        <p style="margin:0 0 4px;color:#147170;font-size:11px;font-weight:700;letter-spacing:1.5px;text-transform:uppercase;">
          Bestätigung der Zuwendung
        </p>
        <p style="margin:0;color:#0E1A19;font-size:18px;font-weight:800;">
          Spendenbescheinigung
        </p>
      </div>

      <!-- Details Tabelle -->
      <table width="100%" cellpadding="0" cellspacing="0">
        <tr>
          <td style="padding:8px 0;border-bottom:1px solid #E5F7F7;color:#6B7280;font-size:13px;width:45%;">Belegnummer</td>
          <td style="padding:8px 0;border-bottom:1px solid #E5F7F7;color:#0E1A19;font-size:13px;font-weight:700;font-family:monospace;">${receiptNumber}</td>
        </tr>
        <tr>
          <td style="padding:8px 0;border-bottom:1px solid #E5F7F7;color:#6B7280;font-size:13px;">Spendeneingang</td>
          <td style="padding:8px 0;border-bottom:1px solid #E5F7F7;color:#0E1A19;font-size:13px;font-weight:600;">${formattedDate}</td>
        </tr>
        <tr>
          <td style="padding:8px 0;border-bottom:1px solid #E5F7F7;color:#6B7280;font-size:13px;">Spender:in</td>
          <td style="padding:8px 0;border-bottom:1px solid #E5F7F7;color:#0E1A19;font-size:13px;font-weight:600;">${donorName}</td>
        </tr>
        ${donorAddress ? `<tr>
          <td style="padding:8px 0;border-bottom:1px solid #E5F7F7;color:#6B7280;font-size:13px;vertical-align:top;">Adresse</td>
          <td style="padding:8px 0;border-bottom:1px solid #E5F7F7;color:#0E1A19;font-size:13px;">${donorAddress.replace(/\n/g, '<br>')}</td>
        </tr>` : ''}
        <tr>
          <td style="padding:8px 0;border-bottom:1px solid #E5F7F7;color:#6B7280;font-size:13px;">E-Mail</td>
          <td style="padding:8px 0;border-bottom:1px solid #E5F7F7;color:#0E1A19;font-size:13px;">${donorEmail}</td>
        </tr>
        <tr>
          <td style="padding:8px 0;border-bottom:1px solid #E5F7F7;color:#6B7280;font-size:13px;">Verwendungszweck</td>
          <td style="padding:8px 0;border-bottom:1px solid #E5F7F7;color:#0E1A19;font-size:13px;">Förderung der Nachbarschaftshilfe</td>
        </tr>
        <tr>
          <td style="padding:12px 0 8px;color:#6B7280;font-size:13px;">Zahlungsart</td>
          <td style="padding:12px 0 8px;color:#0E1A19;font-size:13px;">Banküberweisung</td>
        </tr>
      </table>

      <!-- Betrag -->
      <div style="margin-top:20px;background:linear-gradient(135deg,#1EAAA6 0%,#147170 100%);border-radius:12px;padding:18px 24px;text-align:center;">
        <p style="margin:0 0 2px;color:rgba(255,255,255,0.8);font-size:12px;font-weight:600;letter-spacing:0.5px;text-transform:uppercase;">Gespendeter Betrag</p>
        <p style="margin:0;color:#ffffff;font-size:36px;font-weight:800;letter-spacing:-1px;">${formattedAmount} €</p>
        <p style="margin:4px 0 0;color:rgba(255,255,255,0.8);font-size:12px;">Euro (EUR)</p>
      </div>
    </div>
  </td></tr>

  <!-- EMPFÄNGER-INFO -->
  <tr><td style="padding:0 48px 24px;">
    <div style="background:#F9FAFB;border-radius:12px;padding:20px 24px;">
      <p style="margin:0 0 12px;color:#374151;font-size:13px;font-weight:700;">Empfänger der Spende:</p>
      <table cellpadding="0" cellspacing="0">
        <tr><td style="padding:2px 0;color:#4B5563;font-size:13px;"><strong style="color:#0E1A19;">Mensaena</strong> – Nachbarschaftshilfe-Plattform</td></tr>
        <tr><td style="padding:2px 0;color:#4B5563;font-size:13px;">IBAN: DE79 1001 0178 6303 9229 28</td></tr>
        <tr><td style="padding:2px 0;color:#4B5563;font-size:13px;">BIC: REVODEB2</td></tr>
        <tr><td style="padding:2px 0;color:#4B5563;font-size:13px;">Bank: Revolut Bank UAB</td></tr>
      </table>
    </div>
  </td></tr>

  <!-- HINWEIS -->
  <tr><td style="padding:0 48px 28px;">
    <div style="background:#FFFBEB;border:1px solid #FDE68A;border-radius:12px;padding:16px 20px;">
      <p style="margin:0 0 6px;color:#92400E;font-size:12px;font-weight:700;">⚠️ Hinweis zur steuerlichen Absetzbarkeit</p>
      <p style="margin:0;color:#78350F;font-size:12px;line-height:1.7;">
        Mensaena ist derzeit <strong>nicht</strong> als gemeinnützige Organisation im Sinne der Abgabenordnung anerkannt. Diese Bescheinigung dient als Zahlungsnachweis, kann aber <strong>nicht</strong> für steuerliche Abzüge genutzt werden. Wir arbeiten an der Anerkennung als gemeinnützige Organisation.
      </p>
    </div>
  </td></tr>

  <!-- DANKE -->
  <tr><td style="padding:0 48px 32px;text-align:center;">
    <p style="margin:0 0 16px;color:#374151;font-size:14px;line-height:1.8;">
      Deine Spende fließt direkt in den Betrieb der Plattform – Server, Infrastruktur und Weiterentwicklung. <strong>Danke, dass du uns dabei unterstützt!</strong>
    </p>
    <a href="https://www.mensaena.de/dashboard"
       style="display:inline-block;background:linear-gradient(135deg,#1EAAA6 0%,#147170 100%);color:#ffffff;text-decoration:none;padding:13px 32px;border-radius:12px;font-size:14px;font-weight:700;box-shadow:0 4px 16px rgba(30,170,166,0.3);">
      Zur Mensaena-Plattform →
    </a>
  </td></tr>

  <!-- DIVIDER -->
  <tr><td style="padding:0 48px;">
    <hr style="border:none;border-top:1px solid #E5F7F7;margin:0;">
  </td></tr>

  <!-- FOOTER -->
  <tr><td style="background:#f8fffe;padding:24px 48px;border-radius:0 0 20px 20px;text-align:center;">
    <p style="margin:0 0 6px;color:#9CA3AF;font-size:11px;line-height:1.7;">
      Mensaena · Nachbarschaftshilfe-Plattform · <a href="https://www.mensaena.de" style="color:#1EAAA6;text-decoration:none;">www.mensaena.de</a>
    </p>
    <p style="margin:0 0 6px;color:#9CA3AF;font-size:11px;">
      Kontakt: <a href="mailto:info@mensaena.de" style="color:#6B7280;text-decoration:underline;">info@mensaena.de</a>
    </p>
    <p style="margin:0;color:#9CA3AF;font-size:11px;">
      <a href="https://www.mensaena.de/impressum" style="color:#6B7280;text-decoration:none;">Impressum</a>
      &nbsp;·&nbsp;
      <a href="https://www.mensaena.de/datenschutz" style="color:#6B7280;text-decoration:none;">Datenschutz</a>
    </p>
    <p style="margin:10px 0 0;color:#CBD5E1;font-size:10px;">© 2026 Mensaena – Alle Rechte vorbehalten</p>
  </td></tr>

</table>
</td></tr>
</table>
</body>
</html>`

  return { subject, html }
}
