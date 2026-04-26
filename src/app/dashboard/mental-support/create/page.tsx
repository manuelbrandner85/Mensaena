'use client'

import { Heart, Shield } from 'lucide-react'
import CreatePostPage from '@/components/shared/CreatePostPage'

/** Full-Page Create-Formular für das Mental-Support-Modul */
export default function MentalSupportCreatePage() {
  return (
    <CreatePostPage
      moduleKey="mental-support"
      moduleTitle="Neuer Beitrag – Mentale Unterstützung"
      moduleDescription="Teile Gedanken, suche Unterstützung oder biete Hilfe an. Anonym möglich."
      gradientFrom="from-rose-400"
      gradientTo="to-pink-400"
      ringColor="ring-rose-400"
      iconComponent={<Heart className="w-6 h-6" />}
      createTypes={[
        { value: 'community', label: '💬 Gedanken teilen',     cat: 'mental' },
        { value: 'rescue',    label: '🤗 Unterstützung suchen', cat: 'mental' },
        { value: 'sharing',   label: '🌱 Hilfe anbieten',       cat: 'mental' },
      ]}
      categories={[
        { value: 'mental',  label: 'Mental' },
        { value: 'general', label: 'Allgemein' },
      ]}
      returnRoute="/dashboard/mental-support"
      showAnonymous
      topBanner={
        <div className="mb-6 bg-cyan-50 border border-cyan-200 rounded-2xl p-4 flex items-start gap-3">
          <Shield className="w-5 h-5 text-cyan-600 flex-shrink-0 mt-0.5" />
          <div>
            <p className="text-sm font-semibold text-cyan-900">Du bist nicht allein 💙</p>
            <p className="text-xs text-cyan-700 mt-0.5">
              Alle Beiträge können anonym veröffentlicht werden. Bei akuten Krisen wende dich bitte an die Hotlines.
            </p>
          </div>
        </div>
      }
    />
  )
}
