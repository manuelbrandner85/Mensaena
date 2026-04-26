'use client'

import { Skeleton } from '@/components/ui'

export default function DashboardSkeleton() {
  return (
    <div className="max-w-7xl mx-auto" role="status" aria-label="Dashboard wird geladen...">
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4 md:gap-6">
        {/* Left column */}
        <div className="lg:col-span-2 flex flex-col gap-4 md:gap-6">
          {/* WelcomeHeader skeleton */}
          <div>
            <Skeleton height="2rem" width="16rem" className="mb-2" />
            <Skeleton height="1rem" width="10rem" />
          </div>

          {/* QuickActions skeleton */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            {[...Array(4)].map((_, i) => (
              <div key={i} className="bg-white rounded-xl border border-stone-100 p-4 flex flex-col items-center gap-2">
                <Skeleton variant="rect" height="2.5rem" width="2.5rem" className="rounded-lg" />
                <Skeleton height="1rem" width="4rem" />
              </div>
            ))}
          </div>

          {/* NearbyPosts skeleton */}
          <div>
            <div className="flex items-center justify-between mb-3">
              <Skeleton height="1.5rem" width="8rem" />
              <Skeleton height="1rem" width="6rem" />
            </div>
            <div className="flex gap-4 overflow-hidden">
              {[...Array(3)].map((_, i) => (
                <div key={i} className="min-w-[280px] bg-white rounded-xl border border-stone-100 p-4">
                  <div className="flex gap-2 mb-2">
                    <Skeleton height="1.25rem" width="4rem" className="rounded-full" />
                    <Skeleton height="1rem" width="3rem" />
                  </div>
                  <Skeleton height="1.25rem" className="mb-2" />
                  <Skeleton height="1rem" width="75%" className="mb-3" />
                  <div className="flex items-center gap-2 pt-3 border-t border-stone-100">
                    <Skeleton variant="round" height="1.5rem" width="1.5rem" />
                    <Skeleton height="0.75rem" width="5rem" />
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* ActivityFeed skeleton */}
          <div className="bg-white rounded-xl border border-stone-100">
            <div className="p-4 border-b border-stone-100">
              <Skeleton height="1.5rem" width="9rem" />
            </div>
            {[...Array(5)].map((_, i) => (
              <div key={i} className="flex gap-3 p-4">
                <Skeleton variant="round" height="2.5rem" width="2.5rem" className="flex-shrink-0" />
                <div className="flex-1">
                  <Skeleton height="1rem" width="12rem" className="mb-1.5" />
                  <Skeleton height="0.75rem" width="8rem" />
                </div>
                <Skeleton height="0.75rem" width="3rem" className="flex-shrink-0" />
              </div>
            ))}
          </div>
        </div>

        {/* Right column */}
        <div className="lg:col-span-1 flex flex-col gap-4 md:gap-6">
          {/* OnboardingChecklist skeleton */}
          <div className="bg-white rounded-xl border border-stone-100 p-4">
            <Skeleton height="1.25rem" width="12rem" className="mb-2" />
            <Skeleton height="0.5rem" className="rounded-full mb-3" />
            {[...Array(4)].map((_, i) => (
              <div key={i} className="flex items-center gap-2.5 mb-2">
                <Skeleton variant="round" height="1.125rem" width="1.125rem" />
                <Skeleton height="1rem" width="8rem" />
              </div>
            ))}
          </div>

          {/* StatsCards skeleton */}
          <div className="grid grid-cols-2 gap-3">
            {[...Array(4)].map((_, i) => (
              <div key={i} className="bg-white rounded-xl border border-stone-100 p-4">
                <Skeleton height="2rem" width="2rem" className="rounded-lg mb-2" />
                <Skeleton height="1.75rem" width="3rem" className="mb-1" />
                <Skeleton height="0.75rem" width="5rem" />
              </div>
            ))}
          </div>

          {/* TrustScore skeleton */}
          <div className="bg-white rounded-xl border border-stone-100 p-4">
            <Skeleton height="1.25rem" width="8rem" className="mb-3" />
            <Skeleton height="2rem" width="4rem" className="mb-1" />
            <Skeleton height="1rem" width="6rem" />
          </div>

          {/* UnreadMessages skeleton */}
          <div className="bg-white rounded-xl border border-stone-100">
            <div className="p-4">
              <Skeleton height="1.25rem" width="11rem" />
            </div>
            {[...Array(3)].map((_, i) => (
              <div key={i} className="flex items-center gap-3 p-3">
                <Skeleton variant="round" height="2.25rem" width="2.25rem" className="flex-shrink-0" />
                <div className="flex-1">
                  <Skeleton height="1rem" width="7rem" className="mb-1" />
                  <Skeleton height="0.75rem" />
                </div>
              </div>
            ))}
          </div>

          {/* MiniMap skeleton */}
          <Skeleton height="200px" className="rounded-xl" />

          {/* CommunityPulse skeleton */}
          <div className="bg-white rounded-xl border border-stone-100 p-4">
            <Skeleton height="1.25rem" width="10rem" className="mb-3" />
            {[...Array(3)].map((_, i) => (
              <div key={i} className="flex justify-between py-2">
                <Skeleton height="1rem" width="7rem" />
                <Skeleton height="1rem" width="2rem" />
              </div>
            ))}
          </div>
        </div>
      </div>
      <span className="sr-only">Dashboard wird geladen...</span>
    </div>
  )
}
