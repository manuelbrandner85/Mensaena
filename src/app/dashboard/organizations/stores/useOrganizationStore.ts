import { create } from 'zustand'
import { createClient } from '@/lib/supabase/client'

// ── Sanitize helpers für PostgREST .or()/ilike ───────────────────────────────
function escapeIlike(s: string): string {
  return s.replace(/\\/g, '\\\\').replace(/%/g, '\\%').replace(/_/g, '\\_')
}
function sanitizeForOrFilter(s: string): string {
  return s.replace(/[,()"\\]/g, '').trim()
}

import type {
  Organization, OrganizationReview, OrganizationSuggestion,
  OrganizationStats, OrganizationFilter,
  CreateReviewInput, UpdateReviewInput, CreateSuggestionInput,
} from '../types'
import { PAGE_SIZE, REVIEW_PAGE_SIZE } from '../types'

interface OrganizationState {
  // Data
  organizations: Organization[]
  currentOrganization: Organization | null
  reviews: OrganizationReview[]
  suggestions: OrganizationSuggestion[]
  stats: OrganizationStats | null

  // Loading
  loading: boolean
  loadingDetail: boolean
  loadingReviews: boolean
  loadingStats: boolean
  submitting: boolean

  // Pagination
  page: number
  hasMore: boolean
  reviewPage: number
  hasMoreReviews: boolean

  // Filters
  filters: OrganizationFilter

  // Actions – Data loading
  loadOrganizations: () => Promise<void>
  loadMoreOrganizations: () => Promise<void>
  loadOrganizationBySlug: (slug: string) => Promise<void>
  loadReviews: (orgId: string) => Promise<void>
  loadMoreReviews: (orgId: string) => Promise<void>
  loadStats: () => Promise<void>
  loadSuggestions: () => Promise<void>

  // Actions – Reviews
  createReview: (input: CreateReviewInput, userId: string) => Promise<void>
  updateReview: (reviewId: string, input: UpdateReviewInput) => Promise<void>
  deleteReview: (reviewId: string, orgId: string) => Promise<void>
  toggleHelpful: (reviewId: string, userId: string) => Promise<void>
  reportReview: (reviewId: string, reason: string) => Promise<void>
  respondToReview: (reviewId: string, response: string) => Promise<void>

  // Actions – Suggestions
  submitSuggestion: (input: CreateSuggestionInput, userId: string) => Promise<void>
  approveSuggestion: (id: string) => Promise<void>
  rejectSuggestion: (id: string, notes: string) => Promise<void>

  // Actions – Admin
  uploadImage: (file: File) => Promise<string>

  // Actions – Filters
  setFilters: (filters: Partial<OrganizationFilter>) => void
  resetFilters: () => void
}

const defaultFilters: OrganizationFilter = {
  search: '',
  category: 'all',
  country: 'all',
  verified_only: false,
  is_emergency: false,
  has_reviews: false,
  min_rating: 0,
  sort_by: 'name',
  radius_km: 50,
}

export const useOrganizationStore = create<OrganizationState>((set, get) => ({
  organizations: [],
  currentOrganization: null,
  reviews: [],
  suggestions: [],
  stats: null,
  loading: false,
  loadingDetail: false,
  loadingReviews: false,
  loadingStats: false,
  submitting: false,
  page: 0,
  hasMore: true,
  reviewPage: 0,
  hasMoreReviews: true,
  filters: { ...defaultFilters },

  // ── Load Organizations via RPC ────────────────────────────────────────

  loadOrganizations: async () => {
    set({ loading: true, page: 0 })
    const supabase = createClient()
    const { filters } = get()

    // Try v2 RPC first, then v1, then direct query
    const rpcArgs = {
      p_search: filters.search || '',
      p_category: filters.category !== 'all' ? filters.category : null,
      p_verified_only: filters.verified_only,
      p_lat: filters.latitude ?? null,
      p_lng: filters.longitude ?? null,
      p_radius_km: filters.radius_km,
      p_limit: PAGE_SIZE,
      p_offset: 0,
    }

    // Try search_organizations_v2
    const { data, error } = await supabase.rpc('search_organizations_v2', rpcArgs as any)

    if (!error && data) {
      set({
        organizations: data as Organization[],
        hasMore: data.length === PAGE_SIZE,
      })
    } else {
      // Fallback: try v1 RPC
      const { data: v1Data, error: v1Error } = await supabase.rpc('search_organizations', {
        ...rpcArgs,
        p_country: filters.country,
        p_is_emergency: filters.is_emergency,
        p_min_rating: filters.min_rating,
        p_sort_by: filters.sort_by,
      } as any)

      if (!v1Error && v1Data) {
        set({
          organizations: v1Data as Organization[],
          hasMore: v1Data.length === PAGE_SIZE,
        })
      } else {
        // Final fallback: direct query
        let query = supabase
          .from('organizations')
          .select('*')
          .order('name')
          .range(0, PAGE_SIZE - 1)

        if (filters.category !== 'all') query = query.eq('category', filters.category)
        const sanitizedSearch = sanitizeForOrFilter(filters.search ?? '')
        if (sanitizedSearch) {
          const term = escapeIlike(sanitizedSearch)
          query = query.or(`name.ilike.%${term}%,address.ilike.%${term}%,description.ilike.%${term}%,city.ilike.%${term}%`)
        }
        if (filters.verified_only) query = query.eq('is_verified', true)

        const { data: fallbackData, error: fallbackErr } = await query
        if (fallbackErr) console.error('organizations fallback query failed:', fallbackErr.message)
        set({
          organizations: (fallbackData ?? []) as Organization[],
          hasMore: (fallbackData ?? []).length === PAGE_SIZE,
        })
      }
    }
    set({ loading: false })
  },

  loadMoreOrganizations: async () => {
    const { page, hasMore, loading, filters } = get()
    if (!hasMore || loading) return
    const nextPage = page + 1
    const supabase = createClient()

    const rpcArgs = {
      p_search: filters.search || '',
      p_category: filters.category !== 'all' ? filters.category : null,
      p_verified_only: filters.verified_only,
      p_lat: filters.latitude ?? null,
      p_lng: filters.longitude ?? null,
      p_radius_km: filters.radius_km,
      p_limit: PAGE_SIZE,
      p_offset: nextPage * PAGE_SIZE,
    }

    // Try v2 first, then v1
    let result = await supabase.rpc('search_organizations_v2', rpcArgs as any)
    if (result.error) {
      result = await supabase.rpc('search_organizations', {
        ...rpcArgs,
        p_country: filters.country,
        p_is_emergency: filters.is_emergency,
        p_min_rating: filters.min_rating,
        p_sort_by: filters.sort_by,
      } as any)
    }

    if (!result.error && result.data) {
      set(s => ({
        organizations: [...s.organizations, ...(result.data as Organization[])],
        page: nextPage,
        hasMore: result.data.length === PAGE_SIZE,
      }))
    }
  },

  // ── Load Organization by Slug ─────────────────────────────────────────

  loadOrganizationBySlug: async (slug: string) => {
    set({ loadingDetail: true, currentOrganization: null })
    const supabase = createClient()

    // Try by ID first (slug column may not exist), then fallback by name
    let { data, error } = await supabase
      .from('organizations')
      .select('*')
      .eq('id', slug)
      .eq('is_active', true)
      .maybeSingle()
    if (error) console.error('loadOrganizationBySlug by-id failed:', error.message)

    if (!data) {
      // Try by name (slugified) — escape ilike wildcards in segments and re-join
      const term = slug.split('-').map(escapeIlike).join('%')
      const res = await supabase
        .from('organizations')
        .select('*')
        .ilike('name', `%${term}%`)
        .eq('is_active', true)
        .limit(1)
        .maybeSingle()
      if (res.error) console.error('loadOrganizationBySlug by-name failed:', res.error.message)
      data = res.data
    }

    if (data) {
      set({ currentOrganization: data as Organization })
    }
    set({ loadingDetail: false })
  },

  // ── Load Reviews ──────────────────────────────────────────────────────

  loadReviews: async (orgId: string) => {
    set({ loadingReviews: true, reviewPage: 0, reviews: [] })
    const supabase = createClient()

    const { data, error } = await supabase
      .from('organization_reviews')
      .select('*, profiles:user_id(name, avatar_url)')
      .eq('organization_id', orgId)
      .order('created_at', { ascending: false })
      .range(0, REVIEW_PAGE_SIZE - 1)
    if (error) console.error('loadReviews failed:', error.message)

    if (data) {
      set({
        reviews: data as OrganizationReview[],
        hasMoreReviews: data.length === REVIEW_PAGE_SIZE,
      })
    }
    set({ loadingReviews: false })
  },

  loadMoreReviews: async (orgId: string) => {
    const { reviewPage, hasMoreReviews, loadingReviews } = get()
    if (!hasMoreReviews || loadingReviews) return
    const nextPage = reviewPage + 1
    const supabase = createClient()

    const { data, error } = await supabase
      .from('organization_reviews')
      .select('*, profiles:user_id(name, avatar_url)')
      .eq('organization_id', orgId)
      .order('created_at', { ascending: false })
      .range(nextPage * REVIEW_PAGE_SIZE, (nextPage + 1) * REVIEW_PAGE_SIZE - 1)
    if (error) console.error('loadMoreReviews failed:', error.message)

    if (data) {
      set(s => ({
        reviews: [...s.reviews, ...(data as OrganizationReview[])],
        reviewPage: nextPage,
        hasMoreReviews: data.length === REVIEW_PAGE_SIZE,
      }))
    }
  },

  // ── Load Stats ────────────────────────────────────────────────────────

  loadStats: async () => {
    set({ loadingStats: true })
    const supabase = createClient()

    const { data, error } = await supabase.rpc('get_organization_stats')

    if (!error && data) {
      set({ stats: data as OrganizationStats })
    } else {
      // Fallback: count directly
      const { count } = await supabase
        .from('organizations')
        .select('*', { count: 'exact', head: true })
        .eq('is_active', true)

      set({
        stats: {
          total_organizations: count ?? 0,
          verified_count: 0,
          total_reviews: 0,
          avg_rating: 0,
          categories: [],
        },
      })
    }
    set({ loadingStats: false })
  },

  // ── Load Suggestions (Admin) ──────────────────────────────────────────

  loadSuggestions: async () => {
    const supabase = createClient()
    const { data, error } = await supabase
      .from('organization_suggestions')
      .select('*, profiles!organization_suggestions_user_id_fkey(name, avatar_url)')
      .order('created_at', { ascending: false })
    if (error) console.error('loadSuggestions failed:', error.message)

    if (data) {
      set({ suggestions: data as OrganizationSuggestion[] })
    }
  },

  // ── Create Review ─────────────────────────────────────────────────────

  createReview: async (input, userId) => {
    set({ submitting: true })
    const supabase = createClient()

    const { error } = await supabase.from('organization_reviews').insert({
      organization_id: input.organization_id,
      user_id: userId,
      rating: input.rating,
      comment: input.content,
    })

    if (error) {
      set({ submitting: false })
      throw new Error(error.message)
    }

    // Reload reviews
    await get().loadReviews(input.organization_id)
    // Reload the org to get updated rating
    const { currentOrganization } = get()
    if (currentOrganization) {
      await get().loadOrganizationBySlug(currentOrganization.id)
    }
    set({ submitting: false })
  },

  updateReview: async (reviewId, input) => {
    const supabase = createClient()
    const { error } = await supabase.from('organization_reviews').update(input).eq('id', reviewId)
    if (error) { console.error('updateReview failed:', error.message); throw new Error(error.message) }
    const { currentOrganization } = get()
    if (currentOrganization) {
      await get().loadReviews(currentOrganization.id)
    }
  },

  deleteReview: async (reviewId, orgId) => {
    const supabase = createClient()
    const { error } = await supabase.from('organization_reviews').delete().eq('id', reviewId)
    if (error) { console.error('deleteReview failed:', error.message); throw new Error(error.message) }
    await get().loadReviews(orgId)
    const { currentOrganization } = get()
    if (currentOrganization) {
      await get().loadOrganizationBySlug(currentOrganization.id)
    }
  },

  toggleHelpful: async (reviewId, userId) => {
    const supabase = createClient()
    // Check if already helpful — 0 rows is the normal case on first toggle
    const { data: existing, error: existingErr } = await supabase
      .from('organization_review_helpful')
      .select('id')
      .eq('review_id', reviewId)
      .eq('user_id', userId)
      .maybeSingle()
    if (existingErr) { console.error('toggleHelpful check failed:', existingErr.message); return }

    if (existing) {
      const { error: delErr } = await supabase.from('organization_review_helpful').delete().eq('id', existing.id)
      if (delErr) { console.error('toggleHelpful delete failed:', delErr.message); return }
      // Decrement
      const { error: rpcErr } = await supabase.rpc('decrement_helpful', { p_review_id: reviewId })
      if (rpcErr) {
        // Manual fallback
        const prev = get().reviews.find(r => r.id === reviewId)?.helpful_count ?? 1
        const { error: upErr } = await supabase.from('organization_reviews')
          .update({ helpful_count: Math.max(0, prev - 1) })
          .eq('id', reviewId)
        if (upErr) { console.error('toggleHelpful decrement fallback failed:', upErr.message); return }
      }
    } else {
      const { error: insErr } = await supabase.from('organization_review_helpful').insert({ review_id: reviewId, user_id: userId })
      if (insErr) { console.error('toggleHelpful insert failed:', insErr.message); return }
      const { error: rpcErr } = await supabase.rpc('increment_helpful', { p_review_id: reviewId })
      if (rpcErr) {
        const prev = get().reviews.find(r => r.id === reviewId)?.helpful_count ?? 0
        const { error: upErr } = await supabase.from('organization_reviews')
          .update({ helpful_count: prev + 1 })
          .eq('id', reviewId)
        if (upErr) { console.error('toggleHelpful increment fallback failed:', upErr.message); return }
      }
    }

    // Optimistic update
    set(s => ({
      reviews: s.reviews.map(r =>
        r.id === reviewId
          ? {
              ...r,
              helpful_count: existing ? Math.max(0, r.helpful_count - 1) : r.helpful_count + 1,
              user_found_helpful: !existing,
            }
          : r
      ),
    }))
  },

  reportReview: async (reviewId, reason) => {
    const supabase = createClient()
    await supabase.from('organization_reviews').update({
      is_reported: true,
      report_reason: reason,
    }).eq('id', reviewId)

    set(s => ({
      reviews: s.reviews.map(r =>
        r.id === reviewId ? { ...r, is_reported: true } : r
      ),
    }))
  },

  respondToReview: async (reviewId, response) => {
    const supabase = createClient()
    await supabase.from('organization_reviews').update({
      admin_response: response,
      admin_response_at: new Date().toISOString(),
    }).eq('id', reviewId)

    set(s => ({
      reviews: s.reviews.map(r =>
        r.id === reviewId ? { ...r, admin_response: response, admin_response_at: new Date().toISOString() } : r
      ),
    }))
  },

  // ── Suggestions ───────────────────────────────────────────────────────

  submitSuggestion: async (input, userId) => {
    set({ submitting: true })
    const supabase = createClient()

    const { error } = await supabase.from('organization_suggestions').insert({
      user_id: userId,
      name: input.name,
      description: input.description || null,
      category: input.category,
      address: input.address || null,
      city: input.city || null,
      country: input.country,
      phone: input.phone || null,
      email: input.email || null,
      website: input.website || null,
    })

    if (error) {
      set({ submitting: false })
      throw new Error(error.message)
    }
    set({ submitting: false })
  },

  approveSuggestion: async (id) => {
    const supabase = createClient()
    await supabase.from('organization_suggestions').update({ status: 'approved' }).eq('id', id)
    set(s => ({
      suggestions: s.suggestions.map(sug =>
        sug.id === id ? { ...sug, status: 'approved' as const } : sug
      ),
    }))
  },

  rejectSuggestion: async (id, notes) => {
    const supabase = createClient()
    await supabase.from('organization_suggestions').update({
      status: 'rejected',
      admin_notes: notes,
    }).eq('id', id)
    set(s => ({
      suggestions: s.suggestions.map(sug =>
        sug.id === id ? { ...sug, status: 'rejected' as const, admin_notes: notes } : sug
      ),
    }))
  },

  // ── Upload Image ──────────────────────────────────────────────────────

  uploadImage: async (file) => {
    const supabase = createClient()
    const ext = file.name.split('.').pop()
    const path = `org-${Date.now()}.${ext}`

    const { error } = await supabase.storage
      .from('organization-images')
      .upload(path, file, { cacheControl: '3600', upsert: false })

    if (error) throw new Error(error.message)

    const { data } = supabase.storage.from('organization-images').getPublicUrl(path)
    return data.publicUrl
  },

  // ── Filters ───────────────────────────────────────────────────────────

  setFilters: (partial) => {
    set(s => ({ filters: { ...s.filters, ...partial } }))
  },

  resetFilters: () => {
    set({ filters: { ...defaultFilters } })
  },
}))
