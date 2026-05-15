'use client'

import Link from 'next/link'

export default function LandingMap() {
  return (
    <section className="cin-wrap cin-section" id="map">
      <div className="cin-section-head">
        <div className="num">
          <b>— 07</b>
          <br />
          Live in der Fläche
        </div>
        <h2>
          Echte Nachbarschaften, <em>verbunden</em> in Echtzeit.
        </h2>
      </div>

      <div className="cin-region cin-section-end">
        <div className="frame reveal">
          <div className="map" aria-hidden="true">
            <span className="pin a" />
            <span className="pin b" />
            <span className="pin c" />
            <span className="pin d" />
            <span className="pin e" />
            <span className="pin f" />
          </div>
        </div>
        <div className="panel reveal d1">
          <div>
            <div className="cin-eyebrow" style={{ marginBottom: 20 }}>
              07 / Live in der Fläche
            </div>
            <h3>
              Eine Karte, die <em>handeln lässt</em>.
            </h3>
            <p style={{ marginTop: 24 }}>
              Geo-getaggte Beiträge, gefilterte Cluster, Echtzeit-Updates. Wer Hilfe sucht oder
              gibt, sieht die Nachbarschaft als das, was sie ist:{' '}
              <em>eine Karte mit Klingelschildern.</em>
            </p>
          </div>
          <div className="stats">
            <div>
              <span className="k">Pins · 24h</span>
              <span className="v">1 842</span>
            </div>
            <div>
              <span className="k">Städte</span>
              <span className="v">186</span>
            </div>
            <div>
              <span className="k">Krisen-Hubs</span>
              <span className="v">9</span>
            </div>
          </div>
          <Link className="cin-btn primary" href="/auth?mode=register" style={{ alignSelf: 'flex-start' }}>
            Registrieren und Karte freischalten <span className="arrow">→</span>
          </Link>
        </div>
      </div>
    </section>
  )
}
