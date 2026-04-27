import { NextResponse } from 'next/server'
import { getApiClient, err } from '@/lib/supabase/api-auth'

/**
 * POST /api/notifications/test
 *
 * Sendet eine Test-Push-Benachrichtigung an den angemeldeten User.
 * Nützlich um zu prüfen ob Push-Subscriptions korrekt funktionieren.
 */
export async function POST() {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()

  const { error } = await supabase.from('notifications').insert({
    user_id:  user.id,
    type:     'test',
    category: 'system',
    title:    '🔔 Test-Benachrichtigung',
    content:  'Push-Benachrichtigungen funktionieren korrekt! Du erhältst alle wichtigen Mensaena-Meldungen.',
    link:     '/dashboard/notifications',
    metadata: { test: true },
  })

  if (error) {
    console.error('[notifications/test] insert error:', error.message)
    return err.internal(error.message)
  }

  return NextResponse.json({ ok: true })
}
