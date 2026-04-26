'use client'

import { useEffect, useState, useCallback } from 'react'
import dynamic from 'next/dynamic'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import { cn } from '@/lib/design-system'
import { Button, ErrorState } from '@/components/ui'
import { PullToRefresh } from '@/components/mobile'

import { useDashboard } from './hooks/useDashboard'
import DashboardSkeleton from './components/DashboardSkeleton'
import DashboardHeroCard from './components/DashboardHeroCard'
import QuickActions from './components/QuickActions'
import NearbyPosts from './components/NearbyPosts'
import RatingPromptBanner from '@/app/ratings/components/RatingPromptBanner'
import NinaWarningBanner from '@/components/dashboard/NinaWarningBanner'
import FoodWarningBanner from '@/components/warnings/FoodWarningBanner'
import HolidayBadge from '@/components/calendar/HolidayBadge'

// Lazy-load below-the-fold components to shrink the initial JS bundle
// and speed up Time to Interactive. MiniMap pulls Leaflet; everything
// else is rendered after the user scrolls past QuickActions.
const skeleton = <div className="rounded-2xl bg-stone-100 animate-pulse h-40" />

const WeeklyDigest             = dynamic(() => import('./components/WeeklyDigest'),                      { ssr: false, loading: () => null })
const SmartMatchWidget         = dynamic(() => import('@/components/dashboard/SmartMatchWidget'),         { loading: () => skeleton })
const WeeklyChallengeHighlight = dynamic(() => import('@/components/features/WeeklyChallengeHighlight'), { loading: () => skeleton })
const ActivityFeed             = dynamic(() => import('./components/ActivityFeed'),                      { loading: () => skeleton })
const OnboardingChecklist      = dynamic(() => import('./components/OnboardingChecklist'),               { loading: () => skeleton })
const StatsCards               = dynamic(() => import('./components/StatsCards'),                        { loading: () => skeleton })
const UnreadMessages           = dynamic(() => import('./components/UnreadMessages'),                    { loading: () => skeleton })
const BotTipCard               = dynamic(() => import('./components/BotTipCard'),                        { loading: () => skeleton })
const TrustScoreCard           = dynamic(() => import('./components/TrustScoreCard'),                    { loading: () => skeleton })
const ThanksReceived           = dynamic(() => import('./components/ThanksReceived'),                    { loading: () => null })
const WeatherWidget            = dynamic(() => import('./components/WeatherWidget'),                     { ssr: false, loading: () => null })
const SuccessStoryCard         = dynamic(() => import('./components/SuccessStoryCard'),                  { loading: () => null })
const CommunityPulse           = dynamic(() => import('./components/CommunityPulse'),                    { loading: () => skeleton })
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
const JobsNearbyWidget = dynamic(
  () => import('@/components/jobs/JobsNearbyWidget'),
  { loading: () => skeleton },
)
const WaterLevelWidget = dynamic(
  () => import('@/components/water/WaterLevelWidget'),
  { loading: () => null },
)
const TrafficWidget = dynamic(
  () => import('@/components/traffic/TrafficWidget'),
  { loading: () => skeleton },
)
const DidYouKnowWidget = dynamic(
  () => import('@/components/knowledge/DidYouKnowWidget'),
  { loading: () => null },
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

            {/* Wichtige Warnungen immer direkt nach dem Hero */}
            <NinaWarningBanner
              lat={profile?.latitude ?? undefined}
              lng={profile?.longitude ?? undefined}
            />
            <FoodWarningBanner />

            {/* QuickActions: primäre Aktionen früh sichtbar */}
            <QuickActions unreadCount={totalUnread} />

            {/* Ungelesene Nachrichten – mobile: früh zeigen, da actionable */}
            <div className="lg:hidden">
              <UnreadMessages messages={unreadMessages} />
            </div>

            {/* Weekly digest – shows only once per 6 days or on Mondays */}
            {userId && <WeeklyDigest userId={userId} />}

            {/* "Wusstest du?" – täglicher Stadtfakt */}
            <DidYouKnowWidget />

            {/* Smart-Matching: passende Beiträge für den User */}
            <SmartMatchWidget />

            {/* Onboarding – mobile only */}
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

            {/* StatsCards – mobile only */}
            <div className="lg:hidden">
              <StatsCards stats={stats} />
            </div>

            {/* RatingPromptBanner – nach dem Hauptinhalt, nicht blockierend */}
            {userId && <RatingPromptBanner userId={userId} />}

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

            {/* WeatherWidget – mobile only */}
            {profile?.latitude && profile?.longitude && (
              <div className="lg:hidden space-y-3">
                <WeatherWidget lat={profile.latitude} lng={profile.longitude} />
                <HolidayBadge
                  lat={profile.latitude}
                  lng={profile.longitude}
                  variant="default"
                />
              </div>
            )}

{/* TrafficWidget – mobile only (Pendler-Modus) */}
            <div className="lg:hidden">
              <TrafficWidget />
            </div>

{/* TrustScore – mobile only */}
            <div className="lg:hidden">
              <TrustScoreCard trustScore={trustScore} />
            </div>

            {/* ThanksReceived – mobile only */}
            {userId && (
              <div className="lg:hidden">
                <ThanksReceived userId={userId} />
              </div>
            )}

            {/* CommunityPulse – mobile only */}
            <div className="lg:hidden">
              <CommunityPulse pulse={communityPulse} />
            </div>

            {/* SuccessStoryCard – mobile only */}
            <div className="lg:hidden">
              <SuccessStoryCard />
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
            {userId && <ThanksReceived userId={userId} />}
            <UnreadMessages messages={unreadMessages} />

            <MiniMap
              posts={nearbyPosts}
              userLat={profile?.latitude ?? null}
              userLng={profile?.longitude ?? null}
            />

            {profile?.latitude && profile?.longitude && (
              <>
                <WeatherWidget lat={profile.latitude} lng={profile.longitude} />
                <HolidayBadge
                  lat={profile.latitude}
                  lng={profile.longitude}
                  variant="default"
                />
              </>
            )}

            <WaterLevelWidget />
            <TrafficWidget />
            <JobsNearbyWidget />
            <CommunityPulse pulse={communityPulse} />
            <SuccessStoryCard />
            <BotTipCard tipText={botTip} />
          </div>
        </div>
      </div>

      {/* Rating Modal (global) */}
      {userId && <RatingModal currentUserId={userId} />}
    </PullToRefresh>
  )
}
