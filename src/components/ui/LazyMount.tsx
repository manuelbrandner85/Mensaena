'use client'

import { useEffect, useRef, useState } from 'react'

interface LazyMountProps {
  children: React.ReactNode
  /** Margin before entering viewport that triggers mount. Default: 300px */
  rootMargin?: string
  /** Placeholder shown before mounting — defaults to empty div */
  fallback?: React.ReactNode
  className?: string
}

/**
 * Only mounts children once the wrapper div is near the viewport.
 * Cuts initial render time for below-the-fold widgets significantly.
 */
export default function LazyMount({ children, rootMargin = '300px', fallback, className }: LazyMountProps) {
  const ref = useRef<HTMLDivElement>(null)
  const [mounted, setMounted] = useState(false)

  useEffect(() => {
    const el = ref.current
    if (!el || mounted) return
    if (!('IntersectionObserver' in window)) { setMounted(true); return }
    const observer = new IntersectionObserver(
      ([entry]) => { if (entry.isIntersecting) { setMounted(true); observer.disconnect() } },
      { rootMargin },
    )
    observer.observe(el)
    return () => observer.disconnect()
  }, [rootMargin, mounted])

  return (
    <div ref={ref} className={className}>
      {mounted ? children : (fallback ?? null)}
    </div>
  )
}
