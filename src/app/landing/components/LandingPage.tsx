'use client'

import LandingNavbar from './LandingNavbar'
import LandingHero from './LandingHero'
import LandingStats from './LandingStats'
import LandingFeatures from './LandingFeatures'
import LandingHowItWorks from './LandingHowItWorks'
import LandingCategories from './LandingCategories'
import LandingTestimonials from './LandingTestimonials'
import LandingMap from './LandingMap'
import LandingCTA from './LandingCTA'
import LandingFooter from './LandingFooter'
import RevealObserver from './RevealObserver'
import EditorialRail from './EditorialRail'
import AppDownloadSection from '@/components/download/AppDownloadSection'
import FloatingAppButton from '@/components/download/FloatingAppButton'

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
      <main id="main-content" className="min-h-screen bg-paper">
        <LandingHero />
        <LandingStats />
        <AppDownloadSection />
        <LandingFeatures />
        <LandingHowItWorks />
        <LandingCategories />
        <LandingTestimonials />
        <LandingMap />
        <LandingCTA />
      </main>
      <LandingFooter />
      <FloatingAppButton />
    </>
  )
}
