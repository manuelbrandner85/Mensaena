'use client'

import { useState, useEffect, useCallback, useRef } from 'react'
import { createClient } from '@/lib/supabase/client'
import type {
  DashboardData, DashboardProfile, NearbyPost, ActivityItem,
  UserStats, UnreadMessage, CommunityPulse, OnboardingProgress,
  TrustScore,
} from '../types'

const BOT_ID = '00000000-0000-0000-0000-000000000001'
const CACHE_TTL = 30_000
const PROFILE_CACHE_KEY = 'mensaena_dash_profile'
const PROFILE_CACHE_TTL = 5 * 60 * 1000 // 5 min

function readProfileCache(userId: string): DashboardProfile | null {
  try {
    const raw = localStorage.getItem(PROFILE_CACHE_KEY)
    if (!raw) return null
    const { uid, data, ts } = JSON.parse(raw) as { uid: string; data: DashboardProfile; ts: number }
    if (uid !== userId || Date.now() - ts > PROFILE_CACHE_TTL) return null
    return data
  } catch { return null }
}

function writeProfileCache(userId: string, profile: DashboardProfile) {
  try {
    localStorage.setItem(PROFILE_CACHE_KEY, JSON.stringify({ uid: userId, data: profile, ts: Date.now() }))
  } catch {}
}

const FALLBACK_TIPS = [
  'Hast du heute schon die Karte gecheckt? Vielleicht braucht jemand in deiner Nähe Hilfe!',
  'Ein Lächeln kostet nichts – schreib deinem Nachbarn eine nette Nachricht.',
  'Teile deine Fähigkeiten! Im Skill-Netzwerk kannst du anderen helfen und Neues lernen.',
  'Kleine Gesten, große Wirkung: Biete Einkaufshilfe in deiner Nachbarschaft an.',
  'Kennst du die Zeitbank? Tausche Zeit statt Geld mit deinen Nachbarn!',
]

// Module-level cache shared across re-renders and StrictMode double-mounts
let cachedDashboard: { data: DashboardData; timestamp: number } | null = null

export function useDashboard(userId: string | undefined) {
  const [dashboardData, setDashboardData] = useState<DashboardData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const loadingRef = useRef(false)
  const channelsRef = useRef<ReturnType<ReturnType<typeof createClient>['channel']>[]>([])

  // ─────────────────────────────────────────────────────────────
  // Core data loader
  // ─────────────────────────────────────────────────────────────
  const loadData = useCallback(async (background = false) => {
    if (!userId || loadingRef.current) return
    loadingRef.current = true
    if (!background) setError(null)

    const supabase = createClient()

    try {
      // ── 1. Profile — use localStorage cache to skip sequential DB round-trip ──
      const cachedProfile = typeof window !== 'undefined' ? readProfileCache(userId) : null
      let profile: DashboardProfile | null = cachedProfile
      const lat = cachedProfile?.latitude
      const lng = cachedProfile?.longitude
      const radiusKm = cachedProfile?.radius_km ?? 10

      // ── 2. All queries in parallel (profile refresh + data) ──
      const profileFetch = supabase
        .from('profiles')
        .select('id, name, nickname, email, bio, avatar_url, latitude, longitude, radius_km, trust_score, impact_score, created_at, role')
        .eq('id', userId)
        .single()

      const [
        nearbyRes,
        ownPostsRes,
        ratingsRes,
        statsRes,
        unreadRes,
        pulseRes,
        botTipRes,
        onboardingRes,
        profileRes,
      ] = await Promise.allSettled([
        // [0] Nearby posts — use cached lat/lng if available
        lat && lng
          ? supabase.rpc('get_nearby_posts', { p_lat: lat, p_lng: lng, p_radius_km: radiusKm, p_limit: 10 } as never)
          : supabase.from('posts').select('id, title, description, type, category, status, urgency, latitude, longitude, location_text, created_at, user_id, profiles!inner(name, avatar_url)')
              .eq('status', 'active').order('created_at', { ascending: false }).limit(10),

        // [1] Own recent posts (activity feed)
        supabase.from('posts')
          .select('id, title, type, created_at, user_id')
          .eq('user_id', userId)
          .order('created_at', { ascending: false })
          .limit(5),

        // [2] Trust ratings received – used for activity, avg AND trend (loaded once)
        supabase.from('trust_ratings')
          .select('id, rating, comment, created_at, rater_id, profiles!trust_ratings_rater_id_fkey(name, avatar_url)')
          .eq('rated_id', userId)
          .order('created_at', { ascending: false })
          .limit(20),

        // [3] Platform stats via RPC
        supabase.rpc('get_user_stats', { p_user_id: userId } as never),

        // [4] Unread messages via view
        supabase.from('v_unread_counts')
          .select('*')
          .eq('user_id', userId)
          .gt('unread_count', 0)
          .order('last_message_at', { ascending: false })
          .limit(5),

        // [5] Community pulse
        supabase.rpc('get_community_pulse'),

        // [6] Bot tip
        supabase.from('bot_scheduled_messages')
          .select('content')
          .eq('status', 'pending')
          .eq('message_type', 'daily_tip')
          .order('created_at', { ascending: false })
          .limit(1),

        // [7] Onboarding checks (sent messages + given ratings)
        Promise.all([
          supabase.from('messages').select('id', { count: 'exact', head: true }).eq('sender_id', userId),
          supabase.from('trust_ratings').select('id', { count: 'exact', head: true }).eq('rater_id', userId),
        ]),

        // [8] Profile refresh (runs in parallel with all above)
        profileFetch,
      ])

      const get = <T>(r: PromiseSettledResult<{ data: T | null }>): T | null =>
        r.status === 'fulfilled' ? r.value.data : null

      // ── Update profile from fresh fetch, persist to localStorage cache ──
      const freshProfile = get(profileRes) as DashboardProfile | null
      if (freshProfile) {
        profile = freshProfile
        if (typeof window !== 'undefined') writeProfileCache(userId, freshProfile)
      }

      // ── Nearby Posts ──
      let nearbyPosts: NearbyPost[] = []
      const nearbyRaw = get(nearbyRes)
      if (nearbyRaw) {
        nearbyPosts = (Array.isArray(nearbyRaw) ? nearbyRaw : []).map((p: Record<string, unknown>) => ({
          id: p.id as string,
          title: p.title as string,
          description: (p.description ?? null) as string | null,
          type: p.type as string,
          category: (p.category ?? null) as string | null,
          status: p.status as string,
          urgency: (p.urgency ?? null) as string | null,
          latitude: (p.latitude ?? null) as number | null,
          longitude: (p.longitude ?? null) as number | null,
          location_text: (p.location_text ?? null) as string | null,
          created_at: p.created_at as string,
          user_id: p.user_id as string,
          author_name: (p.author_name ?? (p.profiles as Record<string, unknown> | null)?.name ?? null) as string | null,
          author_avatar: (p.author_avatar ?? (p.profiles as Record<string, unknown> | null)?.avatar_url ?? null) as string | null,
          distance_km: (p.distance_km ?? null) as number | null,
        }))
      }

      // ── Activity Feed ──
      const activities: ActivityItem[] = []

      const ownPosts = get(ownPostsRes)
      if (ownPosts) {
        for (const p of ownPosts as Record<string, unknown>[]) {
          activities.push({
            id: `post-${p.id}`,
            type: p.type === 'crisis' ? 'crisis_alert' : 'new_post',
            title: (p.title as string) || 'Neuer Beitrag',
            description: 'Neuer Beitrag in der Nachbarschaft',
            timestamp: p.created_at as string,
            iconName: p.type === 'crisis' ? 'AlertTriangle' : 'FileText',
            color: p.type === 'crisis' ? 'red' : 'blue',
            linkTo: `/dashboard/posts/${p.id}`,
            actorName: null,
            actorAvatarUrl: null,
          })
        }
      }

      const ratingsRaw = get(ratingsRes)
      if (ratingsRaw) {
        for (const r of ratingsRaw as Record<string, unknown>[]) {
          const rp = r.profiles as Record<string, unknown> | null
          activities.push({
            id: `rating-${r.id}`,
            type: 'trust_rating',
            title: `Neue Bewertung: ${r.rating}/5 ⭐`,
            description: (r.comment as string) || 'Du hast eine Bewertung erhalten',
            timestamp: r.created_at as string,
            iconName: 'Star',
            color: 'amber',
            linkTo: '/dashboard/profile',
            actorName: (rp?.name ?? null) as string | null,
            actorAvatarUrl: (rp?.avatar_url ?? null) as string | null,
          })
        }
      }

      activities.sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime())
      const recentActivity = activities.slice(0, 15)

      // ── Stats (from RPC + derived) ──
      const statsRaw = get(statsRes) as Record<string, unknown> | null
      const memberSinceDays = profile?.created_at
        ? Math.floor((Date.now() - new Date(profile.created_at).getTime()) / 86_400_000)
        : 0

      const stats: UserStats = {
        postsCreated:           Number(statsRaw?.posts_created            ?? 0),
        interactionsCompleted:  Number(statsRaw?.interactions_completed   ?? 0),
        peopleHelped:           Number(statsRaw?.people_helped            ?? 0),
        trustRatingAvg:         0, // calculated from ratings below
        memberSinceDays,
        savedPostsCount:        Number(statsRaw?.saved_posts_count        ?? 0),
      }

      // ── Trust Score (derived from single ratings query) ──
      let trustScore: TrustScore = { average: 0, totalRatings: 0, trend: 'stable' }
      if (ratingsRaw && (ratingsRaw as unknown[]).length > 0) {
        const allR = ratingsRaw as Record<string, unknown>[]
        const avg = allR.reduce((s, r) => s + Number(r.rating || 0), 0) / allR.length
        const now = Date.now()
        const last30 = allR.filter(r => now - new Date(r.created_at as string).getTime() < 30 * 86_400_000)
        const prev30 = allR.filter(r => {
          const d = now - new Date(r.created_at as string).getTime()
          return d >= 30 * 86_400_000 && d < 60 * 86_400_000
        })
        const avgLast = last30.length > 0 ? last30.reduce((s, r) => s + Number(r.rating), 0) / last30.length : avg
        const avgPrev = prev30.length > 0 ? prev30.reduce((s, r) => s + Number(r.rating), 0) / prev30.length : avg
        const trend: TrustScore['trend'] = avgLast > avgPrev + 0.1 ? 'up' : avgLast < avgPrev - 0.1 ? 'down' : 'stable'
        trustScore = { average: Math.round(avg * 10) / 10, totalRatings: allR.length, trend }
        stats.trustRatingAvg = trustScore.average
      }

      // ── Unread Messages ──
      const unreadMessages: UnreadMessage[] = []
      const unreadRaw = get(unreadRes)
      if (unreadRaw) {
        for (const row of unreadRaw as Record<string, unknown>[]) {
          if ((row.unread_count as number) === 0) continue
          unreadMessages.push({
            conversationId: row.conversation_id as string,
            senderName: (row.sender_name ?? 'Nachricht') as string,
            senderAvatarUrl: (row.sender_avatar ?? null) as string | null,
            lastMessageText: ((row.last_message_text as string) ?? '').slice(0, 80),
            timestamp: (row.last_message_at ?? '') as string,
            unreadCount: row.unread_count as number,
          })
        }
      }

      // ── Community Pulse ──
      const pulseRaw = get(pulseRes) as Record<string, unknown> | null
      const communityPulse: CommunityPulse = {
        activeUsersToday:        Number(pulseRaw?.active_users_today      ?? 0),
        newPostsToday:           Number(pulseRaw?.new_posts_today         ?? 0),
        interactionsThisWeek:    Number(pulseRaw?.interactions_this_week  ?? 0),
        newestNeighborName:      (pulseRaw?.newest_neighbor_name      ?? null) as string | null,
        newestNeighborJoinedAt:  (pulseRaw?.newest_neighbor_joined_at ?? null) as string | null,
      }

      // ── Bot Tip ──
      const botTipRaw = get(botTipRes)
      const botTip: string =
        ((botTipRaw as Record<string, unknown>[] | null)?.[0]?.content as string | undefined) ??
        FALLBACK_TIPS[Math.floor(Math.random() * FALLBACK_TIPS.length)]

      // ── Onboarding ──
      let sentMsgCount = 0
      let givenRatingCount = 0
      if (onboardingRes.status === 'fulfilled') {
        const [sentRes, givenRes] = onboardingRes.value
        sentMsgCount      = (sentRes as { count: number | null }).count ?? 0
        givenRatingCount  = (givenRes as { count: number | null }).count ?? 0
      }

      const steps = [
        { id: 'avatar',         label: 'Profilbild hochladen',   done: !!profile?.avatar_url,                       actionPath: '/dashboard/settings' },
        { id: 'bio',            label: 'Bio schreiben',          done: !!profile?.bio && profile.bio.trim().length > 0, actionPath: '/dashboard/settings' },
        { id: 'location',       label: 'Standort einstellen',    done: !!profile?.latitude,                         actionPath: '/dashboard/settings' },
        { id: 'first_post',     label: 'Ersten Beitrag erstellen', done: stats.postsCreated > 0,                    actionPath: '/dashboard/create' },
        { id: 'first_message',  label: 'Erste Nachricht senden', done: sentMsgCount > 0,                            actionPath: '/dashboard/chat' },
        { id: 'first_rating',   label: 'Jemanden bewerten',      done: givenRatingCount > 0,                        actionPath: '/dashboard/map' },
      ]
      const doneCount = steps.filter(s => s.done).length
      const onboardingProgress: OnboardingProgress = {
        completed:       doneCount === steps.length,
        steps,
        percentComplete: Math.round((doneCount / steps.length) * 100),
      }

      const newData: DashboardData = {
        profile,
        nearbyPosts,
        recentActivity,
        stats,
        unreadMessages,
        communityPulse,
        onboardingProgress,
        botTip,
        trustScore,
      }

      cachedDashboard = { data: newData, timestamp: Date.now() }
      setDashboardData(newData)
    } catch (err) {
      console.error('Dashboard load error:', err)
      if (!background) setError('Dashboard konnte nicht geladen werden. Bitte versuche es erneut.')
    } finally {
      setLoading(false)
      loadingRef.current = false
    }
  }, [userId])

  // ─────────────────────────────────────────────────────────────
  // Initial load with stale-while-revalidate cache
  // ─────────────────────────────────────────────────────────────
  useEffect(() => {
    if (!userId) return

    if (cachedDashboard && Date.now() - cachedDashboard.timestamp < CACHE_TTL) {
      setDashboardData(cachedDashboard.data)
      setLoading(false)
      loadData(true) // silent background refresh
    } else {
      loadData(false)
    }
  }, [userId, loadData])

  // ─────────────────────────────────────────────────────────────
  // Realtime subscriptions (optimistic – no full reload)
  // ─────────────────────────────────────────────────────────────
  useEffect(() => {
    if (!userId) return
    const supabase = createClient()

    // New posts → prepend optimistically
    const postChannel = supabase
      .channel(`dashboard-posts:${userId}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'posts' }, (payload) => {
        const p = payload.new as Record<string, unknown>
        if (p.status !== 'active') return
        setDashboardData(prev => {
          if (!prev) return prev
          const newPost: NearbyPost = {
            id:            p.id as string,
            title:         p.title as string,
            description:   (p.description ?? null) as string | null,
            type:          p.type as string,
            category:      (p.category ?? null) as string | null,
            status:        p.status as string,
            urgency:       (p.urgency ?? null) as string | null,
            latitude:      (p.latitude ?? null) as number | null,
            longitude:     (p.longitude ?? null) as number | null,
            location_text: (p.location_text ?? null) as string | null,
            created_at:    p.created_at as string,
            user_id:       p.user_id as string,
            author_name:   null,
            author_avatar: null,
            distance_km:   null,
          }
          const updated: DashboardData = {
            ...prev,
            nearbyPosts: [newPost, ...prev.nearbyPosts].slice(0, 10),
            communityPulse: { ...prev.communityPulse, newPostsToday: prev.communityPulse.newPostsToday + 1 },
          }
          cachedDashboard = { data: updated, timestamp: cachedDashboard?.timestamp ?? Date.now() }
          return updated
        })
      })
      .subscribe()

    // New messages → increment unread counter optimistically
    const msgChannel = supabase
      .channel(`dashboard-messages:${userId}`)
      .on('postgres_changes', {
        event: 'INSERT', schema: 'public', table: 'messages',
        filter: `sender_id=neq.${userId}`,
      }, (payload) => {
        const m = payload.new as Record<string, unknown>
        if (m.sender_id === BOT_ID) return
        setDashboardData(prev => {
          if (!prev) return prev
          const convId = m.conversation_id as string
          const existing = prev.unreadMessages.find(u => u.conversationId === convId)
          const updatedMessages: UnreadMessage[] = existing
            ? prev.unreadMessages.map(u =>
                u.conversationId === convId
                  ? { ...u, unreadCount: u.unreadCount + 1, lastMessageText: ((m.content as string) ?? '').slice(0, 80), timestamp: m.created_at as string }
                  : u
              )
            : [
                {
                  conversationId: convId,
                  senderName: 'Neue Nachricht',
                  senderAvatarUrl: null,
                  lastMessageText: ((m.content as string) ?? '').slice(0, 80),
                  timestamp: m.created_at as string,
                  unreadCount: 1,
                },
                ...prev.unreadMessages,
              ].slice(0, 5)

          const updated: DashboardData = { ...prev, unreadMessages: updatedMessages }
          cachedDashboard = { data: updated, timestamp: cachedDashboard?.timestamp ?? Date.now() }
          return updated
        })
      })
      .subscribe()

    channelsRef.current = [postChannel, msgChannel]

    return () => {
      for (const ch of channelsRef.current) supabase.removeChannel(ch)
      channelsRef.current = []
    }
  }, [userId])

  const refresh = useCallback(() => loadData(false), [loadData])

  return { dashboardData, loading, error, refresh }
}

export default useDashboard
