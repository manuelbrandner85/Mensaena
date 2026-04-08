'use client'

import { useState, useEffect, useCallback, useRef } from 'react'
import { useRouter } from 'next/navigation'
import { Clipboard, Plus, RefreshCw, Inbox } from 'lucide-react'
import { cn } from '@/lib/utils'
import { createClient } from '@/lib/supabase/client'
import showToast from '@/components/ui/Toast'
import { useBoard } from './hooks/useBoard'
import type { BoardPost } from './hooks/useBoard'
import BoardGrid from './components/BoardGrid'
import BoardCreateForm from './components/BoardCreateForm'
import BoardFilters from './components/BoardFilters'
import BoardSearch from './components/BoardSearch'
import BoardCardDetail from './components/BoardCardDetail'
import BoardSkeleton from './components/BoardSkeleton'

export default function BoardPage() {
  const router = useRouter()
  const supabase = createClient()
  const [userId, setUserId] = useState<string | undefined>()
  const [authLoading, setAuthLoading] = useState(true)
  const [showCreate, setShowCreate] = useState(false)
  const [detailPost, setDetailPost] = useState<BoardPost | null>(null)
  const [editingPost, setEditingPost] = useState<BoardPost | null>(null)
  const touchStartY = useRef(0)
  const containerRef = useRef<HTMLDivElement>(null)

  // Auth guard
  useEffect(() => {
    const check = async () => {
      const { data: { session } } = await supabase.auth.getSession()
      if (!session?.user) {
        router.push('/auth')
        return
      }
      setUserId(session.user.id)
      setAuthLoading(false)
    }
    check()
  }, [supabase, router])

  const board = useBoard(userId)

  // Pull-to-refresh (mobile)
  const handleTouchStart = useCallback((e: React.TouchEvent) => {
    touchStartY.current = e.touches[0].clientY
  }, [])

  const handleTouchEnd = useCallback(
    (e: React.TouchEvent) => {
      const pullDistance = e.changedTouches[0].clientY - touchStartY.current
      const scrollTop = containerRef.current?.scrollTop ?? 0
      if (pullDistance > 80 && scrollTop <= 0) {
        board.refresh()
      }
    },
    [board],
  )

  const handleDelete = useCallback(
    async (postId: string) => {
      if (!confirm('Diesen Aushang wirklich löschen?')) return
      try {
        await board.deletePost(postId)
        showToast('Aushang gelöscht', 'success')
        if (detailPost?.id === postId) setDetailPost(null)
      } catch {
        showToast('Löschen fehlgeschlagen', 'error')
      }
    },
    [board, detailPost],
  )

  const handleEdit = useCallback(
    (post: BoardPost) => {
      setDetailPost(null)
      setShowCreate(false)
      setEditingPost(post)
    },
    [],
  )

  const handleEditSubmit = useCallback(
    async (input: Parameters<typeof board.updatePost>[1]) => {
      if (!editingPost) return
      await board.updatePost(editingPost.id, input)
      setEditingPost(null)
    },
    [board, editingPost],
  )

  if (authLoading) {
    return (
      <div className="max-w-4xl mx-auto px-4 py-6">
        <BoardSkeleton />
      </div>
    )
  }

  return (
    <div
      ref={containerRef}
      className="max-w-4xl mx-auto px-4 py-6 min-h-screen"
      onTouchStart={handleTouchStart}
      onTouchEnd={handleTouchEnd}
    >
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <div className="p-2 rounded-xl bg-emerald-100">
            <Clipboard className="w-6 h-6 text-emerald-700" />
          </div>
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Pinnwand</h1>
            <p className="text-sm text-gray-500">Aushänge deiner Gemeinschaft</p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={() => board.refresh()}
            disabled={board.refreshing}
            className="p-2 rounded-lg text-gray-500 hover:bg-gray-100 transition"
            title="Aktualisieren"
          >
            <RefreshCw className={cn('w-5 h-5', board.refreshing && 'animate-spin')} />
          </button>
          <button
            onClick={() => { setEditingPost(null); setShowCreate(!showCreate) }}
            className={cn(
              'inline-flex items-center gap-2 px-4 py-2 rounded-lg font-medium text-sm transition',
              (showCreate || editingPost)
                ? 'bg-gray-200 text-gray-700'
                : 'bg-emerald-600 text-white hover:bg-emerald-700 shadow-sm',
            )}
          >
            <Plus className="w-4 h-4" />
            Neuer Aushang
          </button>
        </div>
      </div>

      {/* Create / Edit form */}
      {(showCreate || editingPost) && (
        <div className="mb-6">
          <BoardCreateForm
            onSubmit={editingPost ? handleEditSubmit : board.createPost}
            onUploadImage={board.uploadImage}
            onClose={() => { setShowCreate(false); setEditingPost(null) }}
            editMode={!!editingPost}
            initialData={editingPost ? {
              content: editingPost.content,
              category: editingPost.category,
              color: editingPost.color,
              contact_info: editingPost.contact_info,
              image_url: editingPost.image_url,
            } : undefined}
          />
        </div>
      )}

      {/* Filters + Search */}
      <div className="space-y-3 mb-6">
        <BoardFilters value={board.category} onChange={board.setCategory} />
        <BoardSearch value={board.search} onChange={board.setSearch} />
      </div>

      {/* Pull-to-refresh indicator */}
      {board.refreshing && (
        <div className="flex items-center justify-center py-3 mb-4">
          <RefreshCw className="w-4 h-4 animate-spin text-emerald-600 mr-2" />
          <span className="text-sm text-gray-500">Aktualisiere...</span>
        </div>
      )}

      {/* Content */}
      {board.loading && board.posts.length === 0 ? (
        <BoardSkeleton />
      ) : board.posts.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-16 text-center">
          <div className="p-4 rounded-full bg-gray-100 mb-4">
            <Inbox className="w-10 h-10 text-gray-400" />
          </div>
          <h3 className="text-lg font-semibold text-gray-700 mb-1">Noch keine Aushänge</h3>
          <p className="text-sm text-gray-500 mb-4">
            Erstelle den ersten Aushang für deine Gemeinschaft!
          </p>
          <button
            onClick={() => setShowCreate(true)}
            className="inline-flex items-center gap-2 px-4 py-2 rounded-lg bg-emerald-600 text-white
                       font-medium text-sm hover:bg-emerald-700 transition"
          >
            <Plus className="w-4 h-4" />
            Neuer Aushang
          </button>
        </div>
      ) : (
        <BoardGrid
          posts={board.posts}
          userId={userId}
          myPins={board.myPins}
          newPostIds={board.newPostIds}
          hasMore={board.hasMore}
          loading={board.loading}
          onTogglePin={board.togglePin}
          onOpenDetail={setDetailPost}
          onEdit={handleEdit}
          onDelete={handleDelete}
          onLoadMore={board.loadMore}
        />
      )}

      {/* Detail modal */}
      {detailPost && (
        <BoardCardDetail
          post={detailPost}
          userId={userId}
          isPinned={board.myPins.has(detailPost.id)}
          comments={board.comments}
          commentsLoading={board.commentsLoading}
          onClose={() => setDetailPost(null)}
          onTogglePin={board.togglePin}
          onAddComment={board.addComment}
          onDeleteComment={board.deleteComment}
          onLoadComments={board.loadComments}
        />
      )}
    </div>
  )
}
