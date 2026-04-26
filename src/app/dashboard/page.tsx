'use client'

import { useEffect, useState, useCallback } from 'react'
import dynamic from 'next/dynamic'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { cn } from '@/lib/design-system'
import { Button, ErrorState } from '@/components/ui'
import { PullToRefresh } from '@/components/mobile'

import { useDashboard } from './hooks/useDashboard'
import { useDashboardWidgetStore } from '@/stores/dashboardWidgetStore'
import DashboardSkeleton from './components/DashboardSkeleton'
import DashboardHeroCard from './components/DashboardHeroCard'
import QuickActions from './components/QuickActions'
import NearbyPosts from './components/NearbyPosts'
import RatingPromptBanner from '@/app/ratings/components/RatingPromptBanner'
import NinaWarningBanner from '@/components/dashboard/NinaWarningBanner'
import FoodWarningBanner from '@/components/warnings/FoodWarningBanner'

// ── Lazy-loaded components ─────────────────────────────────────────────────────
const skeleton = <div className="rounded-2xl bg-stone-100 animate-pulse h-40" />

const WeeklyDigest             = dynamic(() => import('./components/WeeklyDigest'),                      { ssr: false, loading: () => null })
const SmartMatchWidget         = dynamic(() => import('@/components/dashboard/SmartMatchWidget'),         { loading: () => skeleton })
const WeeklyChallengeHighlight = dynamic(() => import('@/components/features/WeeklyChallengeHighlight'), { loading: () => skeleton })
const ActivityFeed             = dynamic(() => import('./components/ActivityFeed'),                      { loading: () => skeleton })
const OnboardingChecklist      = dynamic(() => import('./components/OnboardingChecklist'),               { loading: () => skeleton })
const StatsCards               = dynamic(() => import('./components/StatsCards'),                        { loading: () => skeleton })
const UnreadMessages           = dynamic(() => import('./components/UnreadMessages'),                    { loading: () => skeleton })
const BotTipCard               = dynamic(() => import('./components/BotTipCard'),                        { loading: () => null })
const TrustScoreCard           = dynamic(() => import('./components/TrustScoreCard'),                    { loading: () => skeleton })
const ThanksReceived           = dynamic(() => import('./components/ThanksReceived'),                    { loading: () => null })
const SuccessStoryCard         = dynamic(() => import('./components/SuccessStoryCard'),                  { loading: () => null })
const CommunityPulse           = dynamic(() => import('./components/CommunityPulse'),                    { loading: () => skeleton })
const MiniMap = dynamic(() => import('./components/MiniMap'), {
  ssr: false,
  loading: () => <div className="h-64 rounded-2xl bg-stone-100 animate-pulse" />,
})
const RatingModal = dynamic(
  () => import('@/app/ratings/components/RatingModal'),
  { ssr: false },
)
const WidgetGrid = dynamic(
  () => import('@/components/dashboard/WidgetGrid'),
  { ssr: false, loading: () => skeleton },
)
const WidgetSettingsModal = dynamic(
  () => import('@/components/dashboard/WidgetSettingsModal'),
  { ssr: false },
)

export default function DashboardPage() {
  const router = useRouter()
  const [userId, setUserId] = useState<string | undefined>()
  const [authLoading, setAuthLoading] = useState(true)
  const { dashboardData, loading, error, refresh } = useDashboard(userId)
  const [refreshing, setRefreshing] = useState(false)
  const { settingsOpen: widgetSettingsOpen, openSettings, closeSettings } = useDashboardWidgetStore()

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

  const gridProfile = profile
    ? { latitude: profile.latitude, longitude: profile.longitude }
    : null

  return (
    <PullToRefresh onRefresh={handleRefresh}>
      <div className="max-w-7xl mx-auto space-y-3 md:space-y-6">

        {/* ══════════════════════════════════════════════════════════
         *  Main 2 + 1 grid
         * ══════════════════════════════════════════════════════════ */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-3 md:gap-6">

          {/* ── Left column (2/3) ─────────────────────────────── */}
          <div className="lg:col-span-2 flex flex-col gap-3 md:gap-6">
            <DashboardHeroCard
              profile={profile}
              memberSinceDays={stats.memberSinceDays}
            />

            {/* Critical warnings – hardcoded above the fold */}
            <NinaWarningBanner
              lat={profile?.latitude ?? undefined}
              lng={profile?.longitude ?? undefined}
            />
            <FoodWarningBanner />

            <QuickActions unreadCount={totalUnread} />

            {/* Mobile-only: unread messages */}
            <div className="lg:hidden">
              <UnreadMessages messages={unreadMessages} />
            </div>

            {userId && <WeeklyDigest userId={userId} />}

            <SmartMatchWidget />

            {!onboardingProgress.completed && (
              <div className="lg:hidden">
                <OnboardingChecklist progress={onboardingProgress} />
              </div>
            )}

            <NearbyPosts
              posts={nearbyPosts}
              userHasLocation={!!(profile?.latitude && profile?.longitude)}
            />

            <WeeklyChallengeHighlight />

            {/* Mobile-only stats */}
            <div className="lg:hidden">
              <StatsCards stats={stats} />
            </div>

            {userId && <RatingPromptBanner userId={userId} />}

            <ActivityFeed
              activities={recentActivity}
              onRefresh={handleRefresh}
              refreshing={refreshing}
            />

            {/* Mobile-only map */}
            <div className="lg:hidden">
              <MiniMap
                posts={nearbyPosts}
                userLat={profile?.latitude ?? null}
                userLng={profile?.longitude ?? null}
              />
            </div>

            {/* Mobile-only core sidebar items */}
            <div className="lg:hidden">
              <TrustScoreCard trustScore={trustScore} />
            </div>
            {userId && (
              <div className="lg:hidden">
                <ThanksReceived userId={userId} />
              </div>
            )}
            <div className="lg:hidden">
              <CommunityPulse pulse={communityPulse} />
            </div>
            <div className="lg:hidden">
              <SuccessStoryCard />
            </div>
            <div className="lg:hidden pb-4">
              <BotTipCard tipText={botTip} />
            </div>
          </div>

          {/* ── Right column (1/3) – desktop only ──────────────── */}
          <div className="hidden lg:flex lg:col-span-1 flex-col gap-4 md:gap-6">
            {!onboardingProgress.completed && (
              <OnboardingChecklist progress={onboardingProgress} />
            )}
            <StatsCards stats={stats} />
            <TrustScoreCard trustScore={trustScore} />
            {userId && <ThanksReceived userId={userId} />}
            <UnreadMessages messages={unreadMessages} />
            <MiniMap
              posts={nearbyPosts}
              userLat={profile?.latitude ?? null}
              userLng={profile?.longitude ?? null}
            />
            <CommunityPulse pulse={communityPulse} />
            <SuccessStoryCard />
            <BotTipCard tipText={botTip} />
          </div>
        </div>

        {/* ══════════════════════════════════════════════════════════
         *  Configurable widget grid (full-width, 1/2/3 columns)
         * ══════════════════════════════════════════════════════════ */}
        <WidgetGrid
          profile={gridProfile}
          onOpenSettings={openSettings}
        />

      </div>

      {/* Rating Modal */}
      {userId && <RatingModal currentUserId={userId} />}

      {/* Widget Settings Modal */}
      {widgetSettingsOpen && (
        <WidgetSettingsModal onClose={closeSettings} />
      )}
    </PullToRefresh>
  )
}
