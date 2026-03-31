'use client'

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import DashboardOverview from '@/components/dashboard/DashboardOverview'
import type { User } from '@supabase/supabase-js'

export default function DashboardPage() {
  const [user, setUser] = useState<User | null>(null)
  const [profile, setProfile] = useState<Record<string, unknown> | null>(null)
  const [recentPosts, setRecentPosts] = useState<Record<string, unknown>[]>([])
  const [myPostsCount, setMyPostsCount] = useState(0)
  const [activePostsCount, setActivePostsCount] = useState(0)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const supabase = createClient()

    async function fetchData() {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return

      setUser(user)

      const [profileRes, postsRes, myCountRes, activeCountRes] = await Promise.all([
        supabase.from('profiles').select('*').eq('id', user.id).single(),
        supabase.from('posts').select('*, profiles(name, avatar_url)').eq('status', 'active').order('created_at', { ascending: false }).limit(6),
        supabase.from('posts').select('*', { count: 'exact', head: true }).eq('user_id', user.id),
        supabase.from('posts').select('*', { count: 'exact', head: true }).eq('status', 'active'),
      ])

      setProfile(profileRes.data)
      setRecentPosts(postsRes.data || [])
      setMyPostsCount(myCountRes.count || 0)
      setActivePostsCount(activeCountRes.count || 0)
      setLoading(false)
    }

    fetchData()
  }, [])

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="w-8 h-8 border-4 border-primary-400 border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }

  const displayName = (profile as Record<string, unknown>)?.name as string
    || user?.user_metadata?.full_name
    || user?.email?.split('@')[0]
    || 'Nutzer'

  return (
    <DashboardOverview
      displayName={displayName}
      profile={profile as Record<string, unknown>}
      recentPosts={recentPosts as Record<string, unknown>[]}
      myPostsCount={myPostsCount}
      activePostsCount={activePostsCount}
    />
  )
}
