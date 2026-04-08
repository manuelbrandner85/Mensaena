import type { Metadata } from 'next'
import { createClient } from '@supabase/supabase-js'
import {
  SITE_URL,
  SITE_NAME,
  generatePostTitle,
  truncateDescription,
  getCategoryLabel,
} from '@/lib/seo'
import {
  generatePostSchema,
  generateBreadcrumbSchema,
} from '@/lib/structured-data'
import JsonLd from '@/components/JsonLd'
import PostDetailPage from './PostDetailPage'

// ── Supabase helper (server-only, no singleton) ─────────────────────

function getSupabase() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  if (!url || !key) return null
  return createClient(url, key)
}

// ── Dynamic metadata for post detail pages ──────────────────────────

interface Props {
  params: Promise<{ id: string }>
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { id } = await params
  const supabase = getSupabase()
  if (!supabase) return { title: 'Beitrag', robots: { index: false } }

  try {
    const { data: post } = await supabase
      .from('posts')
      .select(
        'id, title, description, type, category, created_at, updated_at, user_id, tags, profiles(name)',
      )
      .eq('id', id)
      .single()

    if (!post) {
      return {
        title: 'Beitrag nicht gefunden',
        robots: { index: false, follow: false },
      }
    }

    const title = generatePostTitle(post.title)
    const description = truncateDescription(
      post.description || `${post.title} – Nachbarschaftshilfe auf Mensaena`,
    )
    const authorName =
      (post.profiles as { name?: string } | null)?.name ?? 'Nachbar'
    const categoryLabel = getCategoryLabel(post.category || post.type || '')
    const canonicalUrl = `${SITE_URL}/dashboard/posts/${id}`
    const ogImageUrl = `${SITE_URL}/api/og?title=${encodeURIComponent(post.title)}&category=${encodeURIComponent(post.category || post.type || '')}`

    return {
      title,
      description,
      openGraph: {
        type: 'article',
        title,
        description,
        url: canonicalUrl,
        siteName: SITE_NAME,
        locale: 'de_DE',
        publishedTime: post.created_at,
        modifiedTime: post.updated_at || post.created_at,
        authors: [authorName],
        tags: post.tags ?? [categoryLabel],
        images: [
          {
            url: ogImageUrl,
            width: 1200,
            height: 630,
            alt: post.title,
          },
        ],
      },
      twitter: {
        card: 'summary_large_image',
        title,
        description,
        images: [ogImageUrl],
      },
      alternates: { canonical: canonicalUrl },
      robots: { index: true, follow: true },
    }
  } catch {
    return { title: 'Beitrag', robots: { index: false } }
  }
}

// ── Page component (server) ─────────────────────────────────────────

export default async function Page({ params }: Props) {
  const { id } = await params
  const supabase = getSupabase()

  let jsonLdData = null

  if (supabase) {
    try {
      const { data: post } = await supabase
        .from('posts')
        .select(
          'id, title, description, type, category, created_at, updated_at, profiles(name)',
        )
        .eq('id', id)
        .single()

      if (post) {
        const authorName =
          (post.profiles as { name?: string } | null)?.name ?? 'Nachbar'
        const categoryLabel = getCategoryLabel(
          post.category || post.type || '',
        )
        const canonicalUrl = `${SITE_URL}/dashboard/posts/${id}`

        jsonLdData = [
          generatePostSchema({
            title: post.title,
            description:
              post.description ||
              `${post.title} – Nachbarschaftshilfe auf Mensaena`,
            datePublished: post.created_at,
            dateModified: post.updated_at || post.created_at,
            authorName,
            category: categoryLabel,
            url: canonicalUrl,
          }),
          generateBreadcrumbSchema([
            { name: 'Startseite', url: SITE_URL },
            { name: 'Beiträge', url: `${SITE_URL}/dashboard` },
            { name: post.title, url: canonicalUrl },
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
      <PostDetailPage />
    </>
  )
}
