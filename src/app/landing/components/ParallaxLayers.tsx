'use client'

import { useEffect } from 'react'

/**
 * ParallaxLayers — globaler, scroll-getriebener Parallax für die ganze Seite.
 *
 * Jedes Element mit `data-parallax="<speed>"` wird beim Scrollen sanft vertikal
 * verschoben (speed ~ -0.3..0.3). Ein einzelner rAF-Loop liest alle Elemente,
 * rechnet ihre Position relativ zur Viewport-Mitte und setzt `--py` als CSS-Var
 * (das CSS übernimmt das transform, damit andere Transforms nicht kollidieren).
 * Respektiert prefers-reduced-motion (kein Effekt). Zero-Cost wenn keine Targets.
 */
export default function ParallaxLayers() {
  useEffect(() => {
    if (typeof window === 'undefined') return
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return

    let raf = 0
    let els: HTMLElement[] = []

    const collect = () => {
      els = Array.from(document.querySelectorAll<HTMLElement>('[data-parallax]'))
    }

    const update = () => {
      raf = 0
      const vh = window.innerHeight
      for (const el of els) {
        const rect = el.getBoundingClientRect()
        // -1 (Element unter Viewport) .. +1 (über Viewport), 0 = zentriert
        const center = rect.top + rect.height / 2
        const rel = (center - vh / 2) / (vh / 2 + rect.height / 2)
        const speed = parseFloat(el.dataset.parallax || '0.15')
        const shift = -rel * speed * 100 // px
        el.style.setProperty('--py', `${shift.toFixed(1)}px`)
      }
    }

    const onScroll = () => {
      if (raf) return
      raf = requestAnimationFrame(update)
    }

    collect()
    update()
    window.addEventListener('scroll', onScroll, { passive: true })
    window.addEventListener('resize', onScroll, { passive: true })

    const mo = new MutationObserver(() => {
      collect()
      onScroll()
    })
    mo.observe(document.body, { childList: true, subtree: true })

    return () => {
      if (raf) cancelAnimationFrame(raf)
      window.removeEventListener('scroll', onScroll)
      window.removeEventListener('resize', onScroll)
      mo.disconnect()
    }
  }, [])

  return null
}
