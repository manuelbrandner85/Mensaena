'use client'

import { useRef, useEffect } from 'react'
import { Loader2 } from 'lucide-react'
import BoardCard from './BoardCard'
import type { BoardPost } from '../hooks/useBoard'

interface BoardGridProps {
  posts: BoardPost[]
  userId?: string
  myPins: Set<string>
  newPostIds: Set<string>
  hasMore: boolean
  loading: boolean
  onTogglePin: (postId: string) => void
  onOpenDetail: (post: BoardPost) => void
  onEdit: (post: BoardPost) => void
  onDelete: (postId: string) => void
  onLoadMore: () => void
}

export default function BoardGrid({
  posts,
  userId,
  myPins,
  newPostIds,
  hasMore,
  loading,
  onTogglePin,
  onOpenDetail,
  onEdit,
  onDelete,
  onLoadMore,
}: BoardGridProps) {
  const sentinelRef = useRef<HTMLDivElement>(null)
  // Use refs for hasMore/loading/onLoadMore so the observer is only created once
  const hasMoreRef = useRef(hasMore)
  const loadingRef = useRef(loading)
  const onLoadMoreRef = useRef(onLoadMore)

  useEffect(() => { hasMoreRef.current = hasMore }, [hasMore])
  useEffect(() => { loadingRef.current = loading }, [loading])
  useEffect(() => { onLoadMoreRef.current = onLoadMore }, [onLoadMore])

  useEffect(() => {
    const el = sentinelRef.current
    if (!el) return
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0]?.isIntersecting && hasMoreRef.current && !loadingRef.current) {
          onLoadMoreRef.current()
        }
      },
      { rootMargin: '200px' },
    )
    observer.observe(el)
    return () => observer.disconnect()
    // Observer is created once and uses refs to avoid stale closures
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  return (
    <>
      <div className="columns-1 sm:columns-2 lg:columns-3 gap-4 space-y-4">
        {posts.map((post) => (
          <BoardCard
            key={post.id}
            post={post}
            userId={userId}
            isPinned={myPins.has(post.id)}
            isNew={newPostIds.has(post.id)}
            onTogglePin={onTogglePin}
            onOpenDetail={onOpenDetail}
            onEdit={onEdit}
            onDelete={onDelete}
          />
        ))}
      </div>

      {/* Sentinel for infinite scroll */}
      <div ref={sentinelRef} className="h-4" />

      {/* Loading spinner */}
      {loading && posts.length > 0 && (
        <div className="flex items-center justify-center py-6">
          <Loader2 className="w-5 h-5 animate-spin text-primary-600" />
          <span className="ml-2 text-sm text-ink-500">Laden...</span>
        </div>
      )}
    </>
  )
}
