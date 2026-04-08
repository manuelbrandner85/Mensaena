import type { Metadata } from 'next'
import { createClient } from '@supabase/supabase-js'
import {
  SITE_URL,
  SITE_NAME,
  DEFAULT_OG_IMAGE,
  generateProfileTitle,
  truncateDescription,
} from '@/lib/seo'
import {
  generateProfileSchema,
  generateBreadcrumbSchema,
} from '@/lib/structured-data'
import JsonLd from '@/components/JsonLd'
import PublicProfilePage from './ProfilePage'

// ── Supabase helper ─────────────────────────────────────────────────

function getSupabase() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  if (!url || !key) return null
  return createClient(url, key)
}

// ── Dynamic metadata for public profile pages ───────────────────────

interface Props {
  params: Promise<{ userId: string }>
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { userId } = await params
  const supabase = getSupabase()
  if (!supabase) return { title: 'Profil', robots: { index: false } }

  try {
    const { data: profile } = await supabase
      .from('profiles')
      .select('id, name, bio, avatar_url, privacy_public')
      .eq('id', userId)
      .single()

    if (!profile || profile.privacy_public === false) {
      return {
        title: 'Profil nicht gefunden',
        robots: { index: false, follow: false },
      }
    }

    const title = generateProfileTitle(profile.name || 'Nachbar')
    const description = truncateDescription(
      profile.bio ||
        `${profile.name || 'Nachbar'} ist Mitglied bei Mensaena – Nachbarschaftshilfe neu gedacht.`,
    )
    const canonicalUrl = `${SITE_URL}/dashboard/profile/${userId}`
    const image = profile.avatar_url || `${SITE_URL}${DEFAULT_OG_IMAGE}`

    return {
      title,
      description,
      openGraph: {
        type: 'profile',
        title,
        description,
        url: canonicalUrl,
        siteName: SITE_NAME,
        locale: 'de_DE',
        images: [
          {
            url: image,
            width: 400,
            height: 400,
            alt: `Profil von ${profile.name || 'Nachbar'}`,
          },
        ],
      },
      twitter: {
        card: 'summary',
        title,
        description,
        images: [image],
      },
      alternates: { canonical: canonicalUrl },
      robots: { index: true, follow: true },
    }
  } catch {
    return { title: 'Profil', robots: { index: false } }
  }
}

// ── Page component (server) ─────────────────────────────────────────

export default async function Page({ params }: Props) {
  const { userId } = await params
  const supabase = getSupabase()

  let jsonLdData = null

  if (supabase) {
    try {
      const { data: profile } = await supabase
        .from('profiles')
        .select('id, name, bio, avatar_url, privacy_public')
        .eq('id', userId)
        .single()

      if (profile && profile.privacy_public !== false) {
        const canonicalUrl = `${SITE_URL}/dashboard/profile/${userId}`

        jsonLdData = [
          generateProfileSchema({
            name: profile.name || 'Nachbar',
            description: profile.bio || undefined,
            image: profile.avatar_url || undefined,
            url: canonicalUrl,
          }),
          generateBreadcrumbSchema([
            { name: 'Startseite', url: SITE_URL },
            { name: 'Profil', url: `${SITE_URL}/dashboard/profile` },
            {
              name: profile.name || 'Nachbar',
              url: canonicalUrl,
            },
          ]),
        ]
      }
    } catch {
      // Continue without JSON-LD
    }
  }

  return (
    <>
      {jsonLdData && <JsonLd data={jsonLdData} />}
      <PublicProfilePage />
    </>
  )
}
