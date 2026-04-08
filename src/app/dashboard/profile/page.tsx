'use client'

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useStore } from '@/store/useStore'
import ProfileView from '@/components/profile/ProfileView'
import type { Profile, ProfilePost, ProfileStats } from '@/components/profile/ProfileView'

export default function ProfilePage() {
  const store = useStore()
  const [profile, setProfile] = useState<Profile | null>(null)
  const [posts, setPosts] = useState<ProfilePost[]>([])
  const [stats, setStats] = useState<ProfileStats | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function fetchData() {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return

      const userId = user.id

      // Use store cache for userId if available
      if (!store.userId) {
        store.set({ userId })
      }

      // Load profile
      const { data: profileData } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', userId)
        .single()

      if (profileData) {
        setProfile(profileData as Profile)
        // Sync store
        store.set({
          userName: profileData.name ?? null,
          userAvatar: profileData.avatar_url ?? null,
        })
      }

      // Load user's posts
      const { data: postsData } = await supabase
        .from('posts')
        .select('id, title, type, status, urgency, created_at, reaction_count')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })

      setPosts((postsData ?? []) as ProfilePost[])

      // Load profile stats via RPC (with fallback to manual computation)
      let statsObj: ProfileStats
      const { data: rpcStats, error: rpcErr } = await supabase.rpc('get_profile_stats', {
        target_user_id: userId,
      })

      if (!rpcErr && rpcStats) {
        statsObj = rpcStats as ProfileStats
      } else {
        // Fallback: compute stats manually
        const now = new Date()
        const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000).toISOString()

        const [helpGivenRes, messagesRes, recentPostsRes] = await Promise.all([
          supabase.from('interactions').select('id').eq('helper_id', userId).eq('status', 'accepted'),
          supabase.from('messages').select('id', { count: 'exact' }).eq('sender_id', userId).is('deleted_at', null),
          supabase.from('posts').select('created_at').eq('user_id', userId).gte('created_at', thirtyDaysAgo),
        ])

        const memberDays = profileData?.created_at
          ? Math.floor((Date.now() - new Date(profileData.created_at).getTime()) / (24 * 60 * 60 * 1000))
          : 0

        // Build 30-day activity
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

      setStats(statsObj)
      setLoading(false)
    }

    fetchData()
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  if (loading || !profile || !stats) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="w-8 h-8 border-4 border-primary-400 border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }

  return (
    <ProfileView
      profile={profile}
      user={{ id: store.userId!, email: profile.email }}
      posts={posts}
      stats={stats}
      isOwnProfile={true}
    />
  )
}
