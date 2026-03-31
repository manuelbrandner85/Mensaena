import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import DashboardOverview from '@/components/dashboard/DashboardOverview'

export default async function DashboardPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) redirect('/login')

  // Fetch user profile
  const { data: profile } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', user.id)
    .single()

  // Fetch recent posts
  const { data: recentPosts } = await supabase
    .from('posts')
    .select('*, profiles(name, avatar_url)')
    .eq('status', 'active')
    .order('created_at', { ascending: false })
    .limit(6)

  // Fetch stats
  const { count: myPostsCount } = await supabase
    .from('posts')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', user.id)

  const { count: activePostsCount } = await supabase
    .from('posts')
    .select('*', { count: 'exact', head: true })
    .eq('status', 'active')

  const displayName = profile?.name || user.user_metadata?.full_name || user.email?.split('@')[0] || 'Nutzer'

  return (
    <DashboardOverview
      displayName={displayName}
      profile={profile}
      recentPosts={recentPosts || []}
      myPostsCount={myPostsCount || 0}
      activePostsCount={activePostsCount || 0}
    />
  )
}
