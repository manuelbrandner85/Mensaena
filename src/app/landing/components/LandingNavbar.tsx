'use client'

import Link from 'next/link'
import { useTranslations } from 'next-intl'

export default function LandingNavbar() {
  const t = useTranslations('landing')

  return (
    <header className="cin-nav" role="banner">
      <div className="brand">
        <div className="mark">
          Mensaena<em>.</em>
        </div>
        <div className="tag">{t('brandTag')}</div>
      </div>

      <ul>
        <li>
          <a href="#features">{t('navFeatures')}</a>
        </li>
        <li>
          <a href="#how">{t('navHowItWorks')}</a>
        </li>
        <li>
          <a href="#categories">{t('navCategories')}</a>
        </li>
        <li>
          <a href="#map">{t('navMap')}</a>
        </li>
        <li>
          <a href="#support">Spenden</a>
        </li>
      </ul>

      <div className="nav-right">
        <div className="lang" aria-hidden="true">
          <b>DE</b>
          <span>·</span>
          <span>EN</span>
        </div>
        <Link className="cta" href="/auth?mode=register">
          {t('navStart')} ↗
        </Link>
      </div>
    </header>
  )
}
