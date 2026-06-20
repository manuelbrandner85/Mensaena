'use client'

import { useEffect, type RefObject } from 'react'

/**
 * useSectionProgress — liefert den Scroll-Fortschritt (0..1) einer Sektion,
 * während sie durch den Viewport läuft. rAF-gedrosselt, lenis-kompatibel,
 * imperativ (kein Re-Render pro Frame).
 *
 * - Setzt `--p` (0..1) als CSS-Custom-Property auf das Sektions-Element
 *   → für reine CSS-Parallax/Transitions nutzbar.
 * - Ruft optional `onProgress(p)` pro Frame für JS-getriebene Effekte.
 *
 * Bei prefers-reduced-motion wird `--p` einmalig auf 0 gesetzt und der
 * Listener nicht installiert (statische Darstellung).
 */
export function useSectionProgress(
  sectionRef: RefObject<HTMLElement | null>,
  onProgress?: (p: number) => void,
  deps: unknown[] = [],
) {
  useEffect(() => {
    if (typeof window === 'undefined') return
    const section = sectionRef.current
    if (!section) return

    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    if (reduced) {
      section.style.setProperty('--p', '0')
      onProgress?.(0)
      return
    }

    let raf = 0
    const clamp = (v: number) => (v < 0 ? 0 : v > 1 ? 1 : v)

    const update = () => {
      raf = 0
      const rect = section.getBoundingClientRect()
      const total = rect.height - window.innerHeight
      const p = total > 0 ? clamp(-rect.top / total) : rect.top <= 0 ? 1 : 0
      section.style.setProperty('--p', p.toFixed(4))
      onProgress?.(p)
    }

    const onScroll = () => {
      if (raf) return
      raf = requestAnimationFrame(update)
    }

    update()
    window.addEventListener('scroll', onScroll, { passive: true })
    window.addEventListener('resize', onScroll, { passive: true })
    return () => {
      if (raf) cancelAnimationFrame(raf)
      window.removeEventListener('scroll', onScroll)
      window.removeEventListener('resize', onScroll)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps)
}
