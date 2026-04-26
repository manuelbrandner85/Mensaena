'use client'

import { useState, useEffect } from 'react'
import { useRouter, useParams } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import CrisisDetail from '../components/CrisisDetail'
import CrisisSkeleton from '../components/CrisisSkeleton'
import { useCrisisDetail } from '../hooks/useCrisisDetail'
import { useCrisisHelpers } from '../hooks/useCrisisHelpers'

export default function CrisisDetailPage() {
  const router = useRouter()
  const params = useParams()
  const crisisId = params.crisisId as string
  const [userId, setUserId] = useState<string | null>(null)
  const [authLoading, setAuthLoading] = useState(true)

  useEffect(() => {
    const supabase = createClient()
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (!session?.user) {
        router.replace('/auth?mode=login')
        return
      }
      setUserId(session.user.id)
      setAuthLoading(false)
    })
  }, [router])

  const {
    crisis, updates, loading, loadingUpdates,
    updateCrisisStatus, verifyCrisis, markFalseAlarm,
    addUpdate,
  } = useCrisisDetail(crisisId)

  const {
    helpers, loading: loadingHelpers,
    offerHelp, withdrawHelp, updateHelperStatus,
  } = useCrisisHelpers(crisisId, userId ?? undefined)

  if (authLoading || loading) {
    return <CrisisSkeleton count={2} />
  }

  if (!crisis) {
    return (
      <div className="text-center py-16">
        <p className="text-lg font-bold text-ink-800 mb-2">Krise nicht gefunden</p>
        <p className="text-sm text-ink-500 mb-4">Diese Krise existiert nicht oder wurde gelöscht.</p>
        <button
          onClick={() => router.push('/dashboard/crisis')}
          className="px-4 py-2 bg-red-600 text-white rounded-xl text-sm font-medium hover:bg-red-700"
        >
          Zurück zur Übersicht
        </button>
      </div>
    )
  }

  if (!userId) return null

  return (
    <CrisisDetail
      crisis={crisis}
      updates={updates}
      helpers={helpers}
      userId={userId}
      loading={loading}
      loadingUpdates={loadingUpdates}
      loadingHelpers={loadingHelpers}
      onUpdateStatus={updateCrisisStatus}
      onVerify={verifyCrisis}
      onFalseAlarm={markFalseAlarm}
      onAddUpdate={addUpdate}
      onOfferHelp={offerHelp}
      onWithdrawHelp={withdrawHelp}
      onUpdateHelperStatus={updateHelperStatus}
    />
  )
}
