'use client'

import { Sprout } from 'lucide-react'
import CreatePostPage from '@/components/shared/CreatePostPage'

/** Full-Page Create-Formular für das Ernte-Modul */
export default function HarvestCreatePage() {
  return (
    <CreatePostPage
      moduleKey="harvest"
      moduleTitle="Neuer Ernte-Beitrag"
      moduleDescription="Teile Ernte, suche Erntehelfer oder biete Lebensmittel an."
      gradientFrom="from-green-500"
      gradientTo="to-primary-300"
      ringColor="ring-green-400"
      iconComponent={<Sprout className="w-6 h-6" />}
      createTypes={[
        { value: 'sharing',   label: '🌾 Ernte teilen', cat: 'food' },
        { value: 'community', label: '🤝 Erntehelfer gesucht', cat: 'food' },
        { value: 'rescue',    label: '🍎 Lebensmittel retten', cat: 'food' },
      ]}
      categories={[
        { value: 'food',    label: 'Lebensmittel' },
        { value: 'general', label: 'Allgemein' },
      ]}
      returnRoute="/dashboard/harvest"
    />
  )
}
