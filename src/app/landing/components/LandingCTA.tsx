'use client'

import Link from 'next/link'
import { useTranslations } from 'next-intl'

export default function LandingCTA() {
  const t = useTranslations('landing')

  return (
    <section className="cin-wrap cin-cta-final" id="cta">
      <div className="cin-eyebrow reveal">— 09 / Bereit?</div>
      <h2 className="reveal d1">
        Deine Nachbarschaft
        <br />
        <em>wartet auf dich.</em>
      </h2>
      <p className="sub reveal d2">{t('ctaText')}</p>
      <div className="actions reveal d3">
        <Link className="cin-btn primary" href="/auth?mode=register">
          {t('ctaButton')} <span className="arrow">→</span>
        </Link>
        <Link className="cin-btn ghost" href="/auth?mode=login">
          {t('ctaLogin')}
        </Link>
      </div>
    </section>
  )
}
