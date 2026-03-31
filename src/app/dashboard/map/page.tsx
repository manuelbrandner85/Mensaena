import { createClient } from '@/lib/supabase/server'
import MapView from '@/components/map/MapView'

export default async function MapPage() {
  const supabase = createClient()

  const { data: posts } = await supabase
    .from('posts')
    .select('*')
    .eq('status', 'active')
    .not('latitude', 'is', null)
    .not('longitude', 'is', null)
    .order('created_at', { ascending: false })
    .limit(200)

  return <MapView posts={posts || []} />
}
