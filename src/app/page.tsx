import PublicHeader from '@/components/layout/PublicHeader'
import PublicFooter from '@/components/layout/PublicFooter'
import HeroSection from '@/components/landing/HeroSection'
import FeaturesSection from '@/components/landing/FeaturesSection'
import WhyMensaena from '@/components/landing/WhyMensaena'
import HowItWorks from '@/components/landing/HowItWorks'
import ModulesOverview from '@/components/landing/ModulesOverview'
import CTASection from '@/components/landing/CTASection'

export default function HomePage() {
  return (
    <main className="min-h-screen">
      <PublicHeader />
      <HeroSection />
      <FeaturesSection />
      <WhyMensaena />
      <HowItWorks />
      <ModulesOverview />
      <CTASection />
      <PublicFooter />
    </main>
  )
}
