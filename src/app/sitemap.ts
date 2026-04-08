import type { MetadataRoute } from 'next'
import { createClient } from '@supabase/supabase-js'
import { SITE_URL } from '@/lib/seo'

/** Revalidate the sitemap once per hour */
export const revalidate = 3600

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  // ── Static pages ─────────────────────────────────────────────────

  const staticPages: MetadataRoute.Sitemap = [
    {
      url: SITE_URL,
      lastModified: new Date(),
      changeFrequency: 'weekly',
      priority: 1.0,
    },
    {
      url: `${SITE_URL}/dashboard/map`,
      lastModified: new Date(),
      changeFrequency: 'daily',
      priority: 0.8,
    },
    {
      url: `${SITE_URL}/about`,
      lastModified: new Date(),
      changeFrequency: 'monthly',
      priority: 0.5,
    },
    {
      url: `${SITE_URL}/kontakt`,
      lastModified: new Date(),
      changeFrequency: 'monthly',
      priority: 0.4,
    },
    {
      url: `${SITE_URL}/nutzungsbedingungen`,
      lastModified: new Date(),
      changeFrequency: 'monthly',
      priority: 0.3,
    },
    {
      url: `${SITE_URL}/datenschutz`,
      lastModified: new Date(),
      changeFrequency: 'monthly',
      priority: 0.3,
    },
    {
      url: `${SITE_URL}/impressum`,
      lastModified: new Date(),
      changeFrequency: 'monthly',
      priority: 0.3,
    },
  ]

  // ── Dynamic pages from Supabase ──────────────────────────────────

  let postPages: MetadataRoute.Sitemap = []
  let profilePages: MetadataRoute.Sitemap = []

  try {
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
    const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

    if (supabaseUrl && supabaseKey) {
      const supabase = createClient(supabaseUrl, supabaseKey)

      // Active posts
      const { data: posts } = await supabase
        .from('posts')
        .select('id, updated_at')
        .eq('status', 'active')
        .order('created_at', { ascending: false })
        .limit(5000)

      if (posts) {
        postPages = posts.map((p) => ({
          url: `${SITE_URL}/dashboard/posts/${p.id}`,
          lastModified: p.updated_at ? new Date(p.updated_at) : new Date(),
          changeFrequency: 'daily' as const,
          priority: 0.7,
        }))
      }

      // Public profiles
      const { data: profiles } = await supabase
        .from('profiles')
        .select('id, updated_at')
        .order('created_at', { ascending: false })
        .limit(5000)

      if (profiles) {
        profilePages = profiles.map((p) => ({
          url: `${SITE_URL}/dashboard/profile/${p.id}`,
          lastModified: p.updated_at ? new Date(p.updated_at) : new Date(),
          changeFrequency: 'weekly' as const,
          priority: 0.5,
        }))
      }
    }
  } catch (err) {
    // Silently continue – sitemap works without dynamic pages
    console.warn('[sitemap] Failed to fetch dynamic pages:', err)
  }

  return [...staticPages, ...postPages, ...profilePages]
}
