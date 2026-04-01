export const runtime = 'edge'
import ModulePage from '@/components/shared/ModulePage'
import { Shuffle } from 'lucide-react'

export default function SharingPage() {
  return (
    <ModulePage
      title="Teilen & Tauschen"
      description="Geräte teilen, Kleidung & Bücher tauschen – gemeinsam statt neu kaufen"
      icon={<Shuffle className="w-6 h-6 text-white" />}
      color="bg-gradient-to-r from-teal-500 to-emerald-600"
      postTypes={['sharing', 'help_offer', 'help_request']}
      createTypes={[
        { value: 'sharing',      label: '🔄 Teilen / Tauschen'  },
        { value: 'help_offer',   label: '🟢 Anbieten'           },
        { value: 'help_request', label: '🔴 Suchen'             },
      ]}
      categories={[
        { value: 'sharing',   label: '📱 Geräte'           },
        { value: 'everyday',  label: '👕 Kleidung'         },
        { value: 'knowledge', label: '📚 Bücher'           },
        { value: 'general',   label: '🌿 Sonstiges'        },
      ]}
      emptyText="Noch keine Tausch-Angebote"
    />
  )
}
