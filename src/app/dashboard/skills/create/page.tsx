'use client'

import { Wrench } from 'lucide-react'
import CreatePostPage from '@/components/shared/CreatePostPage'

/** Full-Page Create-Formular für das Skills-Modul */
export default function SkillsCreatePage() {
  return (
    <CreatePostPage
      moduleKey="skills"
      moduleTitle="Neuer Skill-Beitrag"
      moduleDescription="Teile deine Fähigkeiten, suche Mentoren oder biete Workshops an."
      gradientFrom="from-purple-500"
      gradientTo="to-violet-400"
      ringColor="ring-purple-400"
      iconComponent={<Wrench className="w-6 h-6" />}
      createTypes={[
        { value: 'sharing',   label: '⭐ Skill anbieten', cat: 'skills' },
        { value: 'rescue',    label: '🔍 Skill suchen',   cat: 'skills' },
        { value: 'community', label: '🎯 Mentoring',      cat: 'skills' },
      ]}
      categories={[
        { value: 'skills',    label: 'Skills' },
        { value: 'knowledge', label: 'Wissen' },
        { value: 'general',   label: 'Allgemein' },
      ]}
      returnRoute="/dashboard/skills"
    />
  )
}
