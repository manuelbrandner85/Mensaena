'use client'

import { useEffect } from 'react'
import { useOrganizationStore } from '../stores/useOrganizationStore'

/**
 * Detail hook – loads single organization by slug, plus its reviews.
 */
export function useOrganizationDetail(slugOrId: string) {
  const store = useOrganizationStore()

  useEffect(() => {
    if (!slugOrId) return
    store.loadOrganizationBySlug(slugOrId)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [slugOrId])

  // Load reviews once we have the org
  useEffect(() => {
    if (!store.currentOrganization?.id) return
    store.loadReviews(store.currentOrganization.id)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [store.currentOrganization?.id])

  return {
    organization: store.currentOrganization,
    reviews: store.reviews,
    loading: store.loadingDetail,
    loadingReviews: store.loadingReviews,
    hasMoreReviews: store.hasMoreReviews,
    submitting: store.submitting,
    loadMoreReviews: store.loadMoreReviews,
    createReview: store.createReview,
    updateReview: store.updateReview,
    deleteReview: store.deleteReview,
    toggleHelpful: store.toggleHelpful,
    reportReview: store.reportReview,
  }
}
