'use client'

import { useState, useEffect, useCallback, useRef } from 'react'
import { createClient } from '@/lib/supabase/client'
import { checkRateLimit } from '@/lib/rate-limit'

// ── Types ────────────────────────────────────────────────────────────
export type BoardCategory =
  | 'general'
  | 'gesucht'
  | 'biete'
  | 'event'
  | 'info'
  | 'warnung'
  | 'verloren'
  | 'fundbuero'

export type BoardColor = 'yellow' | 'green' | 'blue' | 'pink' | 'orange' | 'purple'

export type BoardStatus = 'active' | 'expired' | 'hidden' | 'deleted'

export interface BoardPost {
  id: string
  author_id: string
  content: string
  category: BoardCategory
  color: BoardColor
  image_url: string | null
  contact_info: string | null
  expires_at: string | null
  pinned: boolean
  pin_count: number
  comment_count: number
  latitude: number | null
  longitude: number | null
  region_id: string | null
  status: BoardStatus
  created_at: string
  updated_at: string
  // Joined
  profiles?: {
    name: string | null
    display_name: string | null
    avatar_url: string | null
    trust_score: number | null
  }
}

export interface BoardPin {
  id: string
  user_id: string
  board_post_id: string
  created_at: string
}

export interface BoardComment {
  id: string
  board_post_id: string
  author_id: string
  content: string
  created_at: string
  updated_at: string
  profiles?: {
    name: string | null
    display_name: string | null
    avatar_url: string | null
  }
}

export interface CreateBoardPostInput {
  content: string
  category: BoardCategory
  color: BoardColor
  image_url?: string | null
  contact_info?: string | null
  expires_at?: string | null
}

const PAGE_SIZE = 20

// ── Category helpers ─────────────────────────────────────────────────
export const CATEGORY_LABELS: Record<BoardCategory, string> = {
  general: 'Allgemein',
  gesucht: 'Gesucht',
  biete: 'Biete',
  event: 'Veranstaltung',
  info: 'Info',
  warnung: 'Warnung',
  verloren: 'Verloren',
  fundbuero: 'Fundbüro',
}

export const CATEGORY_ICONS: Record<BoardCategory, string> = {
  general: '📌',
  gesucht: '🔍',
  biete: '🎁',
  event: '📅',
  info: 'ℹ️',
  warnung: '⚠️',
  verloren: '😢',
  fundbuero: '🔑',
}

export const COLOR_MAP: Record<BoardColor, { bg: string; border: string; text: string; badge: string }> = {
  yellow: { bg: 'bg-yellow-50', border: 'border-yellow-300', text: 'text-yellow-900', badge: 'bg-yellow-200 text-yellow-800' },
  green: { bg: 'bg-green-50', border: 'border-green-300', text: 'text-green-900', badge: 'bg-green-200 text-green-800' },
  blue: { bg: 'bg-blue-50', border: 'border-blue-300', text: 'text-blue-900', badge: 'bg-blue-200 text-blue-800' },
  pink: { bg: 'bg-pink-50', border: 'border-pink-300', text: 'text-pink-900', badge: 'bg-pink-200 text-pink-800' },
  orange: { bg: 'bg-orange-50', border: 'border-orange-300', text: 'text-orange-900', badge: 'bg-orange-200 text-orange-800' },
  purple: { bg: 'bg-purple-50', border: 'border-purple-300', text: 'text-purple-900', badge: 'bg-purple-200 text-purple-800' },
}

// ── Hook ─────────────────────────────────────────────────────────────
export function useBoard(userId: string | undefined) {
  const supabase = createClient()
  const [posts, setPosts] = useState<BoardPost[]>([])
  const [loading, setLoading] = useState(true)
  const [hasMore, setHasMore] = useState(true)
  const [page, setPage] = useState(0)
  const [category, setCategory] = useState<BoardCategory | 'all'>('all')
  const [search, setSearch] = useState('')
  const [myPins, setMyPins] = useState<Set<string>>(new Set())
  const [newPostIds, setNewPostIds] = useState<Set<string>>(new Set())
  const [refreshing, setRefreshing] = useState(false)
  const [comments, setComments] = useState<BoardComment[]>([])
  const [commentsLoading, setCommentsLoading] = useState(false)
  const channelRef = useRef<ReturnType<typeof supabase.channel> | null>(null)

  // ── Fetch posts ──
  const fetchPosts = useCallback(
    async (pageNum: number = 0, append: boolean = false) => {
      setLoading(true)
      try {
        let typed: BoardPost[] = []
        const useRpc = search.trim()

        if (useRpc) {
          // Use search_board_posts RPC for server-side full-text search
          const { data: rpcData, error: rpcError } = await supabase.rpc('search_board_posts', {
            p_query: search.trim(),
            p_category: category !== 'all' ? category : null,
            p_limit: PAGE_SIZE,
            p_offset: pageNum * PAGE_SIZE,
          } as any)

          if (!rpcError && rpcData) {
            typed = (rpcData as any[]) as unknown as BoardPost[]
          } else {
            // Fallback to direct query
            typed = await fetchBoardFallback(pageNum)
          }
        } else {
          typed = await fetchBoardFallback(pageNum)
        }

        if (append) {
          setPosts((prev) => [...prev, ...typed])
        } else {
          setPosts(typed)
        }
        setHasMore(typed.length >= PAGE_SIZE)
      } catch (err) {
        console.error('fetchPosts error:', err)
      } finally {
        setLoading(false)
      }
    },
    [supabase, category, search],
  )

  // Fallback direct query (no RPC needed)
  const fetchBoardFallback = useCallback(async (pageNum: number) => {
    let query = supabase
      .from('board_posts')
      .select('*, profiles!board_posts_author_id_fkey(name, display_name, avatar_url, trust_score)')
      .eq('status', 'active')
      .order('pinned', { ascending: false })
      .order('created_at', { ascending: false })
      .range(pageNum * PAGE_SIZE, (pageNum + 1) * PAGE_SIZE - 1)

    if (category !== 'all') {
      query = query.eq('category', category)
    }

    const { data, error } = await query
    if (error) throw error
    return (data ?? []) as unknown as BoardPost[]
  }, [supabase, category])

  // ── Load my pins ──
  const loadMyPins = useCallback(async () => {
    if (!userId) return
    const { data } = await supabase
      .from('board_pins')
      .select('board_post_id')
      .eq('user_id', userId)
    if (data) {
      setMyPins(new Set(data.map((p) => p.board_post_id)))
    }
  }, [supabase, userId])

  // ── Initial load ──
  useEffect(() => {
    setPage(0)
    fetchPosts(0, false)
    loadMyPins()
  }, [fetchPosts, loadMyPins])

  // ── Load more (infinite scroll) ──
  const loadMore = useCallback(() => {
    if (loading || !hasMore) return
    const next = page + 1
    setPage(next)
    fetchPosts(next, true)
  }, [loading, hasMore, page, fetchPosts])

  // ── Refresh ──
  const refresh = useCallback(async () => {
    setRefreshing(true)
    setPage(0)
    await fetchPosts(0, false)
    await loadMyPins()
    setRefreshing(false)
  }, [fetchPosts, loadMyPins])

  // ── Create post ──
  const createPost = useCallback(
    async (input: CreateBoardPostInput) => {
      if (!userId) throw new Error('Nicht angemeldet')
      const allowed = await checkRateLimit(userId, 'create_board_post', 15, 60)
      if (!allowed) throw new Error('Zu viele Beitraege in kurzer Zeit. Bitte warte etwas.')
      const { data, error } = await supabase
        .from('board_posts')
        .insert({
          author_id: userId,
          content: input.content,
          category: input.category,
          color: input.color,
          image_url: input.image_url ?? null,
          contact_info: input.contact_info ?? null,
          expires_at: input.expires_at ?? null,
        })
        .select('*, profiles!board_posts_author_id_fkey(name, display_name, avatar_url, trust_score)')
        .single()
      if (error) throw error
      setPosts((prev) => [data as unknown as BoardPost, ...prev])
      return data
    },
    [supabase, userId],
  )

  // ── Update post ──
  const updatePost = useCallback(
    async (postId: string, updates: Partial<CreateBoardPostInput>) => {
      const { error } = await supabase
        .from('board_posts')
        .update(updates)
        .eq('id', postId)
      if (error) throw error
      setPosts((prev) =>
        prev.map((p) => (p.id === postId ? { ...p, ...updates, updated_at: new Date().toISOString() } : p)),
      )
    },
    [supabase],
  )

  // ── Delete post ──
  const deletePost = useCallback(
    async (postId: string) => {
      const { error } = await supabase
        .from('board_posts')
        .update({ status: 'deleted' })
        .eq('id', postId)
      if (error) throw error
      setPosts((prev) => prev.filter((p) => p.id !== postId))
    },
    [supabase],
  )

  // ── Toggle pin ──
  const togglePin = useCallback(
    async (postId: string) => {
      if (!userId) return
      const isPinned = myPins.has(postId)
      if (isPinned) {
        await supabase.from('board_pins').delete().eq('user_id', userId).eq('board_post_id', postId)
        setMyPins((prev) => {
          const next = new Set(prev)
          next.delete(postId)
          return next
        })
        setPosts((prev) =>
          prev.map((p) => (p.id === postId ? { ...p, pin_count: Math.max(0, p.pin_count - 1) } : p)),
        )
      } else {
        await supabase.from('board_pins').insert({ user_id: userId, board_post_id: postId })
        setMyPins((prev) => new Set(prev).add(postId))
        setPosts((prev) =>
          prev.map((p) => (p.id === postId ? { ...p, pin_count: p.pin_count + 1 } : p)),
        )
      }
    },
    [supabase, userId, myPins],
  )

  // ── Comments ──
  const loadComments = useCallback(
    async (postId: string) => {
      setCommentsLoading(true)
      const { data, error } = await supabase
        .from('board_comments')
        .select('*, profiles!board_comments_author_id_fkey(name, display_name, avatar_url)')
        .eq('board_post_id', postId)
        .order('created_at', { ascending: true })
      if (!error && data) {
        setComments(data as unknown as BoardComment[])
      }
      setCommentsLoading(false)
    },
    [supabase],
  )

  const addComment = useCallback(
    async (postId: string, content: string) => {
      if (!userId) throw new Error('Nicht angemeldet')
      const { data, error } = await supabase
        .from('board_comments')
        .insert({ board_post_id: postId, author_id: userId, content })
        .select('*, profiles!board_comments_author_id_fkey(name, display_name, avatar_url)')
        .single()
      if (error) throw error
      setComments((prev) => [...prev, data as unknown as BoardComment])
      // Update local count
      setPosts((prev) =>
        prev.map((p) => (p.id === postId ? { ...p, comment_count: p.comment_count + 1 } : p)),
      )
    },
    [supabase, userId],
  )

  const deleteComment = useCallback(
    async (commentId: string, postId: string) => {
      const { error } = await supabase.from('board_comments').delete().eq('id', commentId)
      if (error) throw error
      setComments((prev) => prev.filter((c) => c.id !== commentId))
      setPosts((prev) =>
        prev.map((p) => (p.id === postId ? { ...p, comment_count: Math.max(0, p.comment_count - 1) } : p)),
      )
    },
    [supabase],
  )

  // ── Image upload ──
  const uploadImage = useCallback(
    async (file: File): Promise<string> => {
      if (!userId) throw new Error('Nicht angemeldet')
      const maxSize = 5 * 1024 * 1024
      if (file.size > maxSize) throw new Error('Bild darf max. 5 MB groß sein')
      const allowed = ['image/jpeg', 'image/png', 'image/webp', 'image/gif']
      if (!allowed.includes(file.type)) throw new Error('Nur JPEG, PNG, WebP oder GIF erlaubt')

      const ext = file.name.split('.').pop() || 'jpg'
      const path = `${userId}/${Date.now()}_${Math.random().toString(36).slice(2)}.${ext}`

      const { error } = await supabase.storage.from('board-images').upload(path, file, {
        cacheControl: '3600',
        upsert: false,
      })
      if (error) throw error

      const { data } = supabase.storage.from('board-images').getPublicUrl(path)
      return data.publicUrl
    },
    [supabase, userId],
  )

  // ── Realtime subscriptions ──
  useEffect(() => {
    const channel = supabase
      .channel('board-realtime')
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'board_posts' },
        (payload) => {
          const newPost = payload.new as BoardPost
          if (newPost.author_id !== userId && newPost.status === 'active') {
            setNewPostIds((prev) => new Set(prev).add(newPost.id))
            // Refresh to get joined profile
            fetchPosts(0, false)
          }
        },
      )
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'board_posts' },
        (payload) => {
          const updated = payload.new as BoardPost
          setPosts((prev) =>
            prev.map((p) => (p.id === updated.id ? { ...p, ...updated } : p)).filter(
              (p) => p.status === 'active' || p.author_id === userId,
            ),
          )
        },
      )
      .on(
        'postgres_changes',
        { event: 'DELETE', schema: 'public', table: 'board_posts' },
        (payload) => {
          const deleted = payload.old as { id: string }
          setPosts((prev) => prev.filter((p) => p.id !== deleted.id))
        },
      )
      .subscribe()

    channelRef.current = channel

    return () => {
      channel.unsubscribe()
    }
  }, [supabase, userId, fetchPosts])

  // Clear new-post highlight after 5 seconds
  useEffect(() => {
    if (newPostIds.size === 0) return
    const timer = setTimeout(() => setNewPostIds(new Set()), 5000)
    return () => clearTimeout(timer)
  }, [newPostIds])

  return {
    posts,
    loading,
    hasMore,
    category,
    setCategory,
    search,
    setSearch,
    myPins,
    newPostIds,
    refreshing,
    comments,
    commentsLoading,
    loadMore,
    refresh,
    createPost,
    updatePost,
    deletePost,
    togglePin,
    loadComments,
    addComment,
    deleteComment,
    uploadImage,
  }
}
