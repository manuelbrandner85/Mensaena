import { createClient } from '@/lib/supabase/server'
import ProfileView from '@/components/dashboard/ProfileView'

export default async function ProfilePage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()

  const { data: profile } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', user!.id)
    .single()

  const { data: myPosts } = await supabase
    .from('posts')
    .select('*')
    .eq('user_id', user!.id)
    .order('created_at', { ascending: false })
    .limit(10)

  return <ProfileView profile={profile} user={user!} myPosts={myPosts || []} />
}
