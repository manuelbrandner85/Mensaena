import ModulePage from '@/components/shared/ModulePage'
import { Brain } from 'lucide-react'

export default function MentalSupportPage() {
  return (
    <ModulePage
      title="Mentale Unterstützung"
      description="Gesprächspartner, anonyme Hilfe, naturbasierte Unterstützung – du bist nicht allein"
      icon={<Brain className="w-6 h-6 text-white" />}
      color="bg-gradient-to-r from-cyan-500 to-sky-600"
      postTypes={['mental', 'help_offer', 'help_request']}
      createTypes={[
        { value: 'mental',       label: '💙 Unterstützung anbieten' },
        { value: 'help_request', label: '🔴 Gesprächspartner suchen' },
        { value: 'help_offer',   label: '🟢 Zuhören & Begleiten'    },
      ]}
      categories={[
        { value: 'mental',    label: '💬 Gespräch'         },
        { value: 'general',   label: '🌿 Anonyme Hilfe'    },
        { value: 'community', label: '👥 Lokale Treffen'   },
        { value: 'skills',    label: '🌳 Naturbasiert'     },
      ]}
      emptyText="Noch keine Angebote für mentale Unterstützung"
    />
  )
}
