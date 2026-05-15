'use client'

import Link from 'next/link'
import { useTranslations } from 'next-intl'
import type { ReactNode } from 'react'

type Step = {
  num: string
  title: ReactNode
  descKey: 'step1Desc' | 'step2Desc' | 'step3Desc'
  d: string
}

export default function LandingHowItWorks() {
  const t = useTranslations('landing')

  const steps: Step[] = [
    { num: '01', title: <em>Registrieren.</em>, descKey: 'step1Desc', d: '' },
    {
      num: '02',
      title: (
        <>
          Standort <em>einstellen.</em>
        </>
      ),
      descKey: 'step2Desc',
      d: 'd1',
    },
    { num: '03', title: <em>Loslegen.</em>, descKey: 'step3Desc', d: 'd2' },
  ]

  return (
    <section className="cin-wrap cin-section" id="how">
      <div className="cin-section-head">
        <div className="num">
          <b>— 04</b>
          <br />
          So beginnt es
        </div>
        <h2>
          Drei Schritte zur <em>aktiven</em> Nachbarschaft.
        </h2>
      </div>

      <div className="cin-steps-grid cin-section-end">
        {steps.map((s) => (
          <article key={s.num} className={`cin-step reveal ${s.d}`}>
            <div className="big">{s.num}</div>
            <div>
              <h3>{s.title}</h3>
              <p>{t(s.descKey)}</p>
            </div>
          </article>
        ))}
      </div>

      <div className="reveal d3" style={{ marginTop: 8, paddingBottom: 140 }}>
        <Link className="cin-btn primary" href="/auth?mode=register">
          {t('howCta')} <span className="arrow">→</span>
        </Link>
      </div>
    </section>
  )
}
