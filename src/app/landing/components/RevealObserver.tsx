'use client'

import { useEffect } from 'react'

/**
 * Global .reveal activator.
 *
 * Mount once inside the landing page. Any element carrying the `.reveal`
 * class will receive `.is-visible` the first time it enters the viewport.
 * Uses a single shared IntersectionObserver for zero per-element cost.
 *
 * This replaces the need to thread a scroll hook through every landing
 * component while keeping the effect one-time and silent — exactly what
 * the editorial design calls for.
 */
export default function RevealObserver() {
  useEffect(() => {
    if (typeof window === 'undefined') return

    const prefersReduced = window.matchMedia(
      '(prefers-reduced-motion: reduce)',
    ).matches

    if (prefersReduced) {
      document
        .querySelectorAll<HTMLElement>('.reveal')
        .forEach((el) => el.classList.add('is-visible'))
      return
    }

    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) {
            entry.target.classList.add('is-visible')
            observer.unobserve(entry.target)
          }
        }
      },
      { threshold: 0.15, rootMargin: '0px 0px -8% 0px' },
    )

    const attach = () => {
      document
        .querySelectorAll<HTMLElement>('.reveal:not(.is-visible)')
        .forEach((el) => observer.observe(el))
    }

    attach()

    // Watch for newly inserted .reveal elements (e.g. async sections)
    const mutation = new MutationObserver(() => attach())
    mutation.observe(document.body, { childList: true, subtree: true })

    return () => {
      observer.disconnect()
      mutation.disconnect()
    }
  }, [])

  return null
}
