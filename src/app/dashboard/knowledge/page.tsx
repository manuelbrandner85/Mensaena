export const runtime = 'edge'
import ModulePage from '@/components/shared/ModulePage'
import { BookOpen } from 'lucide-react'

export default function KnowledgePage() {
  return (
    <ModulePage
      title="Bildung & Wissen"
      description="Guides, Tutorials, Naturwissen, Selbstversorgung – Wissen teilen und lernen"
      icon={<BookOpen className="w-6 h-6 text-white" />}
      color="bg-gradient-to-r from-emerald-500 to-teal-600"
      postTypes={['knowledge', 'help_offer', 'skill']}
      createTypes={[
        { value: 'knowledge',  label: '📚 Wissen teilen'    },
        { value: 'skill',      label: '🎓 Skill anbieten'   },
        { value: 'help_offer', label: '🟢 Unterrichten'     },
      ]}
      categories={[
        { value: 'knowledge',  label: '📖 Guides'           },
        { value: 'skills',     label: '🛠️ Fähigkeiten'      },
        { value: 'general',    label: '🌿 Naturwissen'      },
        { value: 'mental',     label: '🧠 Selbstversorgung' },
      ]}
      emptyText="Noch keine Wissens-Beiträge"
    />
  )
}
