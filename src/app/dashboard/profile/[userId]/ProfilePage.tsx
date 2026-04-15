'use client'

import { useEffect, useState } from 'react'
import { useParams, useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { useStore } from '@/store/useStore'
import ProfileView from '@/components/profile/ProfileView'
import type { Profile, ProfilePost, ProfileStats } from '@/components/profile/ProfileView'
import { Shield } from 'lucide-react'
import Link from 'next/link'

export default function PublicProfilePage() {
  const params = useParams()
  const router = useRouter()
  const store = useStore()
  const paramUserId = params.userId as string

  const [profile, setProfile] = useState<Profile | null>(null)
  const [posts, setPosts] = useState<ProfilePost[]>([])
  const [stats, setStats] = useState<ProfileStats | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<'private' | 'blocked' | 'not_found' | null>(null)

  useEffect(() => {
    const signal = { cancelled: false }
    async function fetchData() {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (signal.cancelled) return
      const ownUserId = user?.id ?? null

      // Store userId if not cached
      if (ownUserId && !store.userId) {
        store.set({ userId: ownUserId })
      }

      // If viewing own profile, redirect
      if (ownUserId && paramUserId === ownUserId) {
        router.replace('/dashboard/profile')
        return
      }

      // Fetch target profile
      const { data: profileData, error: profileErr } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', paramUserId)
        .single()

      if (signal.cancelled) return
      if (profileErr || !profileData) {
        setError('not_found')
        setLoading(false)
        return
      }

      // Check privacy
      if (profileData.privacy_public === false) {
        setError('private')
        setLoading(false)
        return
      }

      // Check if blocked
      if (ownUserId) {
        const { data: blockData } = await supabase
          .from('user_blocks')
          .select('id')
          .eq('blocker_id', paramUserId)
          .eq('blocked_id', ownUserId)
          .maybeSingle()

        if (signal.cancelled) return
        if (blockData) {
          setError('blocked')
          setLoading(false)
          return
        }
      }

      setProfile(profileData as Profile)

      // Load public posts (active only, limit 10)
      const { data: postsData } = await supabase
        .from('posts')
        .select('id, title, type, status, urgency, created_at, reaction_count')
        .eq('user_id', paramUserId)
        .eq('status', 'active')
        .order('created_at', { ascending: false })
        .limit(10)

      if (signal.cancelled) return
      setPosts((postsData ?? []) as ProfilePost[])

      // Load stats via RPC (with fallback)
      let statsObj: ProfileStats
      const { data: rpcStats, error: rpcErr } = await supabase.rpc('get_profile_stats', {
        target_user_id: paramUserId,
      })

      if (signal.cancelled) return

      if (!rpcErr && rpcStats) {
        statsObj = rpcStats as ProfileStats
      } else {
        // Fallback
        const now = new Date()
        const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000).toISOString()

        const [helpGivenRes, messagesRes, recentPostsRes] = await Promise.all([
          supabase.from('interactions').select('id').eq('helper_id', paramUserId).eq('status', 'accepted'),
          supabase.from('messages').select('id', { count: 'exact' }).eq('sender_id', paramUserId).is('deleted_at', null),
          supabase.from('posts').select('created_at').eq('user_id', paramUserId).gte('created_at', thirtyDaysAgo),
        ])

        if (signal.cancelled) return

        const memberDays = profileData.created_at
          ? Math.floor((Date.now() - new Date(profileData.created_at).getTime()) / (24 * 60 * 60 * 1000))
          : 0

        const dayMap: Record<string, number> = {}
        for (let i = 29; i >= 0; i--) {
          const d = new Date(now.getTime() - i * 24 * 60 * 60 * 1000)
          dayMap[d.toISOString().slice(0, 10)] = 0
        }
        ;(recentPostsRes.data ?? []).forEach((p: { created_at: string }) => {
          const day = new Date(p.created_at).toISOString().slice(0, 10)
          if (dayMap[day] !== undefined) dayMap[day]++
        })

        statsObj = {
          total_posts: (postsData ?? []).length,
          help_given: helpGivenRes.data?.length ?? 0,
          messages_count: messagesRes.count ?? 0,
          member_days: memberDays,
          daily_activity: Object.entries(dayMap).map(([date, count]) => ({ date, count })),
        }
      }

      if (signal.cancelled) return
      setStats(statsObj)
      setLoading(false)
    }

    fetchData()
    return () => { signal.cancelled = true }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [paramUserId])

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="w-8 h-8 border-4 border-primary-400 border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }

  if (error === 'private') {
    return (
      <div className="max-w-md mx-auto text-center py-20">
        <Shield className="w-16 h-16 text-gray-300 mx-auto mb-4" />
        <h2 className="text-xl font-bold text-gray-900 mb-2">Dieses Profil ist privat</h2>
        <p className="text-gray-500 mb-6">
          Dieser Nutzer hat sein Profil auf privat gestellt und ist daher nicht einsehbar.
        </p>
        <Link href="/dashboard" className="text-primary-600 hover:text-primary-700 font-medium text-sm">
          Zurück zum Dashboard
        </Link>
      </div>
    )
  }

  if (error === 'blocked') {
    return (
      <div className="max-w-md mx-auto text-center py-20">
        <Shield className="w-16 h-16 text-gray-300 mx-auto mb-4" />
        <h2 className="text-xl font-bold text-gray-900 mb-2">Profil nicht verfügbar</h2>
        <p className="text-gray-500 mb-6">
          Dieses Profil ist derzeit nicht verfügbar.
        </p>
        <Link href="/dashboard" className="text-primary-600 hover:text-primary-700 font-medium text-sm">
          Zurück zum Dashboard
        </Link>
      </div>
    )
  }

  if (error === 'not_found' || !profile || !stats) {
    return (
      <div className="max-w-md mx-auto text-center py-20">
        <Shield className="w-16 h-16 text-gray-300 mx-auto mb-4" />
        <h2 className="text-xl font-bold text-gray-900 mb-2">Profil nicht gefunden</h2>
        <p className="text-gray-500 mb-6">
          Das gesuchte Profil konnte nicht gefunden werden.
        </p>
        <Link href="/dashboard" className="text-primary-600 hover:text-primary-700 font-medium text-sm">
          Zurück zum Dashboard
        </Link>
      </div>
    )
  }

  return (
    <ProfileView
      profile={profile}
      posts={posts}
      stats={stats}
      isOwnProfile={false}
      targetUserId={paramUserId}
    />
  )
}
