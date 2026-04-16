// ============================================================
// Account Deletion E-Mail Templates – Mensaena
// 1. Löschbestätigung (sofort)
// 2. Re-Engagement Mails (4 Stück über 2 Monate)
// ============================================================

export interface DeletionEmailData {
  name: string
  unsubscribeUrl: string
}

// ── Wrapper: Gemeinsamer HTML-Rahmen ────────────────────────────
function wrap(title: string, body: string, unsubscribeUrl: string): string {
  return `<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1.0">
  <title>${title}</title>
</head>
<body style="margin:0;padding:0;background:#EEF9F9;font-family:Arial,Helvetica,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#EEF9F9;padding:40px 16px;">
<tr><td align="center">
<table width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background:#ffffff;border-radius:20px;overflow:hidden;box-shadow:0 6px 30px rgba(30,170,166,0.12);">

  <!-- HEADER -->
  <tr><td>
    <div style="background:linear-gradient(135deg,#1EAAA6 0%,#147170 100%);padding:36px 48px;text-align:center;">
      <table width="100%" cellpadding="0" cellspacing="0"><tr><td align="center">
        <div style="display:inline-block;background:rgba(255,255,255,0.15);border-radius:16px;padding:10px 20px;margin-bottom:12px;">
          <span style="color:#fff;font-size:28px;font-weight:800;letter-spacing:-1px;">Mensaena</span>
        </div>
        <p style="margin:0;color:rgba(255,255,255,0.85);font-size:13px;letter-spacing:0.5px;">Die Nachbarschaftshilfe-Plattform</p>
      </td></tr></table>
    </div>
  </td></tr>

  <!-- BODY -->
  <tr><td style="padding:40px 48px;">
    ${body}
  </td></tr>

  <!-- DIVIDER -->
  <tr><td style="padding:0 48px;">
    <hr style="border:none;border-top:1px solid #E5F7F7;margin:0;">
  </td></tr>

  <!-- FOOTER -->
  <tr><td style="background:#f8fffe;padding:24px 48px;border-radius:0 0 20px 20px;text-align:center;">
    <p style="margin:0 0 8px;color:#9CA3AF;font-size:11px;line-height:1.7;">
      Du erhältst diese E-Mail, weil du ein Konto bei Mensaena hattest.
    </p>
    <p style="margin:0;color:#9CA3AF;font-size:11px;">
      <a href="${unsubscribeUrl}" style="color:#6B7280;text-decoration:underline;">Keine weiteren E-Mails</a>
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
}

// ═══════════════════════════════════════════════════════════════
// 1. Löschbestätigung – sofort nach Kontolöschung
// ═══════════════════════════════════════════════════════════════
export function buildDeletionConfirmEmail(data: DeletionEmailData): { subject: string; html: string } {
  const { name, unsubscribeUrl } = data
  const greeting = name ? `Hallo ${name},` : 'Hallo,'

  const subject = 'Dein Mensaena-Konto wurde gelöscht'

  const body = `
    <div style="text-align:center;margin-bottom:28px;">
      <div style="display:inline-block;width:64px;height:64px;background:#FEF2F2;border:1px solid #FECACA;border-radius:16px;line-height:64px;font-size:28px;">
        👋
      </div>
    </div>
    <h1 style="margin:0 0 16px;color:#374151;font-size:24px;font-weight:800;text-align:center;">Konto erfolgreich gelöscht</h1>
    <p style="margin:0 0 16px;color:#374151;font-size:15px;line-height:1.75;">
      ${greeting}
    </p>
    <p style="margin:0 0 16px;color:#374151;font-size:15px;line-height:1.75;">
      dein Mensaena-Konto wurde wie gewünscht gelöscht. Alle deine persönlichen Daten, Beiträge und Nachrichten wurden entfernt.
    </p>
    <div style="background:#F9FAFB;border-radius:14px;padding:20px;margin:24px 0;">
      <p style="margin:0 0 8px;color:#6B7280;font-size:13px;font-weight:600;">Was wurde gelöscht:</p>
      <table cellpadding="0" cellspacing="0" style="width:100%;">
        <tr><td style="padding:4px 0;color:#374151;font-size:13px;">✓ Profildaten und Einstellungen</td></tr>
        <tr><td style="padding:4px 0;color:#374151;font-size:13px;">✓ Beiträge und Kommentare</td></tr>
        <tr><td style="padding:4px 0;color:#374151;font-size:13px;">✓ Nachrichten und Chat-Verläufe</td></tr>
        <tr><td style="padding:4px 0;color:#374151;font-size:13px;">✓ Vertrauensbewertungen</td></tr>
      </table>
    </div>
    <p style="margin:0 0 16px;color:#374151;font-size:15px;line-height:1.75;">
      Es tut uns leid, dich gehen zu sehen. Falls du es dir anders überlegst, kannst du dich jederzeit mit einer neuen E-Mail-Adresse wieder anmelden.
    </p>
    <p style="margin:0;color:#9CA3AF;font-size:13px;line-height:1.75;">
      Wir wünschen dir alles Gute!<br>
      <span style="color:#1EAAA6;font-weight:600;">Dein Mensaena-Team</span>
    </p>`

  return { subject, html: wrap(subject, body, unsubscribeUrl) }
}

// ═══════════════════════════════════════════════════════════════
// 2. Re-Engagement Mail #1 – 1 Woche nach Löschung
// ═══════════════════════════════════════════════════════════════
export function buildReengagement1(data: DeletionEmailData): { subject: string; html: string } {
  const { name, unsubscribeUrl } = data
  const greeting = name ? `Hallo ${name},` : 'Hallo,'

  const subject = 'Wir vermissen dich bei Mensaena 💚'

  const body = `
    <div style="text-align:center;margin-bottom:28px;">
      <div style="display:inline-block;width:64px;height:64px;background:#F0FDF4;border:1px solid #BBF7D0;border-radius:16px;line-height:64px;font-size:28px;">
        🌱
      </div>
    </div>
    <h1 style="margin:0 0 16px;color:#374151;font-size:24px;font-weight:800;text-align:center;">Deine Nachbarschaft wartet auf dich</h1>
    <p style="margin:0 0 16px;color:#374151;font-size:15px;line-height:1.75;">
      ${greeting}
    </p>
    <p style="margin:0 0 16px;color:#374151;font-size:15px;line-height:1.75;">
      eine Woche ist vergangen, seit du dein Mensaena-Konto gelöscht hast. In der Zwischenzeit hat sich in deiner Nachbarschaft einiges getan – neue Hilfeanfragen, Angebote und Veranstaltungen warten.
    </p>
    <div style="background:#f0fdfc;border-radius:14px;padding:24px;margin:24px 0;text-align:center;">
      <p style="margin:0 0 4px;color:#147170;font-size:32px;font-weight:800;">7+</p>
      <p style="margin:0;color:#147170;font-size:13px;">neue Aktivitäten in deiner Nähe</p>
    </div>
    <p style="margin:0 0 24px;color:#374151;font-size:15px;line-height:1.75;">
      Du kannst jederzeit mit einem neuen Konto wieder dabei sein. Es dauert nur 30 Sekunden.
    </p>
    <div style="text-align:center;">
      <a href="https://www.mensaena.de/auth?mode=register"
         style="display:inline-block;background:linear-gradient(135deg,#1EAAA6 0%,#147170 100%);color:#ffffff;text-decoration:none;padding:15px 40px;border-radius:13px;font-size:15px;font-weight:700;box-shadow:0 5px 18px rgba(30,170,166,0.35);">
        Neues Konto erstellen →
      </a>
    </div>`

  return { subject, html: wrap(subject, body, unsubscribeUrl) }
}

// ═══════════════════════════════════════════════════════════════
// 3. Re-Engagement Mail #2 – 2 Wochen nach Löschung
// ═══════════════════════════════════════════════════════════════
export function buildReengagement2(data: DeletionEmailData): { subject: string; html: string } {
  const { name, unsubscribeUrl } = data
  const greeting = name ? `Hallo ${name},` : 'Hallo,'

  const subject = 'Nachbarn helfen sich – auch du kannst dabei sein'

  const body = `
    <div style="text-align:center;margin-bottom:28px;">
      <div style="display:inline-block;width:64px;height:64px;background:#EFF6FF;border:1px solid #BFDBFE;border-radius:16px;line-height:64px;font-size:28px;">
        🤝
      </div>
    </div>
    <h1 style="margin:0 0 16px;color:#374151;font-size:24px;font-weight:800;text-align:center;">Gegenseitige Hilfe macht den Unterschied</h1>
    <p style="margin:0 0 16px;color:#374151;font-size:15px;line-height:1.75;">
      ${greeting}
    </p>
    <p style="margin:0 0 16px;color:#374151;font-size:15px;line-height:1.75;">
      wusstest du, dass Mensaena-Nutzer sich gegenseitig hunderte Stunden Zeit geschenkt haben? Ob Einkaufshilfe, Nachhilfe oder ein offenes Ohr – jede Hilfe zählt.
    </p>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin:24px 0;">
      <tr>
        <td width="32%" style="background:#f0fdfc;border-radius:14px;padding:20px;text-align:center;">
          <p style="margin:0 0 4px;font-size:24px;">🗺️</p>
          <p style="margin:0;color:#147170;font-size:12px;font-weight:600;">Interaktive Karte</p>
        </td>
        <td width="2%"></td>
        <td width="32%" style="background:#f0fdfc;border-radius:14px;padding:20px;text-align:center;">
          <p style="margin:0 0 4px;font-size:24px;">⏱️</p>
          <p style="margin:0;color:#147170;font-size:12px;font-weight:600;">Zeitbank</p>
        </td>
        <td width="2%"></td>
        <td width="32%" style="background:#f0fdfc;border-radius:14px;padding:20px;text-align:center;">
          <p style="margin:0 0 4px;font-size:24px;">💬</p>
          <p style="margin:0;color:#147170;font-size:12px;font-weight:600;">Direktnachrichten</p>
        </td>
      </tr>
    </table>
    <p style="margin:0 0 24px;color:#374151;font-size:15px;line-height:1.75;">
      Komm zurück und werde Teil einer aktiven Nachbarschafts-Community.
    </p>
    <div style="text-align:center;">
      <a href="https://www.mensaena.de/auth?mode=register"
         style="display:inline-block;background:linear-gradient(135deg,#1EAAA6 0%,#147170 100%);color:#ffffff;text-decoration:none;padding:15px 40px;border-radius:13px;font-size:15px;font-weight:700;box-shadow:0 5px 18px rgba(30,170,166,0.35);">
        Wieder dabei sein →
      </a>
    </div>`

  return { subject, html: wrap(subject, body, unsubscribeUrl) }
}

// ═══════════════════════════════════════════════════════════════
// 4. Re-Engagement Mail #3 – 1 Monat nach Löschung
// ═══════════════════════════════════════════════════════════════
export function buildReengagement3(data: DeletionEmailData): { subject: string; html: string } {
  const { name, unsubscribeUrl } = data
  const greeting = name ? `Hallo ${name},` : 'Hallo,'

  const subject = 'Deine Nachbarschaft hat sich verändert 🏘️'

  const body = `
    <div style="text-align:center;margin-bottom:28px;">
      <div style="display:inline-block;width:64px;height:64px;background:#FFF7ED;border:1px solid #FED7AA;border-radius:16px;line-height:64px;font-size:28px;">
        🏘️
      </div>
    </div>
    <h1 style="margin:0 0 16px;color:#374151;font-size:24px;font-weight:800;text-align:center;">Es gibt viel Neues zu entdecken</h1>
    <p style="margin:0 0 16px;color:#374151;font-size:15px;line-height:1.75;">
      ${greeting}
    </p>
    <p style="margin:0 0 16px;color:#374151;font-size:15px;line-height:1.75;">
      ein Monat ist vergangen – und Mensaena wächst weiter. Neue Mitglieder, neue Gruppen und neue Möglichkeiten, sich gegenseitig zu helfen.
    </p>
    <div style="background:linear-gradient(135deg,#f0fdfc 0%,#E0F2FE 100%);border-radius:14px;padding:28px;margin:24px 0;text-align:center;">
      <p style="margin:0 0 8px;color:#147170;font-size:18px;font-weight:700;">Was hat sich getan?</p>
      <p style="margin:0;color:#374151;font-size:14px;line-height:1.75;">
        Neue Events, Herausforderungen und Gruppen in deiner Umgebung. Vielleicht ist etwas für dich dabei?
      </p>
    </div>
    <p style="margin:0 0 24px;color:#374151;font-size:15px;line-height:1.75;">
      Du bist jederzeit willkommen. Registriere dich und werde wieder Teil der Gemeinschaft.
    </p>
    <div style="text-align:center;">
      <a href="https://www.mensaena.de/auth?mode=register"
         style="display:inline-block;background:linear-gradient(135deg,#1EAAA6 0%,#147170 100%);color:#ffffff;text-decoration:none;padding:15px 40px;border-radius:13px;font-size:15px;font-weight:700;box-shadow:0 5px 18px rgba(30,170,166,0.35);">
        Jetzt zurückkommen →
      </a>
    </div>`

  return { subject, html: wrap(subject, body, unsubscribeUrl) }
}

// ═══════════════════════════════════════════════════════════════
// 5. Re-Engagement Mail #4 – 2 Monate nach Löschung (letzte)
// ═══════════════════════════════════════════════════════════════
export function buildReengagement4(data: DeletionEmailData): { subject: string; html: string } {
  const { name, unsubscribeUrl } = data
  const greeting = name ? `Liebe/r ${name},` : 'Hallo,'

  const subject = 'Ein letzter Gruß von Mensaena 🌿'

  const body = `
    <div style="text-align:center;margin-bottom:28px;">
      <div style="display:inline-block;width:64px;height:64px;background:#F0FDF4;border:1px solid #BBF7D0;border-radius:16px;line-height:64px;font-size:28px;">
        🌿
      </div>
    </div>
    <h1 style="margin:0 0 16px;color:#374151;font-size:24px;font-weight:800;text-align:center;">Wir respektieren deine Entscheidung</h1>
    <p style="margin:0 0 16px;color:#374151;font-size:15px;line-height:1.75;">
      ${greeting}
    </p>
    <p style="margin:0 0 16px;color:#374151;font-size:15px;line-height:1.75;">
      dies ist unsere letzte Nachricht an dich. Wir möchten dir einfach nochmal sagen: Es war schön, dich in unserer Gemeinschaft gehabt zu haben.
    </p>
    <div style="background:#f8fffe;border-left:4px solid #1EAAA6;border-radius:0 14px 14px 0;padding:20px 24px;margin:24px 0;">
      <p style="margin:0;color:#374151;font-size:14px;line-height:1.75;font-style:italic;">
        „Die Stärke einer Gemeinschaft misst sich an der Bereitschaft, füreinander da zu sein."
      </p>
    </div>
    <p style="margin:0 0 16px;color:#374151;font-size:15px;line-height:1.75;">
      Falls du irgendwann zurückkommen möchtest, sind wir immer für dich da. Keine Fragen, kein Aufwand – einfach neu registrieren.
    </p>
    <div style="text-align:center;margin:28px 0 8px;">
      <a href="https://www.mensaena.de/auth?mode=register"
         style="display:inline-block;background:linear-gradient(135deg,#1EAAA6 0%,#147170 100%);color:#ffffff;text-decoration:none;padding:15px 40px;border-radius:13px;font-size:15px;font-weight:700;box-shadow:0 5px 18px rgba(30,170,166,0.35);">
        Mensaena erneut entdecken →
      </a>
    </div>
    <p style="margin:16px 0 0;color:#9CA3AF;font-size:13px;text-align:center;">
      Du erhältst nach dieser E-Mail keine weiteren Nachrichten.<br>
      <span style="color:#1EAAA6;font-weight:600;">Alles Gute – Dein Mensaena-Team</span>
    </p>`

  return { subject, html: wrap(subject, body, unsubscribeUrl) }
}

// ═══════════════════════════════════════════════════════════════
// Builder-Auswahl nach E-Mail-Nummer
// ═══════════════════════════════════════════════════════════════
export function buildReengagementByIndex(
  index: number,
  data: DeletionEmailData,
): { subject: string; html: string } | null {
  const builders = [
    buildReengagement1,
    buildReengagement2,
    buildReengagement3,
    buildReengagement4,
  ]
  const builder = builders[index]
  return builder ? builder(data) : null
}

/** Zeitplan für Re-Engagement-Mails (Offset ab Löschzeitpunkt) */
export const REENGAGEMENT_SCHEDULE_DAYS = [7, 14, 30, 60]
