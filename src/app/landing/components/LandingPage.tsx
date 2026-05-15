'use client'

import LandingNavbar from './LandingNavbar'
import LandingHero from './LandingHero'
import LandingStats from './LandingStats'
import LandingFeatures from './LandingFeatures'
import LandingHowItWorks from './LandingHowItWorks'
import LandingCategories from './LandingCategories'
import LandingTestimonials from './LandingTestimonials'
import LandingMap from './LandingMap'
import LandingSupport from './LandingSupport'
import LandingCTA from './LandingCTA'
import LandingFooter from './LandingFooter'
import RevealObserver from './RevealObserver'
import AppDownloadSection from '@/components/download/AppDownloadSection'
import FloatingAppButton from '@/components/download/FloatingAppButton'
import DonationBadge from '@/components/landing/DonationBadge'
import { APK_DOWNLOAD_ENABLED } from '@/lib/app-download'

export default function LandingPage() {
  return (
    <div
      className="relative min-h-screen"
      style={{
        background: '#0a1420',
        color: '#ece5d6',
      }}
    >
      <RevealObserver />

      {/* Atmospheric layers — calm, no film artifacts */}
      <div className="cin-haze" aria-hidden="true">
        <i className="a" />
        <i className="b" />
        <i className="c" />
      </div>
      <div className="cin-vignette" aria-hidden="true" />
      <div className="cin-grain" aria-hidden="true" />

      <LandingNavbar />

      <main id="main-content" className="relative" style={{ zIndex: 2 }}>
        <LandingHero />
        <LandingStats />
        {APK_DOWNLOAD_ENABLED && <AppDownloadSection />}
        <LandingFeatures />
        <LandingHowItWorks />
        <LandingCategories />
        <LandingTestimonials />
        <LandingMap />
        <LandingSupport />
        <LandingCTA />
        <LandingFooter />
        {APK_DOWNLOAD_ENABLED && <FloatingAppButton />}
        <DonationBadge variant="floating" />
      </main>
    </div>
  )
}
