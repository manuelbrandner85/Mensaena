'use client'

import Link from 'next/link'
import { useTranslations } from 'next-intl'

export default function LandingHero() {
  const t = useTranslations('landing')

  return (
    <section className="cin-hero" id="hero" aria-labelledby="hero-heading">
      <div className="cin-hero-bloom" aria-hidden="true">
        <span className="b1" />
        <span className="b2" />
      </div>
      <div className="cin-hero-grid" aria-hidden="true" />

      <div className="cin-wrap">
        <div className="cin-eyebrow reveal">— 01 / {t('heroMeta').replace(/^0?1\s*\/\s*/, '')}</div>

        <h1 id="hero-heading" className="reveal d1">
          Nachbarschaft,
          <br />
          <em>neu gedacht.</em>
        </h1>

        <p className="lede reveal d2">
          Hilfe anbieten. Hilfe finden. Menschen in deiner Nähe kennenlernen.
          <br />
          <em>Kostenlos, gemeinnützig, von der Gemeinschaft getragen.</em>
        </p>

        <div className="actions reveal d3">
          <Link className="cin-btn primary" href="/auth?mode=register">
            {t('heroCtaPrimary')} <span className="arrow">→</span>
          </Link>
          <a className="cin-btn ghost" href="#features">
            {t('heroCtaSecondary')}
          </a>
        </div>

        <div className="facts reveal d3">
          <div>
            <div className="k">{t('heroFactLabel1')}</div>
            <div className="v">{t('heroFactValue1')}</div>
          </div>
          <div>
            <div className="k">{t('heroFactLabel2')}</div>
            <div className="v">{t('heroFactValue2')}</div>
          </div>
          <div>
            <div className="k">{t('heroFactLabel3')}</div>
            <div className="v">{t('heroFactValue3')}</div>
          </div>
          <div>
            <div className="k">{t('heroFactLabel4')}</div>
            <div className="v">{t('heroFactValue4')}</div>
          </div>
        </div>
      </div>

      <div className="cin-scroll-hint" aria-hidden="true">
        <span>Scroll</span>
        <i />
      </div>
    </section>
  )
}
