'use client'

import { useRef, useEffect, useCallback } from 'react'
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

  // Infinite scroll with IntersectionObserver
  const handleIntersection = useCallback(
    (entries: IntersectionObserverEntry[]) => {
      if (entries[0]?.isIntersecting && hasMore && !loading) {
        onLoadMore()
      }
    },
    [hasMore, loading, onLoadMore],
  )

  useEffect(() => {
    const el = sentinelRef.current
    if (!el) return
    const observer = new IntersectionObserver(handleIntersection, { rootMargin: '200px' })
    observer.observe(el)
    return () => observer.disconnect()
  }, [handleIntersection])

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
          <Loader2 className="w-5 h-5 animate-spin text-emerald-600" />
          <span className="ml-2 text-sm text-gray-500">Laden...</span>
        </div>
      )}
    </>
  )
}
