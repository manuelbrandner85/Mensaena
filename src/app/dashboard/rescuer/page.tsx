export const runtime = 'edge'
import ModulePage from '@/components/shared/ModulePage'
import { ShieldAlert } from 'lucide-react'

export default function RescuerPage() {
  return (
    <ModulePage
      title="Retter-System"
      description="Rette Ressourcen – Lebensmittel, Kleidung, Gegenstände sinnvoll weitergeben"
      icon={<ShieldAlert className="w-6 h-6 text-white" />}
      color="bg-gradient-to-r from-orange-500 to-orange-700"
      postTypes={['rescue', 'help_offer', 'help_request']}
      createTypes={[
        { value: 'rescue',       label: '🧡 Ressourcen retten' },
        { value: 'help_offer',   label: '🟢 Hilfe anbieten'    },
        { value: 'help_request', label: '🔴 Hilfe suchen'      },
      ]}
      categories={[
        { value: 'food',      label: '🍎 Lebensmittel'  },
        { value: 'everyday',  label: '👕 Kleidung'      },
        { value: 'sharing',   label: '📦 Gegenstände'   },
        { value: 'general',   label: '🌿 Sonstiges'     },
      ]}
      emptyText="Noch keine Retter-Angebote"
    />
  )
}
