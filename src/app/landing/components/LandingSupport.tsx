'use client'

import Link from 'next/link'

export default function LandingSupport() {
  return (
    <section className="cin-wrap cin-section" id="support">
      <div className="cin-section-head">
        <div className="num">
          <b>— 08</b>
          <br />
          Unterstützung
        </div>
        <h2>
          Werbefrei. Spendenfinanziert. <em>Für immer.</em>
        </h2>
      </div>

      <p
        className="reveal"
        style={{
          fontSize: 17,
          lineHeight: 1.6,
          color: 'var(--paper-dim, #cdc4b1)',
          maxWidth: '54ch',
          marginBottom: 48,
        }}
      >
        Mensaena hat keine Werbung, keine Investoren und keine bezahlten Mitarbeiter:innen. Damit
        das so bleibt, finanzieren wir uns ausschließlich durch Menschen wie dich.
      </p>

      <div className="cin-support-card reveal d1 cin-section-end">
        <div className="main">
          <div className="heart-row">
            <span className="heart" aria-hidden="true">
              ♥
            </span>
            <span className="lbl">Goldenes Herz für Spender:innen</span>
          </div>
          <h3>
            Drei Euro halten Mensaena einen <em>Monat lang am Laufen</em> — pro 60
            Nachbar:innen.
          </h3>
          <p className="body">
            Server, Domain, SMS-Verifikation, Kartenservice. Alles, was du auf Mensaena nutzt,
            läuft im Hintergrund und kostet jeden Monat Geld.{' '}
            <em>Deine Spende deckt diese Kosten direkt</em> — transparent und ohne Umweg.
          </p>
          <div className="acts">
            <Link className="cin-btn primary" href="/spenden">
              Mensaena unterstützen <span className="arrow">→</span>
            </Link>
            <Link className="cin-btn ghost" href="/spenden#transparenz">
              Wo das Geld hingeht
            </Link>
          </div>
          <p className="cin-footnote">
            Mensaena ist derzeit nicht als gemeinnützig im Sinne der Abgabenordnung anerkannt.
            Spenden sind daher nicht steuerlich absetzbar — wir arbeiten daran.
          </p>
        </div>

        <div className="aside">
          <span className="lbl">In 30 Sekunden</span>
          <ul className="facts">
            <li>
              <span className="ico">QR</span>
              <div>
                <div className="tit">Banking-App scannen</div>
                <div className="des">
                  QR-Code öffnen, scannen, bestätigen. Funktioniert mit allen deutschen,
                  österreichischen und schweizerischen Banking-Apps.
                </div>
              </div>
            </li>
            <li>
              <span className="ico">DE</span>
              <div>
                <div className="tit">SEPA-Überweisung</div>
                <div className="des">
                  IBAN kopieren, klassische Überweisung. Mit oder ohne Spendenbescheinigung.
                </div>
              </div>
            </li>
            <li>
              <span className="ico">100</span>
              <div>
                <div className="tit">100 % transparent</div>
                <div className="des">
                  Wir veröffentlichen unsere Kosten. Jeder Cent fließt in den Betrieb der
                  Plattform.
                </div>
              </div>
            </li>
          </ul>
        </div>
      </div>
    </section>
  )
}
