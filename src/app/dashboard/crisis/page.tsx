export const runtime = 'edge'
import ModulePage from '@/components/shared/ModulePage'
import { Siren } from 'lucide-react'

export default function CrisisPage() {
  return (
    <ModulePage
      title="🚨 Krisensystem"
      description="Notfall-Hilfe, schnelle Helfer-Zuweisung, Essensversorgung – sofortige Hilfe"
      icon={<Siren className="w-6 h-6 text-white" />}
      color="bg-gradient-to-r from-red-600 to-rose-700"
      postTypes={['crisis', 'help_request', 'help_offer']}
      createTypes={[
        { value: 'crisis',       label: '🚨 Notfall melden'    },
        { value: 'help_request', label: '🔴 Dringend Hilfe'    },
        { value: 'help_offer',   label: '🟢 Ich helfe sofort'  },
      ]}
      categories={[
        { value: 'emergency', label: '🆘 Notfall'            },
        { value: 'food',      label: '🍎 Essensversorgung'   },
        { value: 'housing',   label: '🏠 Unterkunft'        },
        { value: 'general',   label: '🌿 Sonstige Hilfe'    },
      ]}
      emptyText="Keine aktiven Notfälle – gut so!"
    />
  )
}
