'use client'

import { useState, useEffect, useCallback, useRef } from 'react'
import { createClient } from '@/lib/supabase/client'
import { handleSupabaseError } from '@/lib/errors'
import { useStore } from '@/store/useStore'
import toast from 'react-hot-toast'
import type { SettingsProfile, SettingsTab, DataExport, BlockedUser } from '../types'

export function useSettings() {
  const store = useStore()

  // State
  const [settings, setSettings] = useState<SettingsProfile | null>(null)
  const [blockedUsers, setBlockedUsers] = useState<BlockedUser[]>([])
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [activeTab, setActiveTab] = useState<SettingsTab>('profile')
  const [userId, setUserId] = useState<string | null>(null)

  // Dirty tracking: which tabs have unsaved changes
  const [dirtyTabs, setDirtyTabs] = useState<Set<SettingsTab>>(new Set())

  const markDirty = useCallback((tab: SettingsTab) => {
    setDirtyTabs(prev => {
      if (prev.has(tab)) return prev
      const next = new Set(prev)
      next.add(tab)
      return next
    })
  }, [])

  const clearDirty = useCallback((tab: SettingsTab) => {
    setDirtyTabs(prev => {
      if (!prev.has(tab)) return prev
      const next = new Set(prev)
      next.delete(tab)
      return next
    })
  }, [])

  // ────────────────────────────────────────────────
  // Username availability check (debounced)
  // ────────────────────────────────────────────────
  const usernameTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const [usernameAvailable, setUsernameAvailable] = useState<boolean | null>(null)
  const [checkingUsername, setCheckingUsername] = useState(false)

  const checkUsername = useCallback((username: string) => {
    // Clear previous timer
    if (usernameTimerRef.current) clearTimeout(usernameTimerRef.current)

    if (!username || username.length < 3) {
      setUsernameAvailable(null)
      setCheckingUsername(false)
      return
    }

    setCheckingUsername(true)
    setUsernameAvailable(null)

    // Debounce 500ms
    usernameTimerRef.current = setTimeout(async () => {
      try {
        const supabase = createClient()
        // Try username column first, fall back to display_name
        const { data, error } = await supabase
          .from('profiles')
          .select('id')
          .eq('username', username.toLowerCase().trim())
          .neq('id', userId ?? '')
          .limit(1)

        if (error && error.message?.includes('column') && error.message?.includes('does not exist')) {
          // username column doesn't exist – treat as available
          setUsernameAvailable(true)
        } else if (!error) {
          setUsernameAvailable(!data || data.length === 0)
        }
      } catch {
        // Ignore errors in username check – treat as available
        setUsernameAvailable(true)
      }
      setCheckingUsername(false)
    }, 500)
  }, [userId])

  // ────────────────────────────────────────────────
  // Lade alle Settings aus profiles-Tabelle
  // ────────────────────────────────────────────────
  const loadSettings = useCallback(async (): Promise<void> => {
    setLoading(true)
    try {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) { setLoading(false); return }

      setUserId(user.id)
      if (!store.userId) store.set({ userId: user.id })

      // Load profile
      const { data: profileData, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', user.id)
        .single()

      if (error && error.code !== 'PGRST116') {
        handleSupabaseError(error)
      }

      if (profileData) {
        setSettings({ ...profileData, email: user.email ?? '' } as SettingsProfile)
        store.set({
          userName: profileData.name ?? profileData.display_name ?? null,
          userAvatar: profileData.avatar_url ?? null,
        })
      }

      // Load blocked users
      const { data: blocksData } = await supabase
        .from('user_blocks')
        .select('id, blocked_id, created_at, profiles:blocked_id(name, avatar_url)')
        .eq('blocker_id', user.id)
        .order('created_at', { ascending: false })

      if (blocksData) {
        setBlockedUsers(blocksData as unknown as BlockedUser[])
      }
    } catch (err) {
      console.error('useSettings loadSettings error:', err)
    }
    setLoading(false)
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // Auto-load on mount
  useEffect(() => { loadSettings() }, [loadSettings])

  // ────────────────────────────────────────────────
  // Speichere geänderte Settings (Partial Update)
  // Robust: retries by stripping unknown columns
  // ────────────────────────────────────────────────
  const saveSettings = useCallback(async (updates: Partial<SettingsProfile>, message?: string): Promise<boolean> => {
    if (!userId) return false
    setSaving(true)
    const supabase = createClient()

    // Remove non-column fields before sending to DB
    const { email: _email, ...cleanUpdates } = updates as SettingsProfile & { email?: string }
    void _email

    // Attempt save, retry by stripping missing columns
    let payload: Record<string, unknown> = { ...cleanUpdates, updated_at: new Date().toISOString() }
    let lastError: typeof error = null
    let error: { message: string; code?: string; details?: string } | null = null

    for (let attempt = 0; attempt < 4; attempt++) {
      const result = await supabase
        .from('profiles')
        .update(payload)
        .eq('id', userId)

      error = result.error

      if (!error) break

      // If a column doesn't exist, strip it and retry
      const colMatch = error.message?.match(/column\s+["']?(\w+)["']?.*does not exist/i)
        || error.message?.match(/Could not find.*column\s+["']?(\w+)["']?/i)
      if (colMatch) {
        const badCol = colMatch[1]
        console.warn(`[saveSettings] Column "${badCol}" does not exist, stripping and retrying`)
        delete payload[badCol]
        lastError = error
        error = null
        continue
      }

      // Other errors: stop retrying
      break
    }

    setSaving(false)

    if (error) {
      toast.error('Fehler beim Speichern. Bitte versuche es erneut.')
      handleSupabaseError(error)
      return false
    }

    if (lastError) {
      console.warn('[saveSettings] Some columns were skipped but save succeeded')
    }

    setSettings(prev => prev ? { ...prev, ...updates } : null)

    // Sync global store if name or avatar changed
    if ('name' in updates) store.set({ userName: (updates as Record<string, unknown>).name as string | null })
    if ('display_name' in updates) store.set({ userName: updates.display_name ?? null })
    if ('avatar_url' in updates) store.set({ userAvatar: updates.avatar_url ?? null })

    // Clear dirty for current tab
    clearDirty(activeTab)

    if (message) toast.success(message)
    else toast.success('Einstellungen gespeichert \u2713')
    return true
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userId, activeTab, clearDirty])

  // ────────────────────────────────────────────────
  // Passwort ändern über Supabase Auth
  // Workaround: Re-authenticate with signInWithPassword, then updateUser
  // ────────────────────────────────────────────────
  const changePassword = useCallback(async (
    currentPassword: string,
    newPassword: string
  ): Promise<{ success: boolean; error?: string }> => {
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user?.email) return { success: false, error: 'Nicht eingeloggt' }

    // Verify current password
    const { error: verifyError } = await supabase.auth.signInWithPassword({
      email: user.email,
      password: currentPassword,
    })
    if (verifyError) return { success: false, error: 'Aktuelles Passwort ist falsch' }

    // Set new password
    const { error } = await supabase.auth.updateUser({ password: newPassword })
    if (error) return { success: false, error: error.message }
    return { success: true }
  }, [])

  // ────────────────────────────────────────────────
  // DSGVO Daten-Export: Sammle ALLE Nutzerdaten aus ALLEN Tabellen
  // ────────────────────────────────────────────────
  const exportAllData = useCallback(async (): Promise<DataExport | null> => {
    if (!userId) return null
    toast('Daten werden exportiert...', { icon: 'ℹ️' })
    try {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()

      // Sammle parallel aus allen Tabellen
      const [
        profile, posts, messages, interactions, savedPosts,
        trustGiven, trustReceived, notifications, convMembers,
        reports, blocks,
      ] = await Promise.all([
        supabase.from('profiles').select('*').eq('id', userId).single(),
        supabase.from('posts').select('*').eq('user_id', userId),
        supabase.from('messages').select('*').eq('sender_id', userId),
        supabase.from('interactions').select('*').eq('helper_id', userId),
        supabase.from('saved_posts').select('*').eq('user_id', userId),
        supabase.from('trust_ratings').select('*').eq('rater_id', userId),
        supabase.from('trust_ratings').select('*').eq('rated_id', userId),
        supabase.from('notifications').select('*').eq('user_id', userId),
        supabase.from('conversation_members').select('conversation_id').eq('user_id', userId),
        supabase.from('reports').select('*').eq('reporter_id', userId),
        supabase.from('user_blocks').select('*').eq('blocker_id', userId),
      ])

      const exportData: DataExport = {
        exported_at: new Date().toISOString(),
        user: {
          id: userId,
          email: user?.email ?? '',
          created_at: user?.created_at ?? '',
        },
        profile: (profile.data ?? {}) as Record<string, unknown>,
        posts: (posts.data ?? []) as Record<string, unknown>[],
        messages: (messages.data ?? []) as Record<string, unknown>[],
        interactions: (interactions.data ?? []) as Record<string, unknown>[],
        saved_posts: (savedPosts.data ?? []) as Record<string, unknown>[],
        trust_ratings_given: (trustGiven.data ?? []) as Record<string, unknown>[],
        trust_ratings_received: (trustReceived.data ?? []) as Record<string, unknown>[],
        notifications: (notifications.data ?? []) as Record<string, unknown>[],
        conversations: (convMembers.data ?? []) as Record<string, unknown>[],
        reports: (reports.data ?? []) as Record<string, unknown>[],
        blocks: (blocks.data ?? []) as Record<string, unknown>[],
      }

      // JSON-Datei erstellen und downloaden
      const blob = new Blob([JSON.stringify(exportData, null, 2)], { type: 'application/json' })
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = `mensaena-daten-export-${new Date().toISOString().split('T')[0]}.json`
      a.click()
      URL.revokeObjectURL(url)

      toast.success('Daten-Export heruntergeladen')
      return exportData
    } catch (err) {
      console.error('Export error:', err)
      toast.error('Export fehlgeschlagen')
      return null
    }
  }, [userId])

  // ────────────────────────────────────────────────
  // Zähle Nutzerdaten für Live-Übersicht vor Löschung
  // ────────────────────────────────────────────────
  const countUserData = useCallback(async (): Promise<{
    posts: number
    messages: number
    interactions: number
    saved_posts: number
    trust_ratings: number
    conversations: number
    notifications: number
  }> => {
    const zero = { posts: 0, messages: 0, interactions: 0, saved_posts: 0, trust_ratings: 0, conversations: 0, notifications: 0 }
    if (!userId) return zero
    try {
      const supabase = createClient()
      const [posts, messages, interactions, savedPosts, trustRatings, convMembers, notifications] = await Promise.all([
        supabase.from('posts').select('id', { count: 'exact', head: true }).eq('user_id', userId),
        supabase.from('messages').select('id', { count: 'exact', head: true }).eq('sender_id', userId),
        supabase.from('interactions').select('id', { count: 'exact', head: true }).eq('helper_id', userId),
        supabase.from('saved_posts').select('id', { count: 'exact', head: true }).eq('user_id', userId),
        supabase.from('trust_ratings').select('id', { count: 'exact', head: true }).or(`rater_id.eq.${userId},rated_id.eq.${userId}`),
        supabase.from('conversation_members').select('conversation_id', { count: 'exact', head: true }).eq('user_id', userId),
        supabase.from('notifications').select('id', { count: 'exact', head: true }).eq('user_id', userId),
      ])
      return {
        posts: posts.count ?? 0,
        messages: messages.count ?? 0,
        interactions: interactions.count ?? 0,
        saved_posts: savedPosts.count ?? 0,
        trust_ratings: trustRatings.count ?? 0,
        conversations: convMembers.count ?? 0,
        notifications: notifications.count ?? 0,
      }
    } catch {
      return zero
    }
  }, [userId])

  // ────────────────────────────────────────────────
  // Account-Löschung Schritt 1: Markiere zur Löschung (14 Tage Frist)
  // ────────────────────────────────────────────────
  const requestAccountDeletion = useCallback(async (): Promise<boolean> => {
    if (!userId) return false
    const supabase = createClient()
    const { error } = await supabase
      .from('profiles')
      .update({
        deletion_requested_at: new Date().toISOString(),
        deletion_confirmed: false,
        updated_at: new Date().toISOString(),
      })
      .eq('id', userId)

    if (error) {
      handleSupabaseError(error)
      return false
    }

    setSettings(prev => prev ? {
      ...prev,
      deletion_requested_at: new Date().toISOString(),
      deletion_confirmed: false,
    } : null)

    toast.success('Account zur Löschung vorgemerkt. Du hast 14 Tage zum Widerrufen.')
    return true
  }, [userId])

  // ────────────────────────────────────────────────
  // Account-Löschung Schritt 2: Endgültig löschen
  // REIHENFOLGE ist wichtig wegen Foreign Keys:
  // 1. messages, 2. conversation_members, 3. notifications,
  // 4. saved_posts, 5. trust_ratings, 6. interactions,
  // 7. user_blocks, 8. reports, 9. posts,
  // 10. Avatar aus Storage, 11. profiles, 12. Auth-User
  // ────────────────────────────────────────────────
  const confirmAccountDeletion = useCallback(async (): Promise<boolean> => {
    if (!userId) return false
    const supabase = createClient()

    try {
      // 1. messages (sender_id) – anonymize content
      await supabase
        .from('messages')
        .update({ content: '[Geloescht]', deleted_at: new Date().toISOString() })
        .eq('sender_id', userId)

      // 2. conversation_members (user_id)
      await supabase
        .from('conversation_members')
        .delete()
        .eq('user_id', userId)

      // 3. notifications (user_id)
      await supabase
        .from('notifications')
        .delete()
        .eq('user_id', userId)

      // 4. saved_posts (user_id)
      await supabase
        .from('saved_posts')
        .delete()
        .eq('user_id', userId)

      // 5. trust_ratings (rater_id AND rated_id)
      await supabase.from('trust_ratings').delete().eq('rater_id', userId)
      await supabase.from('trust_ratings').delete().eq('rated_id', userId)

      // 6. interactions (helper_id)
      await supabase.from('interactions').delete().eq('helper_id', userId)

      // 7. user_blocks (blocker_id AND blocked_id)
      await supabase.from('user_blocks').delete().eq('blocker_id', userId)
      await supabase.from('user_blocks').delete().eq('blocked_id', userId)

      // 8. reports (reporter_id)
      await supabase.from('reports').delete().eq('reporter_id', userId)

      // 9. posts (author_id) – anonymize, don't delete (community integrity)
      await supabase.from('posts').update({
        contact_phone: null,
        contact_whatsapp: null,
        contact_email: null,
        is_anonymous: true,
      }).eq('user_id', userId)

      // 10. Avatar aus Supabase Storage löschen (both new scoped + legacy flat paths)
      const avatarExtensions = ['webp', 'jpg', 'jpeg', 'png']
      const avatarPaths = [
        ...avatarExtensions.map(ext => `${userId}/avatar.${ext}`),
        ...avatarExtensions.map(ext => `${userId}.${ext}`),
      ]
      await supabase.storage.from('avatars').remove(avatarPaths)

      // 11. profiles (id) – anonymize
      await supabase.from('profiles').update({
        name: 'Geloeschter Nutzer',
        display_name: null,
        username: null,
        bio: '',
        avatar_url: null,
        phone: null,
        homepage: null,
        skills: null,
        location: null,
        latitude: null,
        longitude: null,
        address: null,
        emergency_contacts: '[]',
        deletion_confirmed: true,
        updated_at: new Date().toISOString(),
      }).eq('id', userId)

      // 12. Auth-User: Über Edge Function
      try {
        await supabase.functions.invoke('delete-user', { body: { userId } })
      } catch {
        console.warn('delete-user edge function not available, signing out')
      }

      // Sign out
      await supabase.auth.signOut()

      toast.success('Dein Account wurde gelöscht. Auf Wiedersehen.')
      window.location.href = '/'
      return true
    } catch (err) {
      console.error('Account deletion error:', err)
      toast.error('Löschung fehlgeschlagen. Bitte kontaktiere den Support.')
      return false
    }
  }, [userId])

  // ────────────────────────────────────────────────
  // Unblock a user
  // ────────────────────────────────────────────────
  const unblockUser = useCallback(async (blockId: string): Promise<boolean> => {
    const supabase = createClient()
    const { error } = await supabase.from('user_blocks').delete().eq('id', blockId)
    if (handleSupabaseError(error)) return false
    setBlockedUsers(prev => prev.filter(b => b.id !== blockId))
    toast.success('Nutzer entblockt')
    return true
  }, [])

  // ────────────────────────────────────────────────
  // Geocoding: Adresse → Koordinaten (Nominatim)
  // ────────────────────────────────────────────────
  const geocodeAddress = useCallback(async (address: string): Promise<{ lat: number; lng: number } | null> => {
    if (!address.trim()) return null
    try {
      const q = encodeURIComponent(address.trim())
      const res = await fetch(
        `https://nominatim.openstreetmap.org/search?q=${q}&format=json&limit=1&countrycodes=de,at,ch`,
        { headers: { 'User-Agent': 'Mensaena/1.0' } }
      )
      const data = await res.json()
      if (data[0]) {
        return { lat: parseFloat(data[0].lat), lng: parseFloat(data[0].lon) }
      }
    } catch { /* geocoding optional */ }
    return null
  }, [])

  return {
    settings,
    loading,
    saving,
    activeTab,
    setActiveTab,
    userId,
    blockedUsers,
    dirtyTabs,
    markDirty,
    clearDirty,
    checkUsername,
    usernameAvailable,
    checkingUsername,
    loadSettings,
    saveSettings,
    changePassword,
    exportAllData,
    requestAccountDeletion,
    confirmAccountDeletion,
    countUserData,
    geocodeAddress,
    unblockUser,
  }
}
