'use client'

import { useCallback, useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useStore } from '@/store/useStore'
import ProfileHeader from './components/ProfileHeader'
import ProfileStatsBar, { type ProfileStatsData } from './components/ProfileStatsBar'
import ProfileActivityFeed, { type ActivityItem } from './components/ProfileActivityFeed'
import ProfileEditModal, { type EditableProfile } from './components/ProfileEditModal'

// ── Types (Minimal, für die neuen Komponenten) ───────────────────────────────
interface GroupRow {
  id: string
  joined_at: string
  group_id: string
  groups: { name: string; category: string } | { name: string; category: string }[] | null
}
interface ChallengeRow {
  id: string
  joined_at: string
  status: string
  completed_at: string | null
  challenge_id: string
  challenges: { title: string; category: string } | { title: string; category: string }[] | null
}
interface TimebankRow {
  id: string
  hours: number
  description: string | null
  status: string
  created_at: string
  giver_id: string
  receiver_id: string
}
interface PostRow {
  id: string
  title: string
  type: string
  created_at: string
}

// Supabase-Joins können als Objekt ODER Array kommen – hier normalisieren
function unwrap<T>(v: T | T[] | null | undefined): T | null {
  if (!v) return null
  return Array.isArray(v) ? (v[0] ?? null) : v
}

export default function ProfilePage() {
  const store = useStore()
  const [profile, setProfile] = useState<EditableProfile | null>(null)
  const [stats, setStats] = useState<ProfileStatsData | null>(null)
  const [activity, setActivity] = useState<ActivityItem[]>([])
  const [loading, setLoading] = useState(true)
  const [editing, setEditing] = useState(false)

  const loadAll = useCallback(async () => {
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) {
      setLoading(false)
      return
    }
    const userId = user.id
    if (!store.userId) store.set({ userId })

    // 1) Profil laden
    const { data: profileData } = await supabase
      .from('profiles')
      .select('id, name, nickname, bio, location, avatar_url, phone, homepage, created_at')
      .eq('id', userId)
      .single()

    if (profileData) {
      setProfile(profileData as EditableProfile)
      store.set({
        userName: profileData.name ?? null,
        userAvatar: profileData.avatar_url ?? null,
      })
    }

    // 2) Stats + Activity parallel laden
    const [
      givenRes,
      receivedRes,
      groupsCountRes,
      challengesCountRes,
      postsCountRes,
      tbEntriesRes,
      groupJoinsRes,
      challengeJoinsRes,
      recentPostsRes,
    ] = await Promise.all([
      supabase
        .from('timebank_entries')
        .select('hours')
        .eq('giver_id', userId)
        .eq('status', 'confirmed'),
      supabase
        .from('timebank_entries')
        .select('hours')
        .eq('receiver_id', userId)
        .eq('status', 'confirmed'),
      supabase
        .from('group_members')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', userId),
      supabase
        .from('challenge_progress')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', userId)
        .eq('status', 'active'),
      supabase
        .from('posts')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', userId),
      supabase
        .from('timebank_entries')
        .select('id, hours, description, status, created_at, giver_id, receiver_id')
        .or(`giver_id.eq.${userId},receiver_id.eq.${userId}`)
        .order('created_at', { ascending: false })
        .limit(10),
      supabase
        .from('group_members')
        .select('id, joined_at, group_id, groups(name, category)')
        .eq('user_id', userId)
        .order('joined_at', { ascending: false })
        .limit(10),
      supabase
        .from('challenge_progress')
        .select('id, joined_at, status, completed_at, challenge_id, challenges(title, category)')
        .eq('user_id', userId)
        .order('joined_at', { ascending: false })
        .limit(10),
      supabase
        .from('posts')
        .select('id, title, type, created_at')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })
        .limit(10),
    ])

    const sum = (rows: { hours: number }[] | null) =>
      Math.round((rows ?? []).reduce((s, r) => s + (r.hours ?? 0), 0) * 10) / 10

    setStats({
      hoursGiven: sum(givenRes.data),
      hoursReceived: sum(receivedRes.data),
      groupsCount: groupsCountRes.count ?? 0,
      activeChallenges: challengesCountRes.count ?? 0,
      postsCount: postsCountRes.count ?? 0,
    })

    // 3) Activity-Feed zusammenstellen
    const items: ActivityItem[] = []

    for (const row of (tbEntriesRes.data ?? []) as TimebankRow[]) {
      const isGiver = row.giver_id === userId
      const statusBadge =
        row.status === 'confirmed'
          ? 'Bestätigt'
          : row.status === 'pending'
            ? 'Ausstehend'
            : row.status === 'rejected' || row.status === 'cancelled'
              ? 'Abgelehnt'
              : row.status
      items.push({
        id: row.id,
        kind: 'timebank',
        timestamp: row.created_at,
        title: isGiver
          ? `${row.hours}h Hilfe eingetragen`
          : `${row.hours}h Hilfe erhalten`,
        description: row.description ?? undefined,
        href: '/dashboard/zeitbank',
        badge: statusBadge,
      })
    }

    for (const row of (groupJoinsRes.data ?? []) as GroupRow[]) {
      const g = unwrap(row.groups)
      items.push({
        id: row.id,
        kind: 'group',
        timestamp: row.joined_at,
        title: g ? `Gruppe "${g.name}" beigetreten` : 'Gruppe beigetreten',
        description: g?.category ?? undefined,
        href: row.group_id ? `/dashboard/gruppen/${row.group_id}` : '/dashboard/gruppen',
      })
    }

    for (const row of (challengeJoinsRes.data ?? []) as ChallengeRow[]) {
      const c = unwrap(row.challenges)
      const isCompleted = !!row.completed_at
      items.push({
        id: row.id,
        kind: 'challenge',
        timestamp: row.completed_at ?? row.joined_at,
        title: c
          ? isCompleted
            ? `Challenge "${c.title}" abgeschlossen`
            : `Challenge "${c.title}" gestartet`
          : isCompleted
            ? 'Challenge abgeschlossen'
            : 'Challenge gestartet',
        description: c?.category ?? undefined,
        href: row.challenge_id
          ? `/dashboard/challenges/${row.challenge_id}`
          : '/dashboard/challenges',
        badge: isCompleted ? 'Abgeschlossen' : undefined,
      })
    }

    for (const row of (recentPostsRes.data ?? []) as PostRow[]) {
      items.push({
        id: row.id,
        kind: 'post',
        timestamp: row.created_at,
        title: `Beitrag erstellt: ${row.title}`,
        href: `/dashboard/posts/${row.id}`,
      })
    }

    items.sort(
      (a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime(),
    )
    setActivity(items.slice(0, 15))

    setLoading(false)
  }, [store])

  useEffect(() => {
    loadAll()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // ── Loading-Skeleton ───────────────────────────────────────────────────────
  if (loading || !profile || !stats) {
    return (
      <div className="max-w-4xl mx-auto animate-pulse">
        <div className="h-40 sm:h-56 rounded-2xl sm:rounded-3xl bg-gradient-to-br from-primary-200 to-primary-300" />
        <div className="px-4 sm:px-8 -mt-16 sm:-mt-20">
          <div className="h-32 w-32 sm:h-36 sm:w-36 rounded-full bg-gray-200 ring-4 ring-white mx-auto sm:mx-0" />
          <div className="mt-4 h-6 w-48 bg-gray-200 rounded mx-auto sm:mx-0" />
          <div className="mt-2 h-4 w-32 bg-gray-100 rounded mx-auto sm:mx-0" />
        </div>
        <div className="mt-6 px-4 sm:px-0 grid grid-cols-2 md:grid-cols-4 gap-3">
          {[0, 1, 2, 3].map((i) => (
            <div key={i} className="h-28 rounded-2xl bg-gray-100" />
          ))}
        </div>
        <div className="mt-6 h-64 rounded-2xl bg-gray-100 mx-4 sm:mx-0" />
      </div>
    )
  }

  return (
    <div className="max-w-4xl mx-auto pb-12">
      <ProfileHeader profile={profile} onEdit={() => setEditing(true)} />

      <div className="mt-6 sm:mt-8 px-4 sm:px-0 space-y-5 sm:space-y-6">
        <ProfileStatsBar stats={stats} />
        <ProfileActivityFeed items={activity} />
      </div>

      {editing && (
        <ProfileEditModal
          profile={profile}
          onClose={() => setEditing(false)}
          onSaved={(updated) => {
            setProfile(updated)
            store.set({
              userName: updated.name ?? null,
              userAvatar: updated.avatar_url ?? null,
            })
            setEditing(false)
          }}
        />
      )}
    </div>
  )
}
