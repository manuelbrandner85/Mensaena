import type { SupabaseClient } from '@supabase/supabase-js'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://huaqldjkgyosefzfhjnf.supabase.co'
const BUCKET = 'public'

/**
 * Extrahiert den Storage-Pfad aus einer Supabase Public URL.
 * z.B. https://xyz.supabase.co/storage/v1/object/public/public/social-media/ai-123.png
 *   → social-media/ai-123.png
 */
export function extractStoragePath(url: string): string | null {
  if (!url.includes(SUPABASE_URL)) return null
  const marker = `/storage/v1/object/public/${BUCKET}/`
  const idx = url.indexOf(marker)
  if (idx === -1) return null
  return url.slice(idx + marker.length)
}

/**
 * Löscht Bilder aus Supabase Storage anhand ihrer Public URLs.
 * Überspringt URLs die nicht zum eigenen Storage gehören (z.B. Unsplash).
 */
export async function deleteStorageImages(
  admin: SupabaseClient,
  urls: string[],
): Promise<void> {
  const paths = urls
    .map(extractStoragePath)
    .filter((p): p is string => p !== null)

  if (paths.length === 0) return

  await admin.storage.from(BUCKET).remove(paths)
}
