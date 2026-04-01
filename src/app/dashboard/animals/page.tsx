export const runtime = 'edge'
import ModulePage from '@/components/shared/ModulePage'
import { PawPrint } from 'lucide-react'

export default function AnimalsPage() {
  return (
    <ModulePage
      title="Tierhilfe"
      description="Tierheime, Vermittlung, Gassi-Geher, vermisste Tiere – alles an einem Ort"
      icon={<PawPrint className="w-6 h-6 text-white" />}
      color="bg-gradient-to-r from-pink-500 to-rose-600"
      postTypes={['animal', 'help_offer', 'help_request']}
      createTypes={[
        { value: 'animal',       label: '🐾 Tierhilfe anbieten' },
        { value: 'help_request', label: '🔴 Tier sucht Hilfe'   },
        { value: 'help_offer',   label: '🟢 Ich helfe Tieren'   },
      ]}
      categories={[
        { value: 'animals',   label: '🐶 Vermittlung'        },
        { value: 'everyday',  label: '🐱 Pflege / Gassi'     },
        { value: 'emergency', label: '🚨 Notfall Tier'       },
        { value: 'general',   label: '🌿 Sonstiges'          },
      ]}
      emptyText="Noch keine Tierhilfe-Beiträge"
    />
  )
}
