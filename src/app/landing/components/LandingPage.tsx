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
import EditorialRail from './EditorialRail'
import AppDownloadSection from '@/components/download/AppDownloadSection'
import FloatingAppButton from '@/components/download/FloatingAppButton'
import DonationBadge from '@/components/landing/DonationBadge'
import { APK_DOWNLOAD_ENABLED } from '@/lib/app-download'

/**
 * LandingPage – assembles all landing sections in order.
 * Rendered by app/page.tsx for unauthenticated visitors.
 */
export default function LandingPage() {
  return (
    <>
      <RevealObserver />
      <EditorialRail />
      <LandingNavbar />
      <main id="main-content" className="min-h-dvh bg-paper">
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
      </main>
      <LandingFooter />
      {APK_DOWNLOAD_ENABLED && <FloatingAppButton />}
      <DonationBadge variant="floating" />
    </>
  )
}
