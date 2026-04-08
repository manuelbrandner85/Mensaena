'use client'

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import Link from 'next/link'
import { Building2, ArrowLeft } from 'lucide-react'
import SuggestionForm from '../components/SuggestionForm'
import { useOrganizationStore } from '../stores/useOrganizationStore'

export default function SuggestOrganizationPage() {
  const [userId, setUserId] = useState<string | null>(null)
  const { submitSuggestion, submitting } = useOrganizationStore()

  useEffect(() => {
    const supabase = createClient()
    supabase.auth.getSession().then(({ data }) => {
      setUserId(data.session?.user?.id ?? null)
    })
  }, [])

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <div className="bg-gradient-to-br from-emerald-600 via-emerald-500 to-teal-500 px-4 pt-6 pb-8">
        <div className="max-w-2xl mx-auto">
          <Link
            href="/dashboard/organizations"
            className="inline-flex items-center gap-1.5 text-sm text-white/80 hover:text-white mb-3 transition-colors"
          >
            <ArrowLeft className="w-4 h-4" />
            Zurueck zur Uebersicht
          </Link>
          <div className="flex items-center gap-2 mb-1">
            <Building2 className="w-6 h-6 text-white/80" />
            <span className="text-white/80 text-sm font-medium">Organisation vorschlagen</span>
          </div>
          <h1 className="text-2xl font-bold text-white mb-1">Neue Organisation vorschlagen</h1>
          <p className="text-emerald-100 text-sm">
            Hilf uns, das Verzeichnis zu erweitern! Schlage eine Hilfsorganisation vor, die noch fehlt.
          </p>
        </div>
      </div>

      <div className="max-w-2xl mx-auto px-4 -mt-4">
        <SuggestionForm
          userId={userId}
          onSubmit={submitSuggestion}
          submitting={submitting}
        />
      </div>
    </div>
  )
}
