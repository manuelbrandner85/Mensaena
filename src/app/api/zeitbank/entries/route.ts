import { NextRequest, NextResponse } from 'next/server'
import { getApiClient, err } from '@/lib/supabase/api-auth'

// ── Typen ──────────────────────────────────────────────────────────────────────
interface Profile {
  id: string
  name: string | null
  nickname: string | null
  avatar_url: string | null
}

interface DBEntry {
  id: string
  giver_id: string
  receiver_id: string
  hours: number
  description: string
  category: string
  status: 'pending' | 'confirmed' | 'cancelled' | 'rejected'
  confirmed_at: string | null
  created_at: string
  updated_at: string | null
  help_date: string | null
  giver: Profile | null
  receiver: Profile | null
}

// Normalisiert DB-Felder auf API-Felder
function normalize(e: DBEntry) {
  return {
    id:          e.id,
    helper_id:   e.giver_id,
    helped_id:   e.receiver_id,
    description: e.description,
    hours:       e.hours,
    date:        e.help_date ?? e.created_at?.split('T')[0] ?? null,
    category:    e.category,
    status:      e.status === 'cancelled' ? 'rejected' : e.status,
    created_at:  e.created_at,
    updated_at:  e.updated_at,
    helper:      e.giver,
    helped:      e.receiver,
  }
}

// ── GET /api/zeitbank/entries ──────────────────────────────────────────────────
// Eigene Einträge laden (als Helfer UND als Empfänger)
export async function GET() {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()

  const { data, error } = await supabase
    .from('timebank_entries')
    .select(`
      *,
      giver:giver_id(id, name, nickname, avatar_url),
      receiver:receiver_id(id, name, nickname, avatar_url)
    `)
    .or(`giver_id.eq.${user.id},receiver_id.eq.${user.id}`)
    .order('created_at', { ascending: false })

  if (error) return err.internal(error.message)

  return NextResponse.json({ data: (data ?? []).map(e => normalize(e as unknown as DBEntry)) })
}

// ── POST /api/zeitbank/entries ─────────────────────────────────────────────────
// Neuen Eintrag erstellen (Status: pending)
export async function POST(req: NextRequest) {
  const { supabase, user } = await getApiClient()
  if (!user) return err.unauthorized()

  let body: Record<string, unknown>
  try { body = await req.json() } catch { return err.bad('Ungültiges JSON') }

  const { helped_id, description, hours, date, category } = body

  // Validierung
  if (!helped_id || typeof helped_id !== 'string')
    return err.bad('helped_id ist erforderlich')
  if (helped_id === user.id)
    return err.bad('Du kannst dir nicht selbst Hilfe eintragen')
  if (!description || typeof description !== 'string' || !description.trim())
    return err.bad('description ist erforderlich')
  if (typeof hours !== 'number' || hours <= 0 || hours > 24)
    return err.bad('hours muss zwischen 0 und 24 liegen')

  const helpDate = typeof date === 'string' && date
    ? date
    : new Date().toISOString().split('T')[0]

  const { data: entry, error } = await supabase
    .from('timebank_entries')
    .insert({
      giver_id:    user.id,
      receiver_id: helped_id,
      description: description.trim(),
      hours,
      help_date:   helpDate,
      category:    typeof category === 'string' ? category : 'general',
      status:      'pending',
    })
    .select(`
      *,
      giver:giver_id(id, name, nickname, avatar_url),
      receiver:receiver_id(id, name, nickname, avatar_url)
    `)
    .single()

  if (error) return err.internal(error.message)

  const typedEntry = entry as unknown as DBEntry
  const helperName = typedEntry.giver?.name ?? typedEntry.giver?.nickname ?? 'Jemand'

  // Bestätigungs-Notification für den Empfänger
  await supabase.from('zeitbank_notifications').insert({
    user_id:  helped_id,
    entry_id: typedEntry.id,
    type:     'confirmation_request',
    message:  `${helperName} hat ${hours} Std. Hilfe eingetragen. Bitte bestätige oder lehne ab.`,
  })

  return NextResponse.json({ data: normalize(typedEntry) }, { status: 201 })
}
