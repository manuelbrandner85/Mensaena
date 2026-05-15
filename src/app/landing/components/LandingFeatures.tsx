'use client'

import { useTranslations } from 'next-intl'
import type { ReactNode } from 'react'

type DescKey = 'f1Desc' | 'f2Desc' | 'f3Desc' | 'f4Desc' | 'f5Desc' | 'f6Desc'

type Feat = {
  num: string
  title: ReactNode
  descKey: DescKey
  d: string
}

export default function LandingFeatures() {
  const t = useTranslations('landing')

  // Italic accents hard-coded to match the reference design.
  const feats: Feat[] = [
    { num: '01', title: <em>Hyperlokal.</em>, descKey: 'f1Desc', d: '' },
    {
      num: '02',
      title: (
        <>
          Hilfe geben <em>&amp; nehmen.</em>
        </>
      ),
      descKey: 'f2Desc',
      d: 'd1',
    },
    {
      num: '03',
      title: (
        <>
          Vertrauen &amp; <em>Sicherheit.</em>
        </>
      ),
      descKey: 'f3Desc',
      d: 'd2',
    },
    {
      num: '04',
      title: (
        <>
          Direkter <em>Kontakt.</em>
        </>
      ),
      descKey: 'f4Desc',
      d: '',
    },
    { num: '05', title: <em>Gemeinnützig.</em>, descKey: 'f5Desc', d: 'd1' },
    { num: '06', title: <em>Krisenhilfe.</em>, descKey: 'f6Desc', d: 'd2' },
  ]

  const titleText = t('featuresTitle')
  const hasGemeinschaft = titleText.includes('Gemeinschaft')

  return (
    <section className="cin-wrap cin-section" id="features">
      <div className="cin-section-head">
        <div className="num">
          <b>— 03</b>
          <br />
          Was Mensaena
          <br />
          auszeichnet
        </div>
        <h2>
          {hasGemeinschaft ? (
            <>
              {titleText.split('Gemeinschaft')[0]}
              <em>Gemeinschaft</em>
              {titleText.split('Gemeinschaft')[1]}
            </>
          ) : (
            titleText
          )}
        </h2>
      </div>

      <div className="cin-features-grid cin-section-end">
        {feats.map((f) => (
          <article key={f.num} className={`cin-feat reveal ${f.d}`}>
            <div className="top">
              <span className="num">{f.num}</span>
              <span className="dot" />
            </div>
            <div>
              <h3>{f.title}</h3>
              <p>{t(f.descKey)}</p>
            </div>
          </article>
        ))}
      </div>
    </section>
  )
}
