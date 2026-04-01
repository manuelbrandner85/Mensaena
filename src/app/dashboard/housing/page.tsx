import ModulePage from '@/components/shared/ModulePage'
import { Home } from 'lucide-react'

export default function HousingPage() {
  return (
    <ModulePage
      title="Wohnen & Alltag"
      description="Wohnungen, Notunterkünfte, Umzugshilfe, Haushaltshilfe – lokale Unterstützung"
      icon={<Home className="w-6 h-6 text-white" />}
      color="bg-gradient-to-r from-blue-500 to-blue-700"
      postTypes={['housing', 'help_offer', 'help_request']}
      createTypes={[
        { value: 'housing',      label: '🏡 Wohnung anbieten'  },
        { value: 'help_request', label: '🔴 Wohnung suchen'    },
        { value: 'help_offer',   label: '🟢 Umzugshilfe'       },
      ]}
      categories={[
        { value: 'housing',   label: '🏠 Wohnangebot'      },
        { value: 'moving',    label: '📦 Umzug'            },
        { value: 'everyday',  label: '🧹 Haushaltshilfe'   },
        { value: 'emergency', label: '🚨 Notunterkunft'    },
        { value: 'general',   label: '🌿 Sonstiges'        },
      ]}
      emptyText="Noch keine Wohn-Beiträge"
    />
  )
}
