'use client'

import { useEffect, useState, useCallback } from 'react'
import dynamic from 'next/dynamic'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { cn } from '@/lib/design-system'
import { Button, ErrorState } from '@/components/ui'
import { PullToRefresh, ScrollToTop } from '@/components/mobile'

import { useDashboard } from './hooks/useDashboard'
import DashboardSkeleton from './components/DashboardSkeleton'
import DashboardHeroCard from './components/DashboardHeroCard'
import QuickActions from './components/QuickActions'
import NearbyPosts from './components/NearbyPosts'
import SmartMatchWidget from '@/components/dashboard/SmartMatchWidget'
import ActivityFeed from './components/ActivityFeed'
import StatsCards from './components/StatsCards'
import UnreadMessages from './components/UnreadMessages'
import BotTipCard from './components/BotTipCard'
import TrustScoreCard from './components/TrustScoreCard'
import CommunityPulse from './components/CommunityPulse'
import OnboardingChecklist from './components/OnboardingChecklist'
import RatingPromptBanner from '@/app/ratings/components/RatingPromptBanner'
import NinaWarningBanner from '@/components/dashboard/NinaWarningBanner'
import WeeklyChallengeHighlight from '@/components/features/WeeklyChallengeHighlight'

// Lazy-load heavy / interaction-only components to keep the dashboard
// First Load JS small. MiniMap pulls Leaflet; RatingModal is only shown
// when there is a pending rating to collect.
const MiniMap = dynamic(() => import('./components/MiniMap'), {
  ssr: false,
  loading: () => (
    <div className="h-64 rounded-2xl bg-stone-100 animate-pulse" />
  ),
})
const RatingModal = dynamic(
  () => import('@/app/ratings/components/RatingModal'),
  { ssr: false },
)

export default function DashboardPage() {
  const router = useRouter()
  const [userId, setUserId] = useState<string | undefined>()
  const [authLoading, setAuthLoading] = useState(true)
  const { dashboardData, loading, error, refresh } = useDashboard(userId)
  const [refreshing, setRefreshing] = useState(false)

  // ── Auth guard ──
  useEffect(() => {
    const supabase = createClient()
    supabase.auth.getUser().then(({ data: { user } }) => {
      if (!user) {
        router.replace('/auth')
        return
      }
      setUserId(user.id)
      setAuthLoading(false)
    })
  }, [router])

  // ── Refresh handler ──
  const handleRefresh = useCallback(async () => {
    setRefreshing(true)
    await refresh()
    setRefreshing(false)
  }, [refresh])

  // ── Loading states ──
  if (authLoading || (loading && !dashboardData)) {
    return <DashboardSkeleton />
  }

  // ── Error state ──
  if (error && !dashboardData) {
    return <ErrorState message={error} onRetry={handleRefresh} />
  }

  if (!dashboardData) return null

  const {
    profile,
    nearbyPosts,
    recentActivity,
    stats,
    unreadMessages,
    communityPulse,
    onboardingProgress,
    botTip,
    trustScore,
  } = dashboardData

  const totalUnread = unreadMessages.reduce((s, m) => s + m.unreadCount, 0)

  return (
    <PullToRefresh onRefresh={handleRefresh}>
      <div className="max-w-7xl mx-auto">
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-3 md:gap-6">
          {/* ══════════════════════════════════════════════════════════
           *  LEFT COLUMN (2/3)
           * ══════════════════════════════════════════════════════════ */}
          <div className="lg:col-span-2 flex flex-col gap-3 md:gap-6">
            <DashboardHeroCard
              profile={profile}
              memberSinceDays={stats.memberSinceDays}
            />

            {/* Rating prompt banner */}
            {userId && <RatingPromptBanner userId={userId} />}

            <NinaWarningBanner />

            {/* QuickActions: 2x2 grid on mobile, 4-col on md+ */}
            <QuickActions unreadCount={totalUnread} />

            {/* Smart-Matching: passende Beiträge für den User */}
            <SmartMatchWidget />

            {/* Onboarding – mobile only */}
            {!onboardingProgress.completed && (
              <div className="lg:hidden">
                <OnboardingChecklist progress={onboardingProgress} />
              </div>
            )}

            <WeeklyChallengeHighlight />

            <NearbyPosts
              posts={nearbyPosts}
              userHasLocation={!!(profile?.latitude && profile?.longitude)}
            />

            {/* UnreadMessages – mobile only */}
            <div className="lg:hidden">
              <UnreadMessages messages={unreadMessages} />
            </div>

            {/* StatsCards – mobile only */}
            <div className="lg:hidden">
              <StatsCards stats={stats} />
            </div>

            <ActivityFeed
              activities={recentActivity}
              onRefresh={handleRefresh}
              refreshing={refreshing}
            />

            {/* MiniMap – mobile only */}
            <div className="lg:hidden">
              <MiniMap
                posts={nearbyPosts}
                userLat={profile?.latitude ?? null}
                userLng={profile?.longitude ?? null}
              />
            </div>

            {/* TrustScore – mobile only */}
            <div className="lg:hidden">
              <TrustScoreCard trustScore={trustScore} />
            </div>

            {/* CommunityPulse – mobile only */}
            <div className="lg:hidden">
              <CommunityPulse pulse={communityPulse} />
            </div>

            {/* BotTip – mobile only */}
            <div className="lg:hidden pb-4 md:pb-0">
              <BotTipCard tipText={botTip} />
            </div>
          </div>

          {/* ══════════════════════════════════════════════════════════
           *  RIGHT COLUMN (1/3) – Desktop only
           * ══════════════════════════════════════════════════════════ */}
          <div className="hidden lg:flex lg:col-span-1 flex-col gap-4 md:gap-6">
            {!onboardingProgress.completed && (
              <OnboardingChecklist progress={onboardingProgress} />
            )}

            <StatsCards stats={stats} />
            <TrustScoreCard trustScore={trustScore} />
            <UnreadMessages messages={unreadMessages} />

            <MiniMap
              posts={nearbyPosts}
              userLat={profile?.latitude ?? null}
              userLng={profile?.longitude ?? null}
            />

            <CommunityPulse pulse={communityPulse} />
            <BotTipCard tipText={botTip} />
          </div>
        </div>
      </div>

      {/* Scroll to top FAB */}
      <ScrollToTop />

      {/* Rating Modal (global) */}
      {userId && <RatingModal currentUserId={userId} />}
    </PullToRefresh>
  )
}
