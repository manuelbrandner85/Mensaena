'use client'

import Link from 'next/link'
import { useTranslations } from 'next-intl'

export default function LandingFooter() {
  const t = useTranslations('landing')

  const scrollTop = (e: React.MouseEvent) => {
    e.preventDefault()
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  return (
    <footer className="cin-footer">
      <div className="cin-wrap">
        <div className="wordmark">
          Mensaena<em>.</em>
        </div>
        <div className="wordmark-sub">{t('footerTagline')}</div>

        <div className="row">
          <div>
            <h5>{t('footerPlatform')}</h5>
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
          </div>

          <div>
            <h5>{t('footerLegal')}</h5>
            <ul>
              <li>
                <Link href="/agb">AGB</Link>
              </li>
              <li>
                <Link href="/nutzungsbedingungen">Nutzungsbedingungen</Link>
              </li>
              <li>
                <Link href="/datenschutz">Datenschutz</Link>
              </li>
              <li>
                <Link href="/impressum">Impressum</Link>
              </li>
              <li>
                <Link href="/haftungsausschluss">Haftungsausschluss</Link>
              </li>
              <li>
                <Link href="/community-richtlinien">Community-Richtlinien</Link>
              </li>
            </ul>
          </div>

          <div>
            <h5>{t('footerContact')}</h5>
            <ul>
              <li>
                <a href="mailto:info@mensaena.de">info@mensaena.de</a>
              </li>
              <li>
                <a href="mailto:info@mensaena.de?subject=Feedback">{t('footerFeedback')}</a>
              </li>
              <li>
                <a href="mailto:info@mensaena.de?subject=Bug-Report">{t('footerBugReport')}</a>
              </li>
              <li>
                <a
                  href="https://github.com/manuelbrandner85/Mensaena"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  GitHub
                </a>
              </li>
            </ul>
          </div>

          <div>
            <h5>{t('footerFollowUs')}</h5>
            <ul>
              <li>
                <a href="#">Instagram</a>
              </li>
              <li>
                <a href="#">Mastodon</a>
              </li>
              <li>
                <a href="#">Bluesky</a>
              </li>
            </ul>
          </div>
        </div>

        <Link className="donate-pill" href="/spenden">
          <span className="h" aria-hidden="true">
            ♥
          </span>
          <span>Werbefrei dank Spender:innen — Mensaena unterstützen</span>
        </Link>

        <div className="bot">
          <span>© 2026 Mensaena · {t('footerCopyright')}</span>
          <span>Version 1.0.0-beta · Werbefrei · DSGVO-konform</span>
          <a href="#top" onClick={scrollTop}>
            ↑ Nach oben
          </a>
        </div>
      </div>
    </footer>
  )
}
