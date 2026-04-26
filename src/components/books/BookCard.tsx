'use client'

import { useState } from 'react'
import { BookOpen, User, Calendar, Building2, Hash, Layers } from 'lucide-react'
import { cn } from '@/lib/utils'
import type { BookResult } from '@/lib/api/books'

// Deterministic color from string (for placeholder cover background)
function titleToHsl(title: string): string {
  let hash = 0
  for (let i = 0; i < title.length; i++) {
    hash = title.charCodeAt(i) + ((hash << 5) - hash)
  }
  const h = Math.abs(hash) % 360
  return `hsl(${h}, 35%, 40%)`
}

// ── Cover image (with hash-colored placeholder fallback) ─────────────────────

function BookCover({
  book,
  size,
}: {
  book: BookResult
  size: 'sm' | 'lg'
}) {
  const [imgError, setImgError] = useState(false)
  const color = titleToHsl(book.title)
  const initials = book.title.slice(0, 2).toUpperCase()

  const wrapClass = size === 'sm'
    ? 'w-11 h-16 rounded-lg flex-shrink-0'
    : 'w-28 h-40 sm:w-32 sm:h-44 rounded-xl flex-shrink-0'

  if (!book.coverUrl || imgError) {
    return (
      <div
        className={cn(wrapClass, 'flex flex-col items-center justify-center shadow-sm')}
        style={{ background: `linear-gradient(135deg, ${color}, ${color.replace('40%', '30%')})` }}
      >
        {size === 'sm' ? (
          <BookOpen className="w-4 h-4 text-white/80" />
        ) : (
          <>
            <BookOpen className="w-8 h-8 text-white/70 mb-1" />
            <span className="text-white/60 text-[11px] font-bold tracking-wider">{initials}</span>
          </>
        )}
      </div>
    )
  }

  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img
      src={book.coverUrl}
      alt={`Cover: ${book.title}`}
      className={cn(wrapClass, 'object-cover shadow-sm')}
      onError={() => setImgError(true)}
      loading="lazy"
    />
  )
}

// ── BookCard ─────────────────────────────────────────────────────────────────

interface BookCardProps {
  book: BookResult
  variant: 'compact' | 'full'
  action?: React.ReactNode
  className?: string
}

export default function BookCard({ book, variant, action, className }: BookCardProps) {

  if (variant === 'compact') {
    return (
      <div className={cn(
        'flex items-center gap-3 p-3 rounded-xl bg-white border border-stone-100 transition-colors',
        className,
      )}>
        <BookCover book={book} size="sm" />
        <div className="flex-1 min-w-0">
          <p className="text-sm font-semibold text-ink-900 truncate leading-tight">{book.title}</p>
          <p className="text-xs text-ink-500 truncate mt-0.5">{book.authors.join(', ')}</p>
          {book.publishYear && (
            <p className="text-[11px] text-ink-400 mt-0.5">{book.publishYear}</p>
          )}
        </div>
        {action && <div className="flex-shrink-0 ml-2">{action}</div>}
      </div>
    )
  }

  // ── Full variant ──────────────────────────────────────────────────────────
  return (
    <div className={cn(
      'flex gap-4 p-4 rounded-2xl bg-white border border-stone-100 shadow-sm',
      className,
    )}>
      <BookCover book={book} size="lg" />

      <div className="flex-1 min-w-0">
        <h3 className="text-base font-bold text-ink-900 leading-snug">{book.title}</h3>

        <dl className="mt-2.5 space-y-1.5">
          {book.authors.length > 0 && (
            <div className="flex items-start gap-1.5">
              <User className="w-3.5 h-3.5 text-stone-400 mt-0.5 flex-shrink-0" />
              <dd className="text-sm text-ink-700 leading-snug">{book.authors.join(', ')}</dd>
            </div>
          )}
          {book.publishYear && (
            <div className="flex items-center gap-1.5">
              <Calendar className="w-3.5 h-3.5 text-stone-400 flex-shrink-0" />
              <dd className="text-sm text-ink-600">{book.publishYear}</dd>
            </div>
          )}
          {book.publisher && (
            <div className="flex items-center gap-1.5">
              <Building2 className="w-3.5 h-3.5 text-stone-400 flex-shrink-0" />
              <dd className="text-sm text-ink-600 truncate">{book.publisher}</dd>
            </div>
          )}
          {book.pageCount && (
            <div className="flex items-center gap-1.5">
              <Layers className="w-3.5 h-3.5 text-stone-400 flex-shrink-0" />
              <dd className="text-sm text-ink-600">{book.pageCount} Seiten</dd>
            </div>
          )}
          {book.isbn && (
            <div className="flex items-center gap-1.5">
              <Hash className="w-3.5 h-3.5 text-stone-400 flex-shrink-0" />
              <dd className="text-xs text-ink-400 font-mono">{book.isbn}</dd>
            </div>
          )}
        </dl>

        {book.subjects && book.subjects.length > 0 && (
          <div className="flex flex-wrap gap-1 mt-3">
            {book.subjects.slice(0, 3).map((s) => (
              <span
                key={s}
                className="text-[10px] px-2 py-0.5 rounded-full bg-primary-50 text-primary-700 border border-primary-100 font-medium"
              >
                {s}
              </span>
            ))}
          </div>
        )}

        {action && <div className="mt-3">{action}</div>}
      </div>
    </div>
  )
}
