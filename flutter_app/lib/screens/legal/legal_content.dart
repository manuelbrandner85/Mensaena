/// SKILL: mensaena-features
/// Statische Markdown-Inhalte für alle Legal-/Info-Seiten.
/// 1:1 zu Web (/impressum, /datenschutz, /agb, /haftungsausschluss,
/// /nutzungsbedingungen, /community-guidelines, /about, /kontakt, /spenden).
library;

class LegalContent {
  const LegalContent._();

  static const Map<String, String> titles = {
    'impressum': 'Impressum',
    'datenschutz': 'Datenschutz',
    'agb': 'AGB',
    'haftungsausschluss': 'Haftungsausschluss',
    'nutzungsbedingungen': 'Nutzungsbedingungen',
    'community-guidelines': 'Community-Guidelines',
    'about': 'Über uns',
    'kontakt': 'Kontakt',
    'spenden': 'Spenden',
  };

  static const String impressum = '''
# Impressum

Angaben gemäß § 5 TMG zum Betreiber dieser Plattform.

**Uwe Vetter**
Via d'Ascoli 25
I-93021 Aragona (AG)
Italien

**Manuel Brandner**
Im Wahlsberg 10
55545 Bad Kreuznach
Deutschland

**Kontakt**
E-Mail: info@mensaena.de

**Verantwortlich für den Inhalt nach § 55 Abs. 2 RStV**
Uwe Vetter & Manuel Brandner (s.o.)

## Haftungsausschluss

Die Inhalte dieser Seiten wurden mit größter Sorgfalt erstellt. Für die Richtigkeit, Vollständigkeit und Aktualität der Inhalte können wir jedoch keine Gewähr übernehmen.

## Streitschlichtung

Die Europäische Kommission stellt eine Plattform zur Online-Streitbeilegung (OS) bereit: https://ec.europa.eu/consumers/odr

Wir sind nicht bereit oder verpflichtet, an Streitbeilegungsverfahren vor einer Verbraucherschlichtungsstelle teilzunehmen.
''';

  static const String datenschutz = '''
# Datenschutzerklärung

DSGVO-konform und transparent. So gehen wir mit deinen Daten um.

## 1. Verantwortliche

**Uwe Vetter**
Via d'Ascoli 25, I-93021 Aragona (AG), Italien

**Manuel Brandner**
Im Wahlsberg 10, 55545 Bad Kreuznach, Deutschland

E-Mail: info@mensaena.de

## 2. Datenerhebung

Wir erheben nur die Daten, die für die Bereitstellung unserer Dienste notwendig sind: E-Mail, Name, Standort (optional), Beiträge und Nachrichten.

## 3. Supabase

Authentifizierung und Datenspeicherung erfolgen über Supabase (EU-Server). Daten werden verschlüsselt übertragen und gespeichert.

## 4. Cookies & lokale Speicherung

Mensaena verwendet ausschließlich **technisch notwendige Cookies und localStorage-Einträge**. Es gibt keine Werbe-, Analyse- oder Tracking-Cookies.

- **Sitzungs-Cookie (Supabase Auth)** — wird gesetzt, sobald du dich anmeldest. Enthält ausschließlich dein verschlüsseltes Auth-Token. Wird beim Abmelden gelöscht.
- **Cookie-Einwilligung** (mensaena_cookie_consent) — localStorage. Speichert deine Entscheidung im Cookie-Banner (Schlüssel + Zeitstempel). Kein Server-Transfer.
- **Spenden-Badge** (mensaena_donation_badge_dismissed) — localStorage. Merkt, ob du den Spenden-Hinweis für 7 Tage geschlossen hast. Kein Server-Transfer.

Du kannst alle localStorage-Einträge jederzeit im Browser löschen (Entwickler-Tools → Application → Local Storage).

## 5. Cloudflare

Wir nutzen Cloudflare für CDN, Sicherheit und Performance. Cloudflare kann temporäre Verbindungsdaten verarbeiten.

## 6. Marketing- & Info-E-Mails

Werbliche bzw. reaktivierende E-Mails senden wir **nur mit deiner ausdrücklichen Einwilligung** (Opt-in). Die E-Mail-Anmeldung erfolgt im **Double-Opt-in-Verfahren** (Bestätigung per Klick). Du kannst die Einwilligung jederzeit in den Einstellungen oder über den Abmelde-Link in jeder E-Mail widerrufen. Wir protokollieren Einwilligung und Widerruf zum Nachweis (Zeitpunkt, Art).

## 7. KI-Funktionen

Für optionale KI-Funktionen (z. B. Texthilfe, Assistent, Übersetzung) werden die jeweiligen Eingaben an einen KI-Dienst als Auftragsverarbeiter übermittelt. Es werden **keine Chat-Klartexte zu Analysezwecken** gespeichert; lediglich Metadaten (z. B. genutzte Funktion, Sprache). Gibst du freiwillig Feedback zu einer KI-Antwort, speichern wir dieses zur Qualitätsverbesserung; es wird bei Konto-Löschung mit entfernt.

## 8. Push-Benachrichtigungen

Wenn du zustimmst, verarbeiten wir ein Geräte-Token, um dir Push-Benachrichtigungen zu senden. Du kannst dies in den System- und App-Einstellungen jederzeit deaktivieren.

## 9. Standortdaten

Die Standorterhebung ist **optional** und erfolgt nur nach deiner Freigabe. Standardmäßig ist dein Standort **nicht öffentlich sichtbar**. Anderen Nutzer:innen werden Positionen nur **gerundet** (ungefähr) angezeigt, nicht als exakte Koordinaten.

## 10. Deine Rechte

Du hast das Recht auf Auskunft, Berichtigung, Löschung, Einschränkung und Datenübertragbarkeit. In der App kannst du unter **Einstellungen** deine Daten als Datei **exportieren** (Art. 20) und dein **Konto inkl. aller Daten löschen** (Art. 17). Kontakt: info@mensaena.de

Stand: Juni 2026
''';

  static const String agb = '''
# Allgemeine Geschäftsbedingungen

Klare Spielregeln für eine kostenlose, gemeinnützige und transparente Plattform.

## 1. Geltungsbereich

Diese Allgemeinen Geschäftsbedingungen gelten für die Nutzung der Mensaena-Plattform (mensaena.de und www.mensaena.de) und aller damit verbundenen Dienste. Mit der Registrierung und Nutzung akzeptierst du diese Bedingungen.

## 2. Leistungsbeschreibung

Mensaena ist eine kostenlose Gemeinwohl-Plattform zur lokalen Vernetzung von Menschen. Die Plattform ermöglicht das Inserieren von Hilfsangeboten und -gesuchen, Community-Chats, Tierhilfe, regionale Versorgung, Krisenunterstützung und weitere Funktionen.

## 3. Registrierung & Konto

- Die Registrierung ist ab 16 Jahren erlaubt.
- Du bist für die Sicherheit deines Kontos selbst verantwortlich.
- Jede Person darf nur ein Konto besitzen.
- Falschangaben bei der Registrierung können zur Sperrung führen.

## 4. Verhaltensregeln

Auf Mensaena ist Folgendes untersagt:

- Hassrede, Diskriminierung oder Belästigung anderer Nutzer
- Verbreitung von Falschinformationen oder Spam
- Werbung für kommerzielle Zwecke ohne ausdrückliche Erlaubnis
- Teilen von rechtswidrigen oder anstößigen Inhalten
- Missbrauch des Krisensystems für nicht dringende Anfragen

## 5. Inhalte & Verantwortung

Nutzer sind selbst für die von ihnen erstellten Inhalte verantwortlich. Mensaena behält sich vor, Inhalte zu entfernen, die gegen diese Bedingungen verstoßen.

## 6. Kostenlosigkeit

Die Nutzung von Mensaena ist und bleibt kostenlos. Es gibt keine versteckten Gebühren, keine Abonnements und keine Werbung.

## 7. Haftung

Mensaena haftet nicht für Schäden, die durch die Nutzung der Plattform entstehen, es sei denn, sie wurden vorsätzlich oder grob fahrlässig verursacht.

## 8. Konto-Kündigung

Du kannst dein Konto jederzeit unter Einstellungen löschen. Mensaena kann Konten bei schwerwiegenden Verstößen sperren oder löschen.

## 9. Änderungen

Mensaena behält sich vor, diese AGB anzupassen. Wesentliche Änderungen werden den Nutzern rechtzeitig mitgeteilt.

## 10. Kontakt

E-Mail: info@mensaena.de

Stand: April 2026
''';

  static const String haftungsausschluss = '''
# Haftungsausschluss

Sorgfalt und Grenzen unserer Verantwortung. Klar geregelt.

## 1. Haftung für Inhalte

Die Inhalte unserer Seiten wurden mit größter Sorgfalt erstellt. Für die Richtigkeit, Vollständigkeit und Aktualität der Inhalte können wir jedoch keine Gewähr übernehmen. Als Diensteanbieter sind wir gemäß § 7 Abs. 1 TMG für eigene Inhalte auf diesen Seiten nach den allgemeinen Gesetzen verantwortlich. Nach §§ 8 bis 10 TMG sind wir als Diensteanbieter jedoch nicht verpflichtet, übermittelte oder gespeicherte fremde Informationen zu überwachen.

## 2. Haftung für Links

Unser Angebot enthält Links zu externen Webseiten Dritter, auf deren Inhalte wir keinen Einfluss haben. Deshalb können wir für diese fremden Inhalte auch keine Gewähr übernehmen. Bei Bekanntwerden von Rechtsverletzungen werden wir derartige Links umgehend entfernen.

## 3. Nutzer-generierte Inhalte

Mensaena ist eine Community-Plattform, auf der Nutzer eigene Inhalte erstellen und teilen. Die Verantwortung für nutzer-generierte Inhalte liegt beim jeweiligen Ersteller. Mensaena übernimmt keine Haftung für die Richtigkeit, Vollständigkeit oder Rechtmäßigkeit dieser Inhalte.

## 4. Verfügbarkeit

Mensaena bemüht sich um eine möglichst unterbrechungsfreie Verfügbarkeit der Plattform. Ein Anspruch auf ständige Verfügbarkeit besteht jedoch nicht.

## 5. Krisenhilfe-Disclaimer

**Wichtig:** Die Krisenhilfe-Funktionen auf Mensaena ersetzen keinen professionellen Rettungsdienst. Bei akuter Lebensgefahr rufe immer zuerst die **112** an. Mensaena übernimmt keine Haftung für die Qualität oder Rechtzeitigkeit von Hilfsleistungen, die über die Plattform vermittelt werden.

## 6. Urheberrecht

Die durch die Seitenbetreiber erstellten Inhalte und Werke auf diesen Seiten unterliegen dem deutschen Urheberrecht. Die Vervielfältigung, Bearbeitung, Verbreitung und jede Art der Verwertung außerhalb der Grenzen des Urheberrechtes bedürfen der schriftlichen Zustimmung des jeweiligen Autors.

## 7. Kein Handel & keine Geldgeschäfte

Mensaena ist eine gemeinnützige Plattform für kostenlose Nachbarschaftshilfe. **Kommerzieller Handel, Verkäufe und Geldtransaktionen sind auf der Plattform ausdrücklich nicht gestattet.** Mensaena übernimmt keinerlei Haftung für etwaige Geschäfte, die Nutzer untereinander außerhalb der Plattform vereinbaren.

## 8. Kontakt

E-Mail: info@mensaena.de

Stand: April 2026
''';

  static const String nutzungsbedingungen = '''
# Spielregeln der Gemeinschaft

Kostenlos, gemeinnützig und fair. Hier steht, wie wir miteinander umgehen.

## 1. Geltungsbereich

Diese Nutzungsbedingungen gelten für die Nutzung der Mensaena-Plattform (mensaena.de und www.mensaena.de) und aller damit verbundenen Dienste. Mit der Registrierung akzeptierst du diese Bedingungen.

## 2. Leistungsbeschreibung

Mensaena ist eine kostenlose Gemeinwohl-Plattform zur lokalen Vernetzung von Menschen. Die Plattform ermöglicht das Inserieren von Hilfsangeboten und -gesuchen, Community-Chats, Tierhilfe, regionale Versorgung, Krisenunterstützung und weitere Funktionen.

## 3. Registrierung & Konto

- Die Registrierung ist ab 16 Jahren erlaubt.
- Du bist für die Sicherheit deines Kontos selbst verantwortlich.
- Jede Person darf nur ein Konto besitzen.
- Falschangaben bei der Registrierung können zur Sperrung führen.

## 4. Verhaltensregeln & Handelsverbot

Auf Mensaena ist Folgendes untersagt:

- Hassrede, Diskriminierung oder Belästigung anderer Nutzer
- Verbreitung von Falschinformationen oder Spam
- Werbung für kommerzielle Zwecke ohne ausdrückliche Erlaubnis
- Teilen von rechtswidrigen oder anstößigen Inhalten
- Missbrauch des Krisensystems für nicht dringende Anfragen

**Kein Handel & keine Geldgeschäfte**

Auf der Mensaena-Plattform dürfen **keine kommerziellen Geschäfte, Verkäufe oder Geldtransaktionen** durchgeführt werden. Mensaena ist ausschließlich für kostenlose, gemeinnützige Nachbarschaftshilfe gedacht. Verstöße können zur Sperrung des Kontos führen.

## 5. Inhalte & Verantwortung

Nutzer sind selbst für die von ihnen erstellten Inhalte verantwortlich. Mensaena behält sich vor, Inhalte zu entfernen, die gegen diese Bedingungen verstoßen. Mensaena übernimmt keine Haftung für die Richtigkeit von Nutzerinhalten.

## 6. Kostenlosigkeit

Die Nutzung von Mensaena ist und bleibt kostenlos. Es gibt keine versteckten Gebühren, keine Abonnements und keine Werbung. Mensaena finanziert sich über freiwillige Spenden und ehrenamtliches Engagement.

## 7. Konto-Kündigung

Du kannst dein Konto jederzeit unter Einstellungen löschen. Mensaena kann Konten bei schwerwiegenden Verstößen gegen diese Bedingungen sperren oder löschen.

## 8. Änderungen

Mensaena behält sich vor, diese Nutzungsbedingungen anzupassen. Wesentliche Änderungen werden den Nutzern rechtzeitig mitgeteilt.

## 9. Kontakt

**Uwe Vetter**
Via d'Ascoli 25
I-93021 Aragona (AG)
Italien

**Manuel Brandner**
Im Wahlsberg 10
55545 Bad Kreuznach
Deutschland

E-Mail: info@mensaena.de

Stand: April 2026
''';

  static const String communityGuidelines = '''
# Wie wir miteinander umgehen

Mensaena lebt von gegenseitigem Respekt und Zusammenhalt. Diese Richtlinien helfen uns, eine sichere und freundliche Umgebung für alle zu schaffen.

**Grundprinzip:** Behandle andere so, wie du selbst behandelt werden möchtest. Mensaena ist ein Ort für echte Begegnungen — bringe deinen besten Selbst mit.

## 1. Respektvoller Umgang

- Behandle alle Mitglieder mit Respekt und Würde.
- Keine Beleidigungen, Bedrohungen oder persönlichen Angriffe.
- Akzeptiere unterschiedliche Meinungen und Lebensstile.
- Kommuniziere sachlich und konstruktiv.

## 2. Keine Diskriminierung

Diskriminierung aufgrund von Herkunft, Geschlecht, Religion, sexueller Orientierung, Behinderung oder anderer persönlicher Merkmale ist strikt untersagt.

## 3. Ehrlichkeit & Vertrauen

- Erstelle authentische Profile mit korrekten Angaben.
- Keine Fake-Accounts oder Identitätstäuschung.
- Stehe zu deinen Zusagen und Angeboten.
- Melde Vertrauensbrüche an die Moderation.

## 4. Inhaltsrichtlinien

Folgende Inhalte sind nicht erlaubt:

- Gewaltverherrlichende oder extremistische Inhalte
- Spam, Kettenbriefe oder unerwünschte Werbung
- Falschinformationen oder Verschwörungstheorien
- Urheberrechtlich geschütztes Material ohne Erlaubnis
- Pornografische oder ungeeignete Inhalte
- Persönliche Daten Dritter ohne deren Einwilligung

## 5. Krisensystem

Das Krisenhilfe-System ist für echte Notfälle und dringende Situationen gedacht. Missbrauch des Krisensystems führt zur Sperrung. Bei lebensbedrohlichen Notfällen wende dich immer zuerst an die **112**.

## 6. Datenschutz

- Teile keine persönlichen Daten anderer Nutzer öffentlich.
- Respektiere die Privatsphäre-Einstellungen anderer.
- Keine Screenshots von privaten Nachrichten ohne Zustimmung.

## 7. Melden & Moderation

Wenn du Verstöße gegen diese Richtlinien bemerkst, melde sie bitte über die Melde-Funktion oder per E-Mail an info@mensaena.de. Unser Moderations-Team prüft alle Meldungen und ergreift entsprechende Maßnahmen.

## 8. Konsequenzen

Bei Verstößen gegen diese Richtlinien kann Mensaena:

- Inhalte entfernen oder ausblenden
- Verwarnungen aussprechen
- Funktionen temporär einschränken
- Konten vorübergehend oder dauerhaft sperren

Stand: April 2026
''';

  static const String about = '''
# Freiheit beginnt im Bewusstsein.

Mensaena ist eine deutschsprachige Gemeinwohl-Plattform, die Menschen in ihrer Nachbarschaft vernetzt – lokal, persönlich und ohne Werbung.

## Unsere Mission

Wir glauben, dass echte Gemeinschaft und gegenseitige Hilfe die Grundlagen einer gesunden Gesellschaft sind. Mensaena schafft den digitalen Raum dafür – **kostenlos, ohne Werbung und ohne Datenmissbrauch**.

Die Idee ist einfach: Was wäre, wenn deine Nachbarn wieder füreinander da wären? Wenn Herr Müller nebenan dir beim Umzug hilft, weil du letzte Woche seinen Hund spazieren geführt hast? Wenn die alleinerziehende Mutter im dritten Stock weiß, dass jemand auf ihre Kinder aufpasst, falls sie mal länger arbeiten muss?

Genau das ermöglichen wir – digital, aber menschlich.

## Was uns antreibt

**Gemeinwohl vor Profit** — Mensaena hat keine Investoren, keine Werbepartner und keine bezahlten Mitarbeiter. Jede Entscheidung orientiert sich am Nutzen für die Gemeinschaft.

**Datenschutz first** — DSGVO ist für uns kein Compliance-Thema, sondern Grundprinzip. Wir verkaufen keine Daten und tracken dich nicht über dein Profil hinaus.

**Kostenlos für alle** — Mensaena ist und bleibt kostenlos. Wir finanzieren uns ausschließlich durch freiwillige Spenden – transparent und ohne Paywall.

**Offen & transparent** — Wir veröffentlichen unsere Betriebskosten und zeigen, wo jede Spende hingeht. Open Source ist unser Ziel, sobald der Code stabil ist.

## Was wir bauen

Mensaena ist mehr als ein schwarzes Brett. Auf der Plattform findest du:

- **Hilfsangebote & -gesuche** – von Handwerksarbeiten bis Kinderbetreuung
- **Nachbarschafts-Karte** – sieh auf einen Blick, wer in deiner Nähe aktiv ist
- **Gruppen & Vereine** – organisiere deine Nachbarschaftsinitiativen digital
- **Marktplatz** – verschenken, tauschen, günstig abgeben
- **Zeitbank** – Stunden statt Euro: gib Zeit, erhalte Zeit zurück
- **Notfall-Warnungen** – regionale Unwetter- und Katastrophenschutzwarnungen

## Wer steckt dahinter

**Manuel Brandner** — Gründer & Entwickler · Bad Kreuznach
Mensaena ist ein Herzensprojekt – gegründet 2024, weil Nachbarschaften wieder lebendiger werden sollten. Alles, was du auf Mensaena siehst, entsteht in meiner Freizeit.

**Uwe Vetter** — Mitgründer · Aragona, Italien
Uwe bringt Erfahrung in Community-Building und ist mitverantwortlich für die rechtliche und organisatorische Seite von Mensaena.

## Wie wir uns finanzieren

Mensaena finanziert sich **ausschließlich durch freiwillige Spenden**. Drei Euro halten die Plattform einen Monat lang am Laufen – pro 60 Nachbar:innen. Wir haben keine Werbung, keine Tracking-Pixel und keine Venture-Capital-Geldgeber.

Mensaena ist derzeit nicht als gemeinnützig im Sinne der Abgabenordnung anerkannt – wir arbeiten daran. Spenden sind daher noch nicht steuerlich absetzbar.
''';

  static const String kontakt = '''
# Schreib uns.

Wir freuen uns über deine Nachricht – egal ob Frage, Feedback oder Lob.

## E-Mail

info@mensaena.de

Wir antworten in der Regel innerhalb von 1–2 Werktagen.

## Adresse

Manuel Brandner
Im Wahlsberg 10
55545 Bad Kreuznach

## Community

Als registrierter Nutzer kannst du den Community-Chat nutzen, um dich mit der Mensaena-Community auszutauschen.

## Häufige Anliegen

- **Technische Probleme:** Bitte beschreibe das Problem und dein Gerät.
- **Feedback & Ideen:** Wir freuen uns über Verbesserungsvorschläge!
- **Meldungen:** Problematische Inhalte bitte mit Link melden.
- **Datenschutz:** Anfragen gem. DSGVO bitte per E-Mail.
''';

  /// Returns the body Markdown for a given key, or null if unknown.
  static String? body(String key) {
    switch (key) {
      case 'impressum':
        return impressum;
      case 'datenschutz':
        return datenschutz;
      case 'agb':
        return agb;
      case 'haftungsausschluss':
        return haftungsausschluss;
      case 'nutzungsbedingungen':
        return nutzungsbedingungen;
      case 'community-guidelines':
        return communityGuidelines;
      case 'about':
        return about;
      case 'kontakt':
        return kontakt;
      default:
        return null;
    }
  }
}
