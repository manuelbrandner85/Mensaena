import { redirect } from 'next/navigation'

/**
 * /search?q=... → Redirect to /dashboard/posts with search query.
 * This ensures the structured-data search action works.
 */
export default async function SearchPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string }>
}) {
  const { q } = await searchParams
  if (q) {
    redirect(`/dashboard/posts?q=${encodeURIComponent(q)}`)
  }
  redirect('/dashboard/posts')
}
