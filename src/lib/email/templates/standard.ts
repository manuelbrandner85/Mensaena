// ============================================================
// 5 Standard-E-Mail-Templates für Admin-Versand
// ============================================================

interface StandardEmailData {
  unsubscribeUrl: string
}

function wrap(title: string, body: string, unsubscribeUrl: string): string {
  return `<!DOCTYPE html>
<html lang="de">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>${title}</title></head>
<body style="margin:0;padding:0;background:#EEF9F9;font-family:Arial,Helvetica,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#EEF9F9;padding:40px 16px;">
<tr><td align="center">
<table width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background:#ffffff;border-radius:20px;overflow:hidden;box-shadow:0 6px 30px rgba(30,170,166,0.12);">
  <tr><td>
    <div style="background:linear-gradient(135deg,#1EAAA6 0%,#147170 100%);padding:36px 48px;text-align:center;">
      <div style="display:inline-block;background:rgba(255,255,255,0.15);border-radius:16px;padding:10px 20px;margin-bottom:12px;">
        <span style="color:#fff;font-size:28px;font-weight:800;letter-spacing:-1px;">Mensaena</span>
      </div>
      <p style="margin:0;color:rgba(255,255,255,0.85);font-size:13px;letter-spacing:0.5px;">Die Nachbarschaftshilfe-Plattform</p>
    </div>
  </td></tr>
  <tr><td style="padding:40px 48px;">${body}</td></tr>
  <tr><td style="padding:0 48px;"><hr style="border:none;border-top:1px solid #E5F7F7;margin:0;"></td></tr>
  <tr><td style="background:#f8fffe;padding:24px 48px;border-radius:0 0 20px 20px;text-align:center;">
    <p style="margin:0 0 8px;color:#9CA3AF;font-size:11px;">
      <a href="${unsubscribeUrl}" style="color:#6B7280;text-decoration:underline;">E-Mails abbestellen</a>
      &nbsp;·&nbsp;
      <a href="https://www.mensaena.de/impressum" style="color:#6B7280;text-decoration:none;">Impressum</a>
      &nbsp;·&nbsp;
      <a href="https://www.mensaena.de/datenschutz" style="color:#6B7280;text-decoration:none;">Datenschutz</a>
    </p>
    <p style="margin:10px 0 0;color:#CBD5E1;font-size:10px;">© 2026 Mensaena – Nachbarschaftshilfe-Plattform</p>
  </td></tr>
</table>
</td></tr></table>
</body></html>`
}

const CTA = (label: string, url: string) => `
<div style="text-align:center;margin:28px 0 8px;">
  <a href="${url}" style="display:inline-block;background:linear-gradient(135deg,#1EAAA6 0%,#147170 100%);color:#ffffff;text-decoration:none;padding:15px 40px;border-radius:13px;font-size:15px;font-weight:700;box-shadow:0 5px 18px rgba(30,170,166,0.35);">${label}</a>
</div>`

// ═══════════════════════════════════════════════════════════════
// 1. Neue Features / Update
// ═══════════════════════════════════════════════════════════════
export function buildNewFeaturesEmail(data: StandardEmailData) {
  const subject = 'Neue Funktionen auf Mensaena! 🚀'
  const body = `
    <div style="text-align:center;margin-bottom:24px;">
      <div style="display:inline-block;width:64px;height:64px;background:#F0FDF4;border:1px solid #BBF7D0;border-radius:16px;line-height:64px;font-size:28px;">🚀</div>
    </div>
    <h1 style="margin:0 0 16px;color:#374151;font-size:24px;font-weight:800;text-align:center;">Neue Funktionen verfügbar</h1>
    <p style="margin:0 0 16px;color:#374151;font-size:15px;line-height:1.75;">Hallo,</p>
    <p style="margin:0 0 16px;color:#374151;font-size:15px;line-height:1.75;">wir haben Mensaena weiterentwickelt! Hier sind die neuesten Verbesserungen für dich:</p>
    <div style="background:#f0fdfc;border-radius:14px;padding:20px;margin:24px 0;">
      <table cellpadding="0" cellspacing="0" style="width:100%;">
        <tr><td style="padding:6px 0;color:#147170;font-size:14px;font-weight:600;">✨ Verbesserte Benutzeroberfläche</td></tr>
        <tr><td style="padding:6px 0;color:#147170;font-size:14px;font-weight:600;">🗺️ Neue Kartenfeatures</td></tr>
        <tr><td style="padding:6px 0;color:#147170;font-size:14px;font-weight:600;">💬 Schnellerer Chat</td></tr>
        <tr><td style="padding:6px 0;color:#147170;font-size:14px;font-weight:600;">🔔 Bessere Benachrichtigungen</td></tr>
      </table>
    </div>
    <p style="margin:0 0 16px;color:#374151;font-size:15px;line-height:1.75;">Schau vorbei und entdecke alles Neue!</p>
    ${CTA('Jetzt entdecken →', 'https://www.mensaena.de/dashboard')}
    <p style="margin:16px 0 0;color:#9CA3AF;font-size:13px;text-align:center;">Dein Mensaena-Team</p>`
  return { subject, html: wrap(subject, body, data.unsubscribeUrl) }
}

// ═══════════════════════════════════════════════════════════════
// 2. Community-Highlight / Erfolgsgeschichte
// ═══════════════════════════════════════════════════════════════
export function buildCommunityHighlightEmail(data: StandardEmailData) {
  const subject = 'So hilft sich deine Nachbarschaft 🤝'
  const body = `
    <div style="text-align:center;margin-bottom:24px;">
      <div style="display:inline-block;width:64px;height:64px;background:#EFF6FF;border:1px solid #BFDBFE;border-radius:16px;line-height:64px;font-size:28px;">🤝</div>
    </div>
    <h1 style="margin:0 0 16px;color:#374151;font-size:24px;font-weight:800;text-align:center;">Community-Highlights</h1>
    <p style="margin:0 0 16px;color:#374151;font-size:15px;line-height:1.75;">Hallo,</p>
    <p style="margin:0 0 16px;color:#374151;font-size:15px;line-height:1.75;">unsere Gemeinschaft wächst und wir sind stolz auf das, was wir gemeinsam erreichen. Hier ein paar Highlights:</p>
    <div style="background:#f8fffe;border-left:4px solid #1EAAA6;border-radius:0 14px 14px 0;padding:20px 24px;margin:24px 0;">
      <p style="margin:0;color:#374151;font-size:14px;line-height:1.75;font-style:italic;">
        „Dank Mensaena habe ich Hilfe beim Einkaufen gefunden, als ich nach meiner OP nicht mobil war. Innerhalb von 2 Stunden hat sich jemand gemeldet!"
      </p>
      <p style="margin:8px 0 0;color:#1EAAA6;font-size:13px;font-weight:600;">– Ein Mensaena-Mitglied</p>
    </div>
    <p style="margin:0 0 16px;color:#374151;font-size:15px;line-height:1.75;">Werde auch du Teil dieser Erfolgsgeschichten. Biete Hilfe an oder finde Unterstützung.</p>
    ${CTA('Zur Community →', 'https://www.mensaena.de/dashboard/posts')}
    <p style="margin:16px 0 0;color:#9CA3AF;font-size:13px;text-align:center;">Dein Mensaena-Team</p>`
  return { subject, html: wrap(subject, body, data.unsubscribeUrl) }
}

// ═══════════════════════════════════════════════════════════════
// 3. Event-Einladung
// ═══════════════════════════════════════════════════════════════
export function buildEventInviteEmail(data: StandardEmailData) {
  const subject = 'Veranstaltungen in deiner Nähe 📅'
  const body = `
    <div style="text-align:center;margin-bottom:24px;">
      <div style="display:inline-block;width:64px;height:64px;background:#FFF7ED;border:1px solid #FED7AA;border-radius:16px;line-height:64px;font-size:28px;">📅</div>
    </div>
    <h1 style="margin:0 0 16px;color:#374151;font-size:24px;font-weight:800;text-align:center;">Events in deiner Nachbarschaft</h1>
    <p style="margin:0 0 16px;color:#374151;font-size:15px;line-height:1.75;">Hallo,</p>
    <p style="margin:0 0 16px;color:#374151;font-size:15px;line-height:1.75;">es gibt spannende Veranstaltungen in deiner Nähe! Ob Nachbarschaftstreffen, Tauschbörse oder gemeinsames Gärtnern – es ist für jeden etwas dabei.</p>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin:24px 0;">
      <tr>
        <td width="48%" style="background:#f0fdfc;border-radius:14px;padding:20px;vertical-align:top;">
          <p style="margin:0 0 4px;font-size:20px;">🌱</p>
          <p style="margin:0 0 4px;color:#147170;font-size:13px;font-weight:700;">Gemeinschaftsgarten</p>
          <p style="margin:0;color:#4B5563;font-size:12px;">Triff deine Nachbarn beim gemeinsamen Gärtnern</p>
        </td>
        <td width="4%"></td>
        <td width="48%" style="background:#f0fdfc;border-radius:14px;padding:20px;vertical-align:top;">
          <p style="margin:0 0 4px;font-size:20px;">☕</p>
          <p style="margin:0 0 4px;color:#147170;font-size:13px;font-weight:700;">Nachbarschaftscafé</p>
          <p style="margin:0;color:#4B5563;font-size:12px;">Kennenlernen bei Kaffee und Kuchen</p>
        </td>
      </tr>
    </table>
    <p style="margin:0 0 16px;color:#374151;font-size:15px;line-height:1.75;">Schau dir alle Events an und melde dich an!</p>
    ${CTA('Events entdecken →', 'https://www.mensaena.de/dashboard/events')}
    <p style="margin:16px 0 0;color:#9CA3AF;font-size:13px;text-align:center;">Dein Mensaena-Team</p>`
  return { subject, html: wrap(subject, body, data.unsubscribeUrl) }
}

// ═══════════════════════════════════════════════════════════════
// 4. Inaktivitäts-Erinnerung
// ═══════════════════════════════════════════════════════════════
export function buildInactivityReminderEmail(data: StandardEmailData) {
  const subject = 'Wir vermissen dich, komm zurück! 💚'
  const body = `
    <div style="text-align:center;margin-bottom:24px;">
      <div style="display:inline-block;width:64px;height:64px;background:#F0FDF4;border:1px solid #BBF7D0;border-radius:16px;line-height:64px;font-size:28px;">💚</div>
    </div>
    <h1 style="margin:0 0 16px;color:#374151;font-size:24px;font-weight:800;text-align:center;">Deine Nachbarschaft wartet</h1>
    <p style="margin:0 0 16px;color:#374151;font-size:15px;line-height:1.75;">Hallo,</p>
    <p style="margin:0 0 16px;color:#374151;font-size:15px;line-height:1.75;">wir haben dich schon eine Weile nicht mehr gesehen. In deiner Nachbarschaft gibt es neue Hilfeanfragen, Angebote und Gespräche – vielleicht ist etwas für dich dabei?</p>
    <div style="background:linear-gradient(135deg,#f0fdfc 0%,#E0F2FE 100%);border-radius:14px;padding:28px;margin:24px 0;text-align:center;">
      <p style="margin:0 0 8px;color:#147170;font-size:18px;font-weight:700;">Es dauert nur 30 Sekunden</p>
      <p style="margin:0;color:#374151;font-size:14px;">Schau kurz rein und entdecke, was in deiner Umgebung passiert.</p>
    </div>
    ${CTA('Jetzt reinschauen →', 'https://www.mensaena.de/dashboard')}
    <p style="margin:16px 0 0;color:#9CA3AF;font-size:13px;text-align:center;">Dein Mensaena-Team</p>`
  return { subject, html: wrap(subject, body, data.unsubscribeUrl) }
}

// ═══════════════════════════════════════════════════════════════
// 5. Sicherheits- / Datenschutz-Update
// ═══════════════════════════════════════════════════════════════
export function buildSecurityUpdateEmail(data: StandardEmailData) {
  const subject = 'Wichtiges Sicherheitsupdate 🔒'
  const body = `
    <div style="text-align:center;margin-bottom:24px;">
      <div style="display:inline-block;width:64px;height:64px;background:#EFF6FF;border:1px solid #BFDBFE;border-radius:16px;line-height:64px;font-size:28px;">🔒</div>
    </div>
    <h1 style="margin:0 0 16px;color:#374151;font-size:24px;font-weight:800;text-align:center;">Sicherheits- & Datenschutz-Update</h1>
    <p style="margin:0 0 16px;color:#374151;font-size:15px;line-height:1.75;">Hallo,</p>
    <p style="margin:0 0 16px;color:#374151;font-size:15px;line-height:1.75;">die Sicherheit deiner Daten hat für uns oberste Priorität. Wir möchten dich über aktuelle Verbesserungen informieren:</p>
    <div style="background:#F9FAFB;border-radius:14px;padding:20px;margin:24px 0;">
      <table cellpadding="0" cellspacing="0" style="width:100%;">
        <tr><td style="padding:6px 0;color:#374151;font-size:14px;">🔐 Verbesserte Verschlüsselung</td></tr>
        <tr><td style="padding:6px 0;color:#374151;font-size:14px;">🛡️ Aktualisierte Datenschutzrichtlinien</td></tr>
        <tr><td style="padding:6px 0;color:#374151;font-size:14px;">✅ Regelmäßige Sicherheitsprüfungen</td></tr>
      </table>
    </div>
    <p style="margin:0 0 16px;color:#374151;font-size:15px;line-height:1.75;">Wir empfehlen dir, dein Passwort regelmäßig zu ändern und die Zwei-Faktor-Authentifizierung zu aktivieren.</p>
    ${CTA('Einstellungen prüfen →', 'https://www.mensaena.de/dashboard/settings')}
    <p style="margin:16px 0 0;color:#9CA3AF;font-size:13px;text-align:center;">Dein Mensaena-Team</p>`
  return { subject, html: wrap(subject, body, data.unsubscribeUrl) }
}

// ═══════════════════════════════════════════════════════════════
// Index: Alle Templates mit Metadaten
// ═══════════════════════════════════════════════════════════════
export const STANDARD_TEMPLATES = [
  { key: 'new_features',        label: 'Neue Features',           icon: '🚀', builder: buildNewFeaturesEmail },
  { key: 'community_highlight', label: 'Community-Highlight',     icon: '🤝', builder: buildCommunityHighlightEmail },
  { key: 'event_invite',        label: 'Event-Einladung',         icon: '📅', builder: buildEventInviteEmail },
  { key: 'inactivity_reminder', label: 'Inaktivitäts-Erinnerung', icon: '💚', builder: buildInactivityReminderEmail },
  { key: 'security_update',     label: 'Sicherheits-Update',      icon: '🔒', builder: buildSecurityUpdateEmail },
] as const
