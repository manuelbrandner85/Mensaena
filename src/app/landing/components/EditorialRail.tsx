'use client'

import { useEffect, useState } from 'react'

/**
 * EditorialRail — a sticky thin column pinned to the left viewport edge
 * (xl+ only). Shows the current landing section as a list of uppercase
 * mono labels with a line that grows on the active one — exactly the
 * editorial "magazine-style" navigation Linear/Arc use.
 *
 * Hidden below xl to preserve mobile/tablet whitespace.
 */
const SECTIONS = [
  { id: 'hero',         num: '01', label: 'Anfang' },
  { id: 'stats',        num: '02', label: 'Zahlen' },
  { id: 'features',     num: '03', label: 'Features' },
  { id: 'how-it-works', num: '04', label: 'Ablauf' },
  { id: 'categories',   num: '05', label: 'Kategorien' },
  { id: 'testimonials', num: '06', label: 'Stimmen' },
  { id: 'map',          num: '07', label: 'Karte' },
  { id: 'cta',          num: '08', label: 'Start' },
]

export default function EditorialRail() {
  const [active, setActive] = useState<string>('hero')

  useEffect(() => {
    if (typeof window === 'undefined') return

    const observer = new IntersectionObserver(
      (entries) => {
        // Pick the entry closest to the top of the viewport that is still intersecting.
        const visible = entries
          .filter((e) => e.isIntersecting)
          .sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top)
        if (visible.length > 0 && visible[0].target.id) {
          setActive(visible[0].target.id)
        }
      },
      { rootMargin: '-35% 0px -55% 0px', threshold: 0 },
    )

    const targets: Element[] = []
    for (const s of SECTIONS) {
      const el = document.getElementById(s.id)
      if (el) {
        observer.observe(el)
        targets.push(el)
      }
    }

    return () => {
      for (const el of targets) observer.unobserve(el)
      observer.disconnect()
    }
  }, [])

  return (
    <nav
      className="editorial-rail"
      aria-label="Landing page sections"
    >
      {SECTIONS.map((s) => (
        <a
          key={s.id}
          href={`#${s.id}`}
          className={active === s.id ? 'is-active' : ''}
        >
          <span>{s.num}</span>
          <span>{s.label}</span>
        </a>
      ))}
    </nav>
  )
}
