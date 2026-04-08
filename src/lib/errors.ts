/**
 * Centralised Supabase error handling.
 */
import toast from 'react-hot-toast'

/**
 * Handles a Supabase error object: logs it to the console and
 * shows a toast with a user-friendly German message.
 * Returns `true` if there was an error, `false` otherwise.
 */
export function handleSupabaseError(
  error: { message: string; code?: string; details?: string } | null | undefined,
  fallbackMessage = 'Ein Fehler ist aufgetreten. Bitte versuche es erneut.',
): boolean {
  if (!error) return false

  console.error('[Supabase]', error.message, error.code, error.details)

  // Map common Supabase error codes to German messages
  const map: Record<string, string> = {
    '23505': 'Dieser Eintrag existiert bereits.',
    '42501': 'Keine Berechtigung fuer diese Aktion.',
    '23503': 'Verknuepfter Datensatz nicht gefunden.',
    PGRST116: 'Datensatz nicht gefunden.',
  }

  const msg = (error.code && map[error.code]) || fallbackMessage
  toast.error(msg)
  return true
}
