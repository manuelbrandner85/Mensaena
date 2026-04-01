export const runtime = 'edge'
import ModulePage from '@/components/shared/ModulePage'
import { Wrench } from 'lucide-react'

export default function SkillsPage() {
  return (
    <ModulePage
      title="Skill-Netzwerk"
      description="Fähigkeiten anbieten, voneinander lernen, Mentoring – gemeinsam wachsen"
      icon={<Wrench className="w-6 h-6 text-white" />}
      color="bg-gradient-to-r from-purple-500 to-violet-600"
      postTypes={['skill', 'help_offer', 'help_request']}
      createTypes={[
        { value: 'skill',        label: '⭐ Skill anbieten'   },
        { value: 'help_request', label: '🔴 Skill suchen'     },
        { value: 'help_offer',   label: '🎓 Mentoring'        },
      ]}
      categories={[
        { value: 'skills',    label: '🛠️ Handwerk'         },
        { value: 'knowledge', label: '💻 Digital'           },
        { value: 'general',   label: '🎨 Kreativität'       },
        { value: 'mental',    label: '🌱 Persönlichkeit'    },
      ]}
      emptyText="Noch keine Skills geteilt"
    />
  )
}
