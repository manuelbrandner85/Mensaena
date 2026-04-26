'use client'

import { useParams } from 'next/navigation'
import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { Building2 } from 'lucide-react'
import { useOrganizationDetail } from '../hooks/useOrganizationDetail'
import OrganizationDetail from '../components/OrganizationDetail'
import OrganizationReviews from '../components/OrganizationReviews'
import { useOrganizationStore } from '../stores/useOrganizationStore'
import OrganizationMembership from '@/components/features/OrganizationMembership'

export default function OrganizationDetailPage() {
  const params = useParams()
  const slugOrId = params.orgId as string
  const [userId, setUserId] = useState<string | null>(null)

  const {
    organization, reviews, loading, loadingReviews,
    hasMoreReviews, submitting,
    loadMoreReviews, createReview, updateReview, deleteReview,
    toggleHelpful, reportReview,
  } = useOrganizationDetail(slugOrId)

  // Get user session
  useEffect(() => {
    const supabase = createClient()
    supabase.auth.getSession().then(({ data }) => {
      setUserId(data.session?.user?.id ?? null)
    })
  }, [])

  if (loading) {
    return (
      <div className="min-h-screen bg-stone-50 p-4">
        <div className="max-w-4xl mx-auto animate-pulse">
          <div className="h-4 bg-stone-200 rounded w-32 mb-6" />
          <div className="bg-white rounded-2xl border border-stone-100 p-6">
            <div className="flex items-start gap-4">
              <div className="w-14 h-14 bg-stone-100 rounded-2xl" />
              <div className="flex-1">
                <div className="h-6 bg-stone-100 rounded w-3/4 mb-3" />
                <div className="h-4 bg-stone-50 rounded w-1/2 mb-2" />
                <div className="h-4 bg-stone-50 rounded w-1/3" />
              </div>
            </div>
          </div>
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-4 mt-4">
            <div className="lg:col-span-2 bg-white rounded-2xl border border-stone-100 p-6 h-40" />
            <div className="bg-white rounded-2xl border border-stone-100 p-6 h-40" />
          </div>
        </div>
      </div>
    )
  }

  if (!organization) {
    return (
      <div className="min-h-screen bg-stone-50 flex items-center justify-center p-4">
        <div className="text-center">
          <Building2 className="w-12 h-12 text-stone-400 mx-auto mb-3" />
          <h1 className="text-lg font-bold text-ink-700">Organisation nicht gefunden</h1>
          <p className="text-ink-500 text-sm mt-1">Die angeforderte Organisation existiert nicht oder ist nicht mehr aktiv.</p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-stone-50 p-4">
      <OrganizationDetail organization={organization} />

      {/* Reviews section */}
      <div className="max-w-4xl mx-auto mt-6">
        <OrganizationReviews
          orgId={organization.id}
          reviews={reviews}
          loading={loadingReviews}
          hasMore={hasMoreReviews}
          submitting={submitting}
          userId={userId}
          ratingAvg={organization.rating_avg}
          ratingCount={organization.rating_count}
          onCreateReview={createReview}
          onUpdateReview={updateReview}
          onDeleteReview={deleteReview}
          onToggleHelpful={toggleHelpful}
          onReport={reportReview}
          onLoadMore={loadMoreReviews}
        />
      </div>

      {/* Members & invite codes */}
      <div className="max-w-4xl mx-auto mt-6">
        <OrganizationMembership organizationId={organization.id} currentUserId={userId ?? undefined} />
      </div>
    </div>
  )
}
