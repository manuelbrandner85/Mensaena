'use client'

import { type ReactNode } from 'react'
import { useHydratedFeatureFlag, type FeatureKey } from '@/lib/feature-flags'

interface FeatureFlagProps {
  flag: FeatureKey
  children: ReactNode
  fallback?: ReactNode
}

/**
 * Renders children only when the named feature flag is enabled.
 * Uses a hydration-safe hook so SSR never clashes with client localStorage.
 */
export default function FeatureFlag({ flag, children, fallback = null }: FeatureFlagProps) {
  const enabled = useHydratedFeatureFlag(flag)
  if (!enabled) return <>{fallback}</>
  return <>{children}</>
}
