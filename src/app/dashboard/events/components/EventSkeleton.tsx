'use client'

import { cn } from '@/lib/utils'

function Bone({ className }: { className?: string }) {
  return <div className={cn('bg-stone-200 rounded-lg animate-pulse', className)} />
}

function CardSkeleton() {
  return (
    <div className="bg-white rounded-xl border border-stone-200 p-4 flex flex-col sm:flex-row gap-4">
      <Bone className="w-14 h-14 sm:w-16 sm:h-16 rounded-xl flex-shrink-0" />
      <div className="flex-1 min-w-0 space-y-2">
        <Bone className="h-4 w-20" />
        <Bone className="h-5 w-3/4" />
        <Bone className="h-3.5 w-1/2" />
        <Bone className="h-3.5 w-2/5" />
        <div className="flex items-center gap-3 pt-1">
          <Bone className="w-5 h-5 rounded-full" />
          <Bone className="h-3 w-24" />
          <Bone className="h-3 w-16" />
        </div>
      </div>
      <Bone className="w-24 h-8 rounded-lg flex-shrink-0 self-start" />
    </div>
  )
}

export function ListSkeleton() {
  return (
    <div className="space-y-3">
      <Bone className="h-4 w-20 mb-2" />
      {Array.from({ length: 6 }).map((_, i) => (
        <CardSkeleton key={i} />
      ))}
    </div>
  )
}

export function CalendarSkeleton() {
  return (
    <div>
      <div className="flex items-center justify-between mb-4">
        <Bone className="w-8 h-8 rounded-lg" />
        <Bone className="h-6 w-40" />
        <Bone className="w-8 h-8 rounded-lg" />
      </div>
      <div className="grid grid-cols-7 gap-px mb-1">
        {Array.from({ length: 7 }).map((_, i) => (
          <Bone key={i} className="h-4 mx-2" />
        ))}
      </div>
      <div className="grid grid-cols-7 gap-px bg-stone-100 rounded-xl overflow-hidden">
        {Array.from({ length: 35 }).map((_, i) => (
          <div key={i} className="bg-white min-h-[80px] md:min-h-[100px] p-1">
            <Bone className="w-6 h-5 mb-1" />
            {i % 5 === 0 && <Bone className="h-1.5 w-full rounded-full mb-0.5" />}
            {i % 3 === 0 && <Bone className="h-1.5 w-3/4 rounded-full" />}
          </div>
        ))}
      </div>
    </div>
  )
}

export function MapSkeleton() {
  return (
    <div className="relative rounded-xl overflow-hidden bg-stone-100" style={{ height: 'calc(100vh - 280px)', minHeight: 400 }}>
      <div className="absolute inset-0 flex items-center justify-center">
        <div className="text-center">
          <div className="w-10 h-10 border-4 border-purple-400 border-t-transparent rounded-full animate-spin mx-auto mb-3" />
          <p className="text-sm text-ink-500">Karte wird geladen...</p>
        </div>
      </div>
    </div>
  )
}

export default function EventSkeleton({ variant = 'list' }: { variant?: 'list' | 'calendar' | 'map' }) {
  if (variant === 'calendar') return <CalendarSkeleton />
  if (variant === 'map') return <MapSkeleton />
  return <ListSkeleton />
}
