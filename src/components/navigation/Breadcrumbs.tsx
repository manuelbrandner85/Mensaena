'use client'

import Link from 'next/link'
import { ChevronRight, Home } from 'lucide-react'
import { useNavigation } from '@/hooks/useNavigation'

export default function Breadcrumbs() {
  const { breadcrumbs } = useNavigation()

  if (breadcrumbs.length <= 1) return null

  return (
    <nav
      className="flex items-center gap-1 text-sm text-mn-mute px-8 py-2 bg-mn-elevated/60 border-b border-white/8"
      aria-label="Breadcrumb"
    >
      {breadcrumbs.map((crumb, i) => {
        const isLast = i === breadcrumbs.length - 1
        const isFirst = i === 0

        return (
          <span key={crumb.href} className="flex items-center gap-1">
            {i > 0 && <ChevronRight className="w-3 h-3 text-mn-ghost flex-shrink-0" />}
            {isLast ? (
              <span className="text-mn-ink font-medium truncate max-w-[200px]" aria-current="page">
                {crumb.label}
              </span>
            ) : (
              <Link
                href={crumb.href}
                className="flex items-center gap-1 text-mn-mute hover:text-mn-bronze transition-colors truncate max-w-[150px]"
              >
                {isFirst && <Home className="w-3 h-3 flex-shrink-0" />}
                {crumb.label}
              </Link>
            )}
          </span>
        )
      })}
    </nav>
  )
}
