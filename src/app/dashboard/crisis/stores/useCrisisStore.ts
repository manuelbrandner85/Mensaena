import { create } from 'zustand'
import { createClient } from '@/lib/supabase/client'
import type {
  Crisis, CrisisHelper, CrisisUpdate, CrisisStats, EmergencyNumber,
  CrisisFilters, CreateCrisisInput, CrisisStatus, HelperStatus, UpdateType,
  PAGE_SIZE as _PS,
} from '../types'
import { PAGE_SIZE, MAX_CRISES_PER_DAY, MIN_TRUST_FOR_CRITICAL } from '../types'

interface CrisisState {
  // Data
  crises: Crisis[]
  currentCrisis: Crisis | null
  updates: CrisisUpdate[]
  helpers: CrisisHelper[]
  stats: CrisisStats | null
  emergencyNumbers: EmergencyNumber[]

  // Loading
  loading: boolean
  loadingDetail: boolean
  loadingHelpers: boolean
  loadingUpdates: boolean
  loadingStats: boolean
  creating: boolean

  // Pagination
  page: number
  hasMore: boolean

  // Filters
  filters: CrisisFilters

  // Actions – Data loading
  loadCrises: (userId?: string) => Promise<void>
  loadMoreCrises: () => Promise<void>
  loadCrisisDetail: (crisisId: string) => Promise<void>
  loadHelpers: (crisisId: string) => Promise<void>
  loadUpdates: (crisisId: string) => Promise<void>
  loadStats: () => Promise<void>
  loadEmergencyNumbers: () => Promise<void>

  // Actions – Mutations
  createCrisis: (input: CreateCrisisInput, userId: string) => Promise<Crisis>
  updateCrisisStatus: (crisisId: string, status: CrisisStatus, userId: string) => Promise<void>
  verifyCrisis: (crisisId: string, userId: string) => Promise<void>
  markFalseAlarm: (crisisId: string, userId: string) => Promise<void>
  offerHelp: (crisisId: string, userId: string, message?: string, skills?: string[]) => Promise<void>
  withdrawHelp: (crisisId: string, userId: string) => Promise<void>
  updateHelperStatus: (helperId: string, status: HelperStatus) => Promise<void>
  addUpdate: (crisisId: string, userId: string, content: string, updateType?: UpdateType, imageUrl?: string) => Promise<void>
  uploadImage: (file: File) => Promise<string>

  // Actions – Filters
  setFilters: (filters: Partial<CrisisFilters>) => void
  resetFilters: () => void

  // Actions – Realtime
  handleRealtimeCrisis: (payload: any) => void
  handleRealtimeHelper: (payload: any) => void
  handleRealtimeUpdate: (payload: any) => void
}

/**
 * Enriches crisis rows with profile data via a separate query.
 * This avoids the FK join issue (crises_creator_id_fkey -> auth.users, not profiles).
 */
async function enrichCrisesWithProfiles(supabase: any, crises: Crisis[]): Promise<Crisis[]> {
  if (crises.length === 0) return crises
  const creatorIds = [...new Set(crises.map(c => c.creator_id).filter(Boolean))]
  if (creatorIds.length === 0) return crises

  const { data: profiles } = await supabase
    .from('profiles')
    .select('id, name, display_name, avatar_url, trust_score, is_crisis_volunteer')
    .in('id', creatorIds)

  if (!profiles) return crises

  const profileMap = new Map<string, any>()
  for (const p of profiles) {
    profileMap.set(p.id, p)
  }

  return crises.map(c => ({
    ...c,
    profiles: profileMap.get(c.creator_id) ?? undefined,
  }))
}

const defaultFilters: CrisisFilters = {
  status: 'all',
  category: 'all',
  urgency: 'all',
  search: '',
}

// Strip chars that break PostgREST `or()` filter syntax (`,()"\\`)
function sanitizeForOrFilter(value: string): string {
  return value.replace(/[,()"\\]/g, ' ').trim()
}
// Escape ilike pattern metachars
function escapeIlike(value: string): string {
  return value.replace(/[%_\\]/g, '\\$&')
}

export const useCrisisStore = create<CrisisState>((set, get) => ({
  // Initial state
  crises: [],
  currentCrisis: null,
  updates: [],
  helpers: [],
  stats: null,
  emergencyNumbers: [],
  loading: false,
  loadingDetail: false,
  loadingHelpers: false,
  loadingUpdates: false,
  loadingStats: false,
  creating: false,
  page: 0,
  hasMore: true,
  filters: { ...defaultFilters },

  // ── Load Crises ───────────────────────────────────────────────────

  loadCrises: async () => {
    set({ loading: true, page: 0 })
    const supabase = createClient()
    const { filters } = get()

    // Use direct profiles join via creator_id (FK to auth.users, but profiles.id = auth.users.id)
    let query = supabase
      .from('crises')
      .select('*')
      .order('created_at', { ascending: false })
      .range(0, PAGE_SIZE - 1)

    if (filters.status !== 'all') query = query.eq('status', filters.status)
    else query = query.in('status', ['active', 'in_progress'])

    if (filters.category !== 'all') query = query.eq('category', filters.category)
    if (filters.urgency !== 'all') query = query.eq('urgency', filters.urgency)
    if (filters.search) {
      const safe = escapeIlike(sanitizeForOrFilter(filters.search))
      if (safe) {
        query = query.or(`title.ilike.%${safe}%,description.ilike.%${safe}%,location_text.ilike.%${safe}%`)
      }
    }

    const { data, error } = await query
    if (error) console.error('loadCrises failed:', error.message)
    if (!error && data) {
      // Enrich with profile data
      const enriched = await enrichCrisesWithProfiles(supabase, data as Crisis[])
      set({ crises: enriched, hasMore: data.length === PAGE_SIZE })
    }
    set({ loading: false })
  },

  loadMoreCrises: async () => {
    const { page, hasMore, loading, filters } = get()
    if (!hasMore || loading) return
    const nextPage = page + 1
    const supabase = createClient()

    let query = supabase
      .from('crises')
      .select('*')
      .order('created_at', { ascending: false })
      .range(nextPage * PAGE_SIZE, (nextPage + 1) * PAGE_SIZE - 1)

    if (filters.status !== 'all') query = query.eq('status', filters.status)
    else query = query.in('status', ['active', 'in_progress'])

    if (filters.category !== 'all') query = query.eq('category', filters.category)
    if (filters.urgency !== 'all') query = query.eq('urgency', filters.urgency)
    if (filters.search) {
      const safe = escapeIlike(sanitizeForOrFilter(filters.search))
      if (safe) {
        query = query.or(`title.ilike.%${safe}%,description.ilike.%${safe}%`)
      }
    }

    const { data, error } = await query
    if (error) console.error('loadMoreCrises failed:', error.message)
    if (data) {
      const enriched = await enrichCrisesWithProfiles(supabase, data as Crisis[])
      set(s => ({
        crises: [...s.crises, ...enriched],
        page: nextPage,
        hasMore: data.length === PAGE_SIZE,
      }))
    }
  },

  // ── Load Detail ───────────────────────────────────────────────────

  loadCrisisDetail: async (crisisId) => {
    set({ loadingDetail: true })
    const supabase = createClient()
    const { data, error } = await supabase
      .from('crises')
      .select('*')
      .eq('id', crisisId)
      .maybeSingle()
    if (error) console.error('loadCrisisDetail failed:', error.message)
    if (data) {
      // Enrich single crisis with profile
      const enriched = await enrichCrisesWithProfiles(supabase, [data as Crisis])
      set({ currentCrisis: enriched[0] ?? (data as Crisis) })
    } else {
      set({ currentCrisis: null })
    }
    set({ loadingDetail: false })
  },

  loadHelpers: async (crisisId) => {
    set({ loadingHelpers: true })
    const supabase = createClient()
    const { data } = await supabase
      .from('crisis_helpers')
      .select('*, profiles(name, display_name, avatar_url, trust_score, is_crisis_volunteer, crisis_skills)')
      .eq('crisis_id', crisisId)
      .order('created_at', { ascending: true })
    if (data) set({ helpers: data as CrisisHelper[] })
    set({ loadingHelpers: false })
  },

  loadUpdates: async (crisisId) => {
    set({ loadingUpdates: true })
    const supabase = createClient()
    const { data } = await supabase
      .from('crisis_updates')
      .select('*, profiles(name, avatar_url)')
      .eq('crisis_id', crisisId)
      .order('created_at', { ascending: false })
    if (data) set({ updates: data as CrisisUpdate[] })
    set({ loadingUpdates: false })
  },

  loadStats: async () => {
    set({ loadingStats: true })
    const supabase = createClient()
    const { data } = await supabase.rpc('get_crisis_stats')
    if (data && Array.isArray(data) && data.length > 0) {
      set({ stats: data[0] as CrisisStats })
    } else if (data && !Array.isArray(data)) {
      set({ stats: data as CrisisStats })
    }
    set({ loadingStats: false })
  },

  loadEmergencyNumbers: async () => {
    const supabase = createClient()
    const { data } = await supabase
      .from('emergency_numbers')
      .select('*')
      .order('country')
      .order('sort_order')
    if (data) set({ emergencyNumbers: data as EmergencyNumber[] })
  },

  // ── Create Crisis ─────────────────────────────────────────────────

  createCrisis: async (input, userId) => {
    set({ creating: true })
    const supabase = createClient()

    // Abuse check: max 3 per day
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    const { count } = await supabase
      .from('crises')
      .select('*', { count: 'exact', head: true })
      .eq('creator_id', userId)
      .gte('created_at', today.toISOString())
    if ((count ?? 0) >= MAX_CRISES_PER_DAY) {
      set({ creating: false })
      throw new Error('Du hast heute bereits 3 Krisen gemeldet. Bitte warte bis morgen.')
    }

    // Trust score check for critical
    if (input.urgency === 'critical') {
      const { data: profile, error: profileErr } = await supabase
        .from('profiles')
        .select('trust_score, crisis_banned_until')
        .eq('id', userId)
        .maybeSingle()
      if (profileErr) console.error('crisis trust check profile load failed:', profileErr.message)
      if (profile?.crisis_banned_until && new Date(profile.crisis_banned_until) > new Date()) {
        set({ creating: false })
        throw new Error('Dein Konto ist vorübergehend für Krisenmeldungen gesperrt.')
      }
      if ((profile?.trust_score ?? 0) < MIN_TRUST_FOR_CRITICAL) {
        set({ creating: false })
        throw new Error('Für kritische Meldungen wird ein Vertrauensscore von mindestens 2.0 benötigt.')
      }
    }

    const { data, error } = await supabase
      .from('crises')
      .insert({
        creator_id: userId,
        ...input,
      })
      .select('*')
      .single()

    if (error) {
      set({ creating: false })
      throw new Error(error.message)
    }

    // Try to mobilize helpers if location available
    if (input.latitude && input.longitude) {
      await supabase.rpc('mobilize_nearby_helpers', {
        p_crisis_id: data.id,
        p_radius_km: input.radius_km || 10,
      }).catch(() => {}) // Non-blocking
    }

    set(s => ({ crises: [data as Crisis, ...s.crises], creating: false }))
    return data as Crisis
  },

  // ── Update Status ─────────────────────────────────────────────────

  updateCrisisStatus: async (crisisId, status, userId) => {
    const supabase = createClient()
    const updates: Partial<Crisis> = { status }
    if (status === 'resolved') {
      updates.resolved_at = new Date().toISOString()
      updates.resolved_by = userId
    }
    const { error } = await supabase
      .from('crises')
      .update(updates)
      .eq('id', crisisId)
    if (error) throw new Error(error.message)
    set(s => ({
      crises: s.crises.map(c => c.id === crisisId ? { ...c, ...updates } as Crisis : c),
      currentCrisis: s.currentCrisis?.id === crisisId ? { ...s.currentCrisis, ...updates } as Crisis : s.currentCrisis,
    }))
  },

  verifyCrisis: async (crisisId, userId) => {
    const supabase = createClient()
    const { error } = await supabase
      .from('crises')
      .update({ is_verified: true, verified_by: userId, verified_at: new Date().toISOString() })
      .eq('id', crisisId)
    if (error) throw new Error(error.message)
    set(s => ({
      currentCrisis: s.currentCrisis?.id === crisisId
        ? { ...s.currentCrisis, is_verified: true, verified_by: userId, verified_at: new Date().toISOString() }
        : s.currentCrisis,
    }))
  },

  markFalseAlarm: async (crisisId, userId) => {
    const supabase = createClient()
    const { error } = await supabase
      .from('crises')
      .update({ status: 'false_alarm', false_alarm_by: userId })
      .eq('id', crisisId)
    if (error) throw new Error(error.message)

    // Penalty: get crisis creator and penalize trust
    const { currentCrisis } = get()
    if (currentCrisis?.creator_id) {
      await supabase
        .from('profiles')
        .update({ crisis_banned_until: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString() })
        .eq('id', currentCrisis.creator_id)
        .catch(() => {})
    }

    set(s => ({
      crises: s.crises.map(c => c.id === crisisId ? { ...c, status: 'false_alarm' as const, false_alarm_by: userId } : c),
      currentCrisis: s.currentCrisis?.id === crisisId
        ? { ...s.currentCrisis, status: 'false_alarm' as const, false_alarm_by: userId }
        : s.currentCrisis,
    }))
  },

  // ── Helper Actions ────────────────────────────────────────────────

  offerHelp: async (crisisId, userId, message, skills) => {
    const supabase = createClient()
    const { data, error } = await supabase
      .from('crisis_helpers')
      .insert({ crisis_id: crisisId, user_id: userId, message, skills: skills || [] })
      .select('*, profiles(name, display_name, avatar_url, trust_score, is_crisis_volunteer, crisis_skills)')
      .single()
    if (error) {
      if (error.code === '23505') throw new Error('Du hilfst bereits bei dieser Krise.')
      throw new Error(error.message)
    }
    set(s => ({ helpers: [...s.helpers, data as CrisisHelper] }))
  },

  withdrawHelp: async (crisisId, userId) => {
    const supabase = createClient()
    const { error } = await supabase
      .from('crisis_helpers')
      .update({ status: 'withdrawn' })
      .eq('crisis_id', crisisId)
      .eq('user_id', userId)
    if (error) throw new Error(error.message)
    set(s => ({
      helpers: s.helpers.map(h =>
        h.crisis_id === crisisId && h.user_id === userId
          ? { ...h, status: 'withdrawn' as HelperStatus }
          : h
      ),
    }))
  },

  updateHelperStatus: async (helperId, status) => {
    const supabase = createClient()
    const { error } = await supabase
      .from('crisis_helpers')
      .update({ status })
      .eq('id', helperId)
    if (error) throw new Error(error.message)
    set(s => ({
      helpers: s.helpers.map(h => h.id === helperId ? { ...h, status } : h),
    }))
  },

  // ── Updates ───────────────────────────────────────────────────────

  addUpdate: async (crisisId, userId, content, updateType = 'info', imageUrl) => {
    const supabase = createClient()
    const { data, error } = await supabase
      .from('crisis_updates')
      .insert({
        crisis_id: crisisId,
        author_id: userId,
        content,
        update_type: updateType,
        image_url: imageUrl,
      })
      .select('*, profiles(name, avatar_url)')
      .single()
    if (error) throw new Error(error.message)
    set(s => ({ updates: [data as CrisisUpdate, ...s.updates] }))
  },

  // ── Image Upload ──────────────────────────────────────────────────

  uploadImage: async (file) => {
    const supabase = createClient()
    const ext = file.name.split('.').pop()
    const path = `${Date.now()}-${Math.random().toString(36).slice(2)}.${ext}`
    const { error } = await supabase.storage.from('crisis-images').upload(path, file)
    if (error) throw new Error(error.message)
    const { data: urlData } = supabase.storage.from('crisis-images').getPublicUrl(path)
    return urlData.publicUrl
  },

  // ── Filters ───────────────────────────────────────────────────────

  setFilters: (newFilters) => {
    set(s => ({ filters: { ...s.filters, ...newFilters }, page: 0 }))
  },

  resetFilters: () => {
    set({ filters: { ...defaultFilters }, page: 0 })
  },

  // ── Realtime Handlers ─────────────────────────────────────────────

  handleRealtimeCrisis: (payload) => {
    const { eventType, new: newRow, old: oldRow } = payload
    set(s => {
      if (eventType === 'INSERT') {
        return { crises: [newRow as Crisis, ...s.crises] }
      }
      if (eventType === 'UPDATE') {
        const updated = newRow as Crisis
        return {
          crises: s.crises.map(c => c.id === updated.id ? { ...c, ...updated } : c),
          currentCrisis: s.currentCrisis?.id === updated.id ? { ...s.currentCrisis, ...updated } : s.currentCrisis,
        }
      }
      if (eventType === 'DELETE') {
        return { crises: s.crises.filter(c => c.id !== oldRow?.id) }
      }
      return {}
    })
  },

  handleRealtimeHelper: (payload) => {
    const { eventType, new: newRow } = payload
    set(s => {
      if (eventType === 'INSERT') {
        return { helpers: [...s.helpers, newRow as CrisisHelper] }
      }
      if (eventType === 'UPDATE') {
        return { helpers: s.helpers.map(h => h.id === (newRow as CrisisHelper).id ? { ...h, ...newRow } : h) }
      }
      return {}
    })
  },

  handleRealtimeUpdate: (payload) => {
    const { eventType, new: newRow } = payload
    if (eventType === 'INSERT') {
      set(s => ({ updates: [newRow as CrisisUpdate, ...s.updates] }))
    }
  },
}))
