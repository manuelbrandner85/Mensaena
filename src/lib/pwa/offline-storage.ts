/* ═══════════════════════════════════════════════════════════════════════
   OFFLINE  STORAGE  –  IndexedDB wrapper
   Caches profile, posts and queues offline actions for sync.
   ═══════════════════════════════════════════════════════════════════════ */

const DB_NAME = 'mensaena-offline'
const DB_VERSION = 1

// ── Types ────────────────────────────────────────────────────────────

export interface QueuedAction {
  id?: number
  type: 'create_post' | 'send_message' | 'update_profile'
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  payload: Record<string, any>
  createdAt: string
  status: 'pending' | 'synced' | 'failed'
}

// ── Open DB ──────────────────────────────────────────────────────────

function openDB(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    if (typeof indexedDB === 'undefined') {
      reject(new Error('IndexedDB not available'))
      return
    }

    const request = indexedDB.open(DB_NAME, DB_VERSION)

    request.onupgradeneeded = () => {
      const db = request.result
      if (!db.objectStoreNames.contains('cached-profile')) {
        db.createObjectStore('cached-profile')
      }
      if (!db.objectStoreNames.contains('cached-posts')) {
        db.createObjectStore('cached-posts', { keyPath: 'id' })
      }
      if (!db.objectStoreNames.contains('queued-actions')) {
        db.createObjectStore('queued-actions', {
          keyPath: 'id',
          autoIncrement: true,
        })
      }
    }

    request.onsuccess = () => resolve(request.result)
    request.onerror = () => reject(request.error)
  })
}

// ── Profile cache ────────────────────────────────────────────────────

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function cacheProfile(profile: Record<string, any>): Promise<void> {
  const db = await openDB()
  return new Promise((resolve, reject) => {
    const tx = db.transaction('cached-profile', 'readwrite')
    tx.objectStore('cached-profile').put(profile, 'current')
    tx.oncomplete = () => resolve()
    tx.onerror = () => reject(tx.error)
  })
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function getCachedProfile(): Promise<Record<string, any> | null> {
  try {
    const db = await openDB()
    return new Promise((resolve, reject) => {
      const tx = db.transaction('cached-profile', 'readonly')
      const req = tx.objectStore('cached-profile').get('current')
      req.onsuccess = () => resolve(req.result || null)
      req.onerror = () => reject(req.error)
    })
  } catch {
    return null
  }
}

// ── Posts cache ──────────────────────────────────────────────────────

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function cachePosts(posts: Array<Record<string, any>>): Promise<void> {
  const db = await openDB()
  return new Promise((resolve, reject) => {
    const tx = db.transaction('cached-posts', 'readwrite')
    const store = tx.objectStore('cached-posts')
    // Clear old posts first
    store.clear()
    // Add new posts (max 20)
    posts.slice(0, 20).forEach((post) => store.put(post))
    tx.oncomplete = () => resolve()
    tx.onerror = () => reject(tx.error)
  })
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function getCachedPosts(): Promise<Array<Record<string, any>>> {
  try {
    const db = await openDB()
    return new Promise((resolve, reject) => {
      const tx = db.transaction('cached-posts', 'readonly')
      const req = tx.objectStore('cached-posts').getAll()
      req.onsuccess = () => {
        const posts = req.result || []
        posts.sort(
          (a: { created_at?: string }, b: { created_at?: string }) =>
            new Date(b.created_at || 0).getTime() -
            new Date(a.created_at || 0).getTime(),
        )
        resolve(posts)
      }
      req.onerror = () => reject(req.error)
    })
  } catch {
    return []
  }
}

// ── Queued actions ───────────────────────────────────────────────────

export async function queueAction(
  type: QueuedAction['type'],
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  payload: Record<string, any>,
): Promise<void> {
  const db = await openDB()
  return new Promise((resolve, reject) => {
    const tx = db.transaction('queued-actions', 'readwrite')
    tx.objectStore('queued-actions').add({
      type,
      payload,
      createdAt: new Date().toISOString(),
      status: 'pending',
    })
    tx.oncomplete = () => resolve()
    tx.onerror = () => reject(tx.error)
  })
}

export async function getQueuedActions(): Promise<QueuedAction[]> {
  try {
    const db = await openDB()
    return new Promise((resolve, reject) => {
      const tx = db.transaction('queued-actions', 'readonly')
      const req = tx.objectStore('queued-actions').getAll()
      req.onsuccess = () => {
        const actions = (req.result || []) as QueuedAction[]
        resolve(actions.filter((a) => a.status === 'pending'))
      }
      req.onerror = () => reject(req.error)
    })
  } catch {
    return []
  }
}

export async function markActionSynced(id: number): Promise<void> {
  const db = await openDB()
  return new Promise((resolve, reject) => {
    const tx = db.transaction('queued-actions', 'readwrite')
    const store = tx.objectStore('queued-actions')
    const req = store.get(id)
    req.onsuccess = () => {
      if (req.result) {
        req.result.status = 'synced'
        store.put(req.result)
      }
    }
    tx.oncomplete = () => resolve()
    tx.onerror = () => reject(tx.error)
  })
}

export async function markActionFailed(id: number): Promise<void> {
  const db = await openDB()
  return new Promise((resolve, reject) => {
    const tx = db.transaction('queued-actions', 'readwrite')
    const store = tx.objectStore('queued-actions')
    const req = store.get(id)
    req.onsuccess = () => {
      if (req.result) {
        req.result.status = 'failed'
        store.put(req.result)
      }
    }
    tx.oncomplete = () => resolve()
    tx.onerror = () => reject(tx.error)
  })
}

export async function clearSyncedActions(): Promise<void> {
  const db = await openDB()
  return new Promise((resolve, reject) => {
    const tx = db.transaction('queued-actions', 'readwrite')
    const store = tx.objectStore('queued-actions')
    const req = store.getAll()
    req.onsuccess = () => {
      const all = req.result || []
      all.forEach((a: QueuedAction) => {
        if (a.status === 'synced' && a.id !== undefined) {
          store.delete(a.id)
        }
      })
    }
    tx.oncomplete = () => resolve()
    tx.onerror = () => reject(tx.error)
  })
}

// ── Sync logic ───────────────────────────────────────────────────────

export async function syncQueuedActions(): Promise<{
  synced: number
  failed: number
}> {
  const { createClient } = await import('@/lib/supabase/client')
  const supabase = createClient()
  const actions = await getQueuedActions()
  let synced = 0
  let failed = 0

  for (const action of actions) {
    try {
      if (action.type === 'create_post') {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        await (supabase.from('posts') as any).insert(action.payload)
      } else if (action.type === 'send_message') {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        await (supabase.from('messages') as any).insert(action.payload)
      } else if (action.type === 'update_profile') {
        const { id, ...rest } = action.payload
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        await (supabase.from('profiles') as any).update(rest).eq('id', id)
      }
      if (action.id !== undefined) await markActionSynced(action.id)
      synced++
    } catch {
      if (action.id !== undefined) await markActionFailed(action.id)
      failed++
    }
  }

  await clearSyncedActions()
  return { synced, failed }
}
