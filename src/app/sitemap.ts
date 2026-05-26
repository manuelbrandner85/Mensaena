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
      url: `${SITE_URL}/auth`,
      lastModified: new Date(),
      changeFrequency: 'monthly',
      priority: 0.7,
    },
    {
      url: `${SITE_URL}/dashboard/organizations`,
      lastModified: new Date(),
      changeFrequency: 'weekly',
      priority: 0.7,
    },
    {
      url: `${SITE_URL}/dashboard/events`,
      lastModified: new Date(),
      changeFrequency: 'daily',
      priority: 0.6,
    },
    {
      url: `${SITE_URL}/dashboard/wiki`,
      lastModified: new Date(),
      changeFrequency: 'weekly',
      priority: 0.6,
    },
    {
      url: `${SITE_URL}/spenden`,
      lastModified: new Date(),
      changeFrequency: 'monthly',
      priority: 0.6,
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
    {
      url: `${SITE_URL}/community-guidelines`,
      lastModified: new Date(),
      changeFrequency: 'monthly',
      priority: 0.3,
    },
    {
      url: `${SITE_URL}/agb`,
      lastModified: new Date(),
      changeFrequency: 'monthly',
      priority: 0.2,
    },
    {
      url: `${SITE_URL}/haftungsausschluss`,
      lastModified: new Date(),
      changeFrequency: 'monthly',
      priority: 0.2,
    },
  ]

  // ── Dynamic pages from Supabase ──────────────────────────────────
  //
  // Build-Resilience: jeder Fetch hat ein hartes 20s-Budget via
  // AbortController. Wenn Supabase langsam ist (Edge-Region-Timeout
  // wie zuletzt 504 in den CI-Logs), gibt's leeren Pages-Block statt
  // einen Build-Crash. Sitemap-Revalidate (1h) holt naechste Stunde
  // erneut, sobald die Latenz wieder normal ist.

  let postPages: MetadataRoute.Sitemap = []
  let profilePages: MetadataRoute.Sitemap = []

  const FETCH_BUDGET_MS = 20_000
  const LIMIT = 1000 // war 5000 — 1000 reicht fuer SEO-Discovery, 5x schneller

  const fetchWithTimeout = async <T>(
    label: string,
    fn: (signal: AbortSignal) => Promise<T>,
  ): Promise<T | null> => {
    const ctrl = new AbortController()
    const timer = setTimeout(() => ctrl.abort(), FETCH_BUDGET_MS)
    try {
      return await fn(ctrl.signal)
    } catch (err) {
      console.warn(`[sitemap] ${label} skipped:`, err)
      return null
    } finally {
      clearTimeout(timer)
    }
  }

  try {
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
    const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

    if (supabaseUrl && supabaseKey) {
      const supabase = createClient(supabaseUrl, supabaseKey)

      // Beide Queries parallel — spart Wartezeit. AbortSignal greift
      // wenn Supabase langsamer als FETCH_BUDGET_MS antwortet.
      const [postsRes, profilesRes] = await Promise.all([
        fetchWithTimeout('posts', (signal) =>
          supabase
            .from('posts')
            .select('id, updated_at')
            .eq('status', 'active')
            .order('created_at', { ascending: false })
            .limit(LIMIT)
            .abortSignal(signal),
        ),
        fetchWithTimeout('profiles', (signal) =>
          supabase
            .from('profiles')
            .select('id, updated_at')
            .order('created_at', { ascending: false })
            .limit(LIMIT)
            .abortSignal(signal),
        ),
      ])

      const posts = postsRes?.data
      if (Array.isArray(posts)) {
        postPages = posts.map((p) => ({
          url: `${SITE_URL}/dashboard/posts/${p.id}`,
          lastModified: p.updated_at ? new Date(p.updated_at) : new Date(),
          changeFrequency: 'daily' as const,
          priority: 0.7,
        }))
      }

      const profiles = profilesRes?.data
      if (Array.isArray(profiles)) {
        profilePages = profiles.map((p) => ({
          url: `${SITE_URL}/dashboard/profile/${p.id}`,
          lastModified: p.updated_at ? new Date(p.updated_at) : new Date(),
          changeFrequency: 'weekly' as const,
          priority: 0.5,
        }))
      }
    }
  } catch (err) {
    // Sitemap funktioniert auch ohne dynamische Seiten — niemals den Build crashen.
    console.warn('[sitemap] Failed to fetch dynamic pages:', err)
  }

  return [...staticPages, ...postPages, ...profilePages]
}
