/**
 * Lightweight Zustand-free global store using React external store pattern.
 * Manages minimal user identity state (userId, userName, userAvatar).
 *
 * E4 Note: This coexists with Zustand stores (useNavigationStore, useNotificationStore,
 * useOrganizationStore) by design. Each store serves a different purpose:
 * - useStore: user identity (synced from Supabase auth)
 * - useNavigationStore: UI state (sidebar collapse, mobile menu)
 * - useNotificationStore / useOrganizationStore: domain-specific data
 * Consolidation is not needed unless the pattern becomes confusing.
 */

import { useSyncExternalStore, useCallback } from 'react'

interface AppState {
  userId: string | null
  userName: string | null
  userAvatar: string | null
}

let state: AppState = {
  userId: null,
  userName: null,
  userAvatar: null,
}

const listeners = new Set<() => void>()

function getSnapshot(): AppState {
  return state
}

function subscribe(listener: () => void): () => void {
  listeners.add(listener)
  return () => listeners.delete(listener)
}

function setState(partial: Partial<AppState>) {
  state = { ...state, ...partial }
  listeners.forEach((l) => l())
}

export function useStore(): AppState & { set: (partial: Partial<AppState>) => void } {
  const snap = useSyncExternalStore(subscribe, getSnapshot, getSnapshot)
  const set = useCallback((partial: Partial<AppState>) => setState(partial), [])
  return { ...snap, set }
}
