'use client'

import Link from 'next/link'
import { useTranslations } from 'next-intl'

const NUMS = ['01', '02', '03', '04', '05', '06', '07'] as const

export default function LandingCategories() {
  const t = useTranslations('landing')

  const cats = NUMS.map((n, i) => ({
    num: n,
    label: t(`cat${i + 1}Label` as const),
    example: t(`cat${i + 1}Example` as const),
  }))

  const titleText = t('categoriesTitle')
  const accent = 'Form der Hilfe'
  const hasAccent = titleText.includes(accent)

  return (
    <section className="cin-wrap cin-section" id="categories">
      <div className="cin-section-head">
        <div className="num">
          <b>— 05</b>
          <br />
          Kategorien
        </div>
        <h2>
          {hasAccent ? (
            <>
              {titleText.split(accent)[0]}
              <em>{accent}</em>
              {titleText.split(accent)[1]}
            </>
          ) : (
            titleText
          )}
        </h2>
      </div>

      <div className="cin-cats cin-section-end">
        {cats.map((c) => (
          <Link key={c.num} className="cin-cat-row reveal" href="/auth?mode=register">
            <span className="num">{c.num}</span>
            <span className="lbl">{c.label}</span>
            <span className="ex">„{c.example}"</span>
            <span className="arrow">→</span>
          </Link>
        ))}
      </div>
    </section>
  )
}
