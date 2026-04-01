import ModulePage from '@/components/shared/ModulePage'
import { Car } from 'lucide-react'

export default function MobilityPage() {
  return (
    <ModulePage
      title="Mobilität"
      description="Mitfahrgelegenheiten, Transporthilfe, Fahrten koordinieren – lokal organisiert"
      icon={<Car className="w-6 h-6 text-white" />}
      color="bg-gradient-to-r from-indigo-500 to-blue-600"
      postTypes={['mobility', 'help_offer', 'help_request']}
      createTypes={[
        { value: 'mobility',     label: '🚗 Fahrt anbieten'   },
        { value: 'help_request', label: '🔴 Fahrt suchen'     },
        { value: 'help_offer',   label: '🟢 Transporthilfe'   },
      ]}
      categories={[
        { value: 'mobility',  label: '🚌 Mitfahrt'         },
        { value: 'moving',    label: '📦 Transport'        },
        { value: 'everyday',  label: '🛒 Besorgungen'      },
        { value: 'general',   label: '🌿 Sonstiges'        },
      ]}
      emptyText="Noch keine Mobilitäts-Angebote"
    />
  )
}
