'use client'

import { BookOpen } from 'lucide-react'
import CreatePostPage from '@/components/shared/CreatePostPage'

/** Full-Page Create-Formular für das Wissens-Modul */
export default function KnowledgeCreatePage() {
  return (
    <CreatePostPage
      moduleKey="knowledge"
      moduleTitle="Neuer Wissens-Beitrag"
      moduleDescription="Teile Wissen, erstelle Anleitungen oder biete Kurse an."
      gradientFrom="from-indigo-500"
      gradientTo="to-violet-400"
      ringColor="ring-indigo-400"
      iconComponent={<BookOpen className="w-6 h-6" />}
      createTypes={[
        { value: 'community', label: '📚 Anleitung/Guide', cat: 'knowledge' },
        { value: 'sharing',   label: '🎓 Kurs anbieten',  cat: 'knowledge' },
        { value: 'rescue',    label: '❓ Wissen gesucht',  cat: 'knowledge' },
      ]}
      categories={[
        { value: 'knowledge', label: 'Wissen' },
        { value: 'skills',    label: 'Skills' },
        { value: 'general',   label: 'Allgemein' },
      ]}
      returnRoute="/dashboard/knowledge"
    />
  )
}
