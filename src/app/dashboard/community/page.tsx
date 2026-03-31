import ModulePage from '@/components/shared/ModulePage'
import { Users } from 'lucide-react'

export default function CommunityPage() {
  return (
    <ModulePage
      title="Community & Abstimmung"
      description="Lokale Abstimmungen, Probleme melden, gemeinsam Lösungen finden"
      icon={<Users className="w-6 h-6 text-white" />}
      color="bg-gradient-to-r from-violet-500 to-purple-700"
      postTypes={['community', 'help_offer', 'help_request']}
      createTypes={[
        { value: 'community',    label: '🗳️ Abstimmung'       },
        { value: 'help_request', label: '🔴 Problem melden'   },
        { value: 'help_offer',   label: '🟢 Lösung anbieten'  },
      ]}
      categories={[
        { value: 'community', label: '🏘️ Lokal'             },
        { value: 'general',   label: '📢 Ankündigung'       },
        { value: 'knowledge', label: '💡 Idee'              },
        { value: 'emergency', label: '🚨 Problem'           },
      ]}
      emptyText="Noch keine Community-Beiträge"
    />
  )
}
