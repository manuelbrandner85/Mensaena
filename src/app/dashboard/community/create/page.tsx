'use client'

import { Users } from 'lucide-react'
import CreatePostPage from '@/components/shared/CreatePostPage'

/** Full-Page Create-Formular für das Community-Modul */
export default function CommunityCreatePage() {
  return (
    <CreatePostPage
      moduleKey="community"
      moduleTitle="Neuer Community-Beitrag"
      moduleDescription="Starte eine Diskussion, teile eine Idee oder stelle eine Frage."
      gradientFrom="from-mn-amber/8"
      gradientTo="to-mn-amber-warm"
      ringColor="ring-violet-400"
      iconComponent={<Users className="w-6 h-6" />}
      createTypes={[
        { value: 'community', label: '💡 Idee / Vorschlag' },
        { value: 'rescue',    label: '❓ Frage an die Community' },
      ]}
      categories={[
        { value: 'community', label: 'Community' },
        { value: 'general',   label: 'Allgemein' },
      ]}
      returnRoute="/dashboard/community"
    />
  )
}
