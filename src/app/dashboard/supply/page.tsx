import ModulePage from '@/components/shared/ModulePage'
import { Wheat } from 'lucide-react'

export default function SupplyPage() {
  return (
    <ModulePage
      title="Regionale Versorgung"
      description="Bauernhöfe, Produkte, Erntehilfe, Abholung – direkt aus der Region"
      icon={<Wheat className="w-6 h-6 text-white" />}
      color="bg-gradient-to-r from-yellow-500 to-amber-600"
      postTypes={['supply', 'help_offer', 'help_request']}
      createTypes={[
        { value: 'supply',       label: '🌾 Produkt anbieten'  },
        { value: 'help_request', label: '🔴 Produkt suchen'    },
        { value: 'help_offer',   label: '🟢 Erntehilfe'        },
      ]}
      categories={[
        { value: 'food',      label: '🍎 Lebensmittel'    },
        { value: 'sharing',   label: '📦 Tauschen'        },
        { value: 'skills',    label: '🌱 Erntehilfe'      },
        { value: 'general',   label: '🌿 Sonstiges'       },
      ]}
      emptyText="Noch keine Versorgungsangebote"
    />
  )
}
