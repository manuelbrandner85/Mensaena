'use client'

import { useState, useEffect, useCallback, useRef } from 'react'
import { createClient } from '@/lib/supabase/client'
import type {
  DashboardData, DashboardProfile, NearbyPost, ActivityItem,
  UserStats, UnreadMessage, CommunityPulse, OnboardingProgress,
  TrustScore,
} from '../types'

const BOT_ID = '00000000-0000-0000-0000-000000000001'

const FALLBACK_TIPS = [
  'Hast du heute schon die Karte gecheckt? Vielleicht braucht jemand in deiner Nähe Hilfe!',
  'Ein Lächeln kostet nichts – schreib deinem Nachbarn eine nette Nachricht.',
  'Teile deine Fähigkeiten! Im Skill-Netzwerk kannst du anderen helfen und Neues lernen.',
  'Kleine Gesten, große Wirkung: Biete Einkaufshilfe in deiner Nachbarschaft an.',
  'Kennst du die Zeitbank? Tausche Zeit statt Geld mit deinen Nachbarn!',
]

export function useDashboard(userId: string | undefined) {
  const [dashboardData, setDashboardData] = useState<DashboardData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const channelsRef = useRef<ReturnType<ReturnType<typeof createClient>['channel']>[]>([])

  const loadDashboard = useCallback(async () => {
    if (!userId) return
    setError(null)

    const supabase = createClient()

    try {
      // ── 1. Profile ──
      const { data: profileData } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', userId)
        .single()

      const profile = (profileData as unknown as DashboardProfile) ?? null
      const lat = profile?.latitude
      const lng = profile?.longitude
      const radiusKm = profile?.radius_km ?? 10

      // ── Parallel queries via Promise.allSettled ──
      const results = await Promise.allSettled([
        // [0] Nearby Posts
        lat && lng
          ? supabase.rpc('get_nearby_posts', { p_lat: lat, p_lng: lng, p_radius_km: radiusKm, p_limit: 10 } as any)
          : supabase.from('posts').select('*, profiles(name, avatar_url)')
              .eq('status', 'active').order('created_at', { ascending: false }).limit(10),

        // [1] Recent posts (7 days)
        supabase.from('posts').select('id, title, type, created_at, user_id, profiles(name, avatar_url)')
          .eq('status', 'active')
          .gte('created_at', new Date(Date.now() - 7 * 86400000).toISOString())
          .order('created_at', { ascending: false }).limit(10),

        // [2] User interactions (14 days)
        supabase.from('interactions').select('id, status, created_at, post_id, helper_id, posts(title)')
          .or(`helper_id.eq.${userId}`)
          .eq('status', 'completed')
          .gte('created_at', new Date(Date.now() - 14 * 86400000).toISOString())
          .order('created_at', { ascending: false }).limit(10),

        // [3] Trust ratings for user (14 days)
        supabase.from('trust_ratings').select('id, rating, comment, created_at, rater_id, profiles!trust_ratings_rater_id_fkey(name, avatar_url)')
          .eq('rated_id', userId)
          .gte('created_at', new Date(Date.now() - 14 * 86400000).toISOString())
          .order('created_at', { ascending: false }).limit(5),

        // [4] Posts count
        supabase.from('posts').select('*', { count: 'exact', head: true }).eq('user_id', userId),

        // [5] Interactions completed count
        supabase.from('interactions').select('*', { count: 'exact', head: true })
          .or(`helper_id.eq.${userId}`)
          .eq('status', 'completed'),

        // [6] People helped (unique)
        supabase.from('interactions').select('post_id')
          .eq('helper_id', userId).eq('status', 'completed'),

        // [7] Trust rating average
        supabase.from('trust_ratings').select('rating').eq('rated_id', userId),

        // [8] Saved posts count
        supabase.from('saved_posts').select('*', { count: 'exact', head: true }).eq('user_id', userId),

        // [9] Unread messages
        supabase.from('conversation_members')
          .select(`conversation_id, last_read_at, conversations(id, type, title, messages(id, content, created_at, sender_id), conversation_members(user_id, profiles(name, avatar_url)))`)
          .eq('user_id', userId),

        // [10] Community pulse
        supabase.rpc('get_community_pulse'),

        // [11] Bot tip
        supabase.from('bot_scheduled_messages')
          .select('message_content')
          .eq('user_id', userId)
          .eq('sent', false)
          .eq('message_type', 'daily_tip')
          .order('created_at', { ascending: false })
          .limit(1),

        // [12] Trust score with trend
        supabase.from('trust_ratings').select('rating, created_at').eq('rated_id', userId),

        // [13] User sent messages (for onboarding)
        supabase.from('messages').select('id', { count: 'exact', head: true }).eq('sender_id', userId),

        // [14] User given ratings (for onboarding)
        supabase.from('trust_ratings').select('id', { count: 'exact', head: true }).eq('rater_id', userId),
      ])

      // ── Helper to safely extract data ──
      const getData = (idx: number): any => {
        const r = results[idx]
        if (r.status === 'fulfilled') return r.value.data
        return null
      }
      const getCount = (idx: number): number => {
        const r = results[idx]
        if (r.status === 'fulfilled') return (r.value as any).count ?? 0
        return 0
      }

      // ── 2. Nearby Posts ──
      let nearbyPosts: NearbyPost[] = []
      const nearbyRaw = getData(0)
      if (nearbyRaw) {
        if (lat && lng) {
          // RPC result is array of json
          nearbyPosts = (Array.isArray(nearbyRaw) ? nearbyRaw : []).map((p: any) => ({
            id: p.id,
            title: p.title,
            description: p.description,
            type: p.type,
            category: p.category,
            status: p.status,
            urgency: p.urgency,
            latitude: p.latitude,
            longitude: p.longitude,
            location_text: p.location_text,
            created_at: p.created_at,
            user_id: p.user_id,
            author_name: p.author_name ?? p.profiles?.name ?? null,
            author_avatar: p.author_avatar ?? p.profiles?.avatar_url ?? null,
            distance_km: p.distance_km ?? null,
          }))
        } else {
          nearbyPosts = (nearbyRaw as any[]).map((p: any) => ({
            id: p.id,
            title: p.title,
            description: p.description,
            type: p.type,
            category: p.category,
            status: p.status,
            urgency: p.urgency,
            latitude: p.latitude,
            longitude: p.longitude,
            location_text: p.location_text,
            created_at: p.created_at,
            user_id: p.user_id,
            author_name: p.profiles?.name ?? null,
            author_avatar: p.profiles?.avatar_url ?? null,
            distance_km: null,
          }))
        }
      }

      // ── 3. Activity Feed ──
      const activities: ActivityItem[] = []

      // New posts
      const recentPosts = getData(1)
      if (recentPosts) {
        for (const p of recentPosts as any[]) {
          activities.push({
            id: `post-${p.id}`,
            type: p.type === 'crisis' ? 'crisis_alert' : 'new_post',
            title: p.title || 'Neuer Beitrag',
            description: `Neuer Beitrag in der Nachbarschaft`,
            timestamp: p.created_at,
            iconName: p.type === 'crisis' ? 'AlertTriangle' : 'FileText',
            color: p.type === 'crisis' ? 'red' : 'blue',
            linkTo: `/dashboard/posts/${p.id}`,
            actorName: p.profiles?.name ?? null,
            actorAvatarUrl: p.profiles?.avatar_url ?? null,
          })
        }
      }

      // Completed interactions
      const interactions = getData(2)
      if (interactions) {
        for (const i of interactions as any[]) {
          activities.push({
            id: `interaction-${i.id}`,
            type: 'interaction_completed',
            title: 'Hilfe abgeschlossen',
            description: i.posts?.title ? `Bei "${i.posts.title}"` : 'Interaktion abgeschlossen',
            timestamp: i.created_at,
            iconName: 'Handshake',
            color: 'teal',
            linkTo: i.post_id ? `/dashboard/posts/${i.post_id}` : '/dashboard/posts',
            actorName: null,
            actorAvatarUrl: null,
          })
        }
      }

      // Trust ratings
      const ratings = getData(3)
      if (ratings) {
        for (const r of ratings as any[]) {
          const raterProfile = r.profiles
          activities.push({
            id: `rating-${r.id}`,
            type: 'trust_rating',
            title: `Neue Bewertung: ${r.rating}/5 ⭐`,
            description: r.comment || 'Du hast eine Bewertung erhalten',
            timestamp: r.created_at,
            iconName: 'Star',
            color: 'amber',
            linkTo: '/dashboard/profile',
            actorName: raterProfile?.name ?? null,
            actorAvatarUrl: raterProfile?.avatar_url ?? null,
          })
        }
      }

      // Sort and limit
      activities.sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime())
      const recentActivity = activities.slice(0, 15)

      // ── 4. Stats ──
      const postsCreated = getCount(4)
      const interactionsCompleted = getCount(5)
      const uniqueHelped = getData(6)
      const peopleHelped = uniqueHelped ? new Set((uniqueHelped as any[]).map((i: any) => i.post_id)).size : 0
      const trustRatings = getData(7)
      const trustRatingAvg = trustRatings && (trustRatings as any[]).length > 0
        ? (trustRatings as any[]).reduce((sum: number, r: any) => sum + (r.rating || 0), 0) / (trustRatings as any[]).length
        : 0
      const savedPostsCount = getCount(8)
      const memberSinceDays = profile?.created_at
        ? Math.floor((Date.now() - new Date(profile.created_at).getTime()) / 86400000)
        : 0

      const stats: UserStats = {
        postsCreated,
        interactionsCompleted,
        peopleHelped,
        trustRatingAvg: Math.round(trustRatingAvg * 10) / 10,
        memberSinceDays,
        savedPostsCount,
      }

      // ── 5. Unread Messages ──
      const convData = getData(9)
      const unreadMessages: UnreadMessage[] = []
      if (convData) {
        for (const row of convData as any[]) {
          const c = row.conversations
          if (!c || c.type === 'system') continue
          const msgs: any[] = (c.messages ?? []).sort(
            (a: any, b: any) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
          )
          const lastRead = row.last_read_at ? new Date(row.last_read_at).getTime() : 0
          const unread = msgs.filter(
            (m: any) => m.sender_id !== userId && m.sender_id !== BOT_ID && new Date(m.created_at).getTime() > lastRead
          )
          if (unread.length === 0) continue

          const other = (c.conversation_members ?? []).find((m: any) => m.user_id !== userId)
          const senderProfile = other?.profiles
          const lastMsg = msgs[0]

          unreadMessages.push({
            conversationId: c.id,
            senderName: senderProfile?.name ?? c.title ?? 'Nachricht',
            senderAvatarUrl: senderProfile?.avatar_url ?? null,
            lastMessageText: lastMsg ? (lastMsg.content ?? '').slice(0, 80) : '',
            timestamp: lastMsg?.created_at ?? row.last_read_at ?? '',
            unreadCount: unread.length,
          })
        }
        unreadMessages.sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime())
        unreadMessages.splice(5) // Max 5
      }

      // ── 6. Community Pulse ──
      const pulseRaw = getData(10)
      const communityPulse: CommunityPulse = {
        activeUsersToday: pulseRaw?.active_users_today ?? 0,
        newPostsToday: pulseRaw?.new_posts_today ?? 0,
        interactionsThisWeek: pulseRaw?.interactions_this_week ?? 0,
        newestNeighborName: pulseRaw?.newest_neighbor_name ?? null,
        newestNeighborJoinedAt: pulseRaw?.newest_neighbor_joined_at ?? null,
      }

      // ── 7. Bot Tip ──
      const botTipRaw = getData(11)
      let botTip: string | null = null
      if (botTipRaw && (botTipRaw as any[]).length > 0) {
        botTip = (botTipRaw as any[])[0].message_content
      }
      if (!botTip) {
        botTip = FALLBACK_TIPS[Math.floor(Math.random() * FALLBACK_TIPS.length)]
      }

      // ── 8. Trust Score ──
      const allRatings = getData(12) as any[] | null
      let trustScore: TrustScore = { average: 0, totalRatings: 0, trend: 'stable' }
      if (allRatings && allRatings.length > 0) {
        const avg = allRatings.reduce((s, r) => s + (r.rating || 0), 0) / allRatings.length
        const now = Date.now()
        const last30 = allRatings.filter((r) => now - new Date(r.created_at).getTime() < 30 * 86400000)
        const prev30 = allRatings.filter(
          (r) => {
            const diff = now - new Date(r.created_at).getTime()
            return diff >= 30 * 86400000 && diff < 60 * 86400000
          }
        )
        const avgLast = last30.length > 0 ? last30.reduce((s: number, r: any) => s + r.rating, 0) / last30.length : avg
        const avgPrev = prev30.length > 0 ? prev30.reduce((s: number, r: any) => s + r.rating, 0) / prev30.length : avg
        const trend = avgLast > avgPrev + 0.1 ? 'up' : avgLast < avgPrev - 0.1 ? 'down' : 'stable'
        trustScore = { average: Math.round(avg * 10) / 10, totalRatings: allRatings.length, trend }
      }

      // ── 9. Onboarding ──
      const sentMsgCount = getCount(13)
      const givenRatingCount = getCount(14)
      const steps = [
        { id: 'avatar', label: 'Profilbild hochladen', done: !!profile?.avatar_url, actionPath: '/dashboard/settings' },
        { id: 'bio', label: 'Bio schreiben', done: !!profile?.bio && profile.bio.trim().length > 0, actionPath: '/dashboard/settings' },
        { id: 'location', label: 'Standort einstellen', done: !!profile?.latitude, actionPath: '/dashboard/settings' },
        { id: 'first_post', label: 'Ersten Beitrag erstellen', done: postsCreated > 0, actionPath: '/dashboard/create' },
        { id: 'first_message', label: 'Erste Nachricht senden', done: sentMsgCount > 0, actionPath: '/dashboard/chat' },
        { id: 'first_rating', label: 'Jemanden bewerten', done: givenRatingCount > 0, actionPath: '/dashboard/map' },
      ]
      const doneCount = steps.filter((s) => s.done).length
      const percentComplete = Math.round((doneCount / steps.length) * 100)
      const onboardingProgress: OnboardingProgress = {
        completed: percentComplete === 100,
        steps,
        percentComplete,
      }

      setDashboardData({
        profile,
        nearbyPosts,
        recentActivity,
        stats,
        unreadMessages,
        communityPulse,
        onboardingProgress,
        botTip,
        trustScore,
      })
    } catch (err) {
      console.error('Dashboard load error:', err)
      setError('Dashboard konnte nicht geladen werden. Bitte versuche es erneut.')
    } finally {
      setLoading(false)
    }
  }, [userId])

  // ── Realtime subscriptions ──
  useEffect(() => {
    if (!userId) return
    const supabase = createClient()

    const postChannel = supabase
      .channel(`dashboard-posts:${userId}`)
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'posts',
      }, (payload) => {
        const p = payload.new as any
        if (p.status !== 'active') return
        setDashboardData((prev) => {
          if (!prev) return prev
          const newPost: NearbyPost = {
            id: p.id,
            title: p.title,
            description: p.description,
            type: p.type,
            category: p.category,
            status: p.status,
            urgency: p.urgency,
            latitude: p.latitude,
            longitude: p.longitude,
            location_text: p.location_text,
            created_at: p.created_at,
            user_id: p.user_id,
            author_name: null,
            author_avatar: null,
            distance_km: null,
          }
          return {
            ...prev,
            nearbyPosts: [newPost, ...prev.nearbyPosts].slice(0, 10),
            communityPulse: {
              ...prev.communityPulse,
              newPostsToday: prev.communityPulse.newPostsToday + 1,
            },
          }
        })
      })
      .subscribe()

    const msgChannel = supabase
      .channel(`dashboard-messages:${userId}`)
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'messages',
        filter: `sender_id=neq.${userId}`,
      }, () => {
        // Simple approach: reload messages on new message
        loadDashboard()
      })
      .subscribe()

    channelsRef.current = [postChannel, msgChannel]

    return () => {
      for (const ch of channelsRef.current) {
        supabase.removeChannel(ch)
      }
    }
  }, [userId, loadDashboard])

  // ── Initial load ──
  useEffect(() => {
    loadDashboard()
  }, [loadDashboard])

  return { dashboardData, loading, error, refresh: loadDashboard }
}
