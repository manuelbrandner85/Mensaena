'use client'

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import CinemaSection from '@/components/cinema/ui/CinemaSection'

// ── Types ─────────────────────────────────────────────────────────────────────

interface Testimonial {
  quote: string
  name: string
  location: string | null
  memberIndex?: number
}

type LoadStage = 'loading' | 'stories' | 'db' | 'generated' | 'static'

// ── Static fallbacks (Stufe c) ────────────────────────────────────────────────

const STATIC_TESTIMONIALS: Testimonial[] = [
  {
    quote:
      'Durch Mensaena habe ich endlich meine Nachbarn kennengelernt. Letzte Woche hat mir Herr Müller bei der Gartenarbeit geholfen – einfach so.',
    name: 'Anna K.',
    location: 'Berlin-Kreuzberg',
  },
  {
    quote:
      'Als alleinerziehende Mutter ist Mensaena ein Segen. Die Nachbarschaft hilft sich hier wirklich gegenseitig — nicht nur digital, sondern ganz real.',
    name: 'Sarah M.',
    location: 'München-Schwabing',
  },
  {
    quote:
      'Ich bin 72 und nicht so fit mit Technik, aber Mensaena ist so einfach, dass sogar ich es kann. Jetzt helfe ich anderen beim Kochen.',
    name: 'Helmut B.',
    location: 'Hamburg-Eppendorf',
  },
]

function daysSince(dateStr: string): number {
  return Math.floor((Date.now() - new Date(dateStr).getTime()) / 86_400_000)
}

// ── Component ─────────────────────────────────────────────────────────────────

export default function LandingTestimonials() {
  const [testimonials, setTestimonials] = useState<Testimonial[]>([])
  const [stage, setStage] = useState<LoadStage>('loading')

  useEffect(() => {
    let cancelled = false

    async function load() {
      const supabase = createClient()

      try {
        // Stufe 0: echte Erfolgsgeschichten aus success_stories
        const { data: stories } = await supabase
          .from('success_stories')
          .select('title, body, profiles!success_stories_author_id_fkey(name, location)')
          .eq('is_approved', true)
          .order('created_at', { ascending: false })
          .limit(6)

        if (cancelled) return

        if (stories && stories.length > 0) {
          const items: Testimonial[] = stories.map((row) => {
            const p = Array.isArray(row.profiles)
              ? row.profiles[0]
              : (row.profiles as { name: string | null; location: string | null } | null)
            return {
              quote: row.body as string,
              name: p?.name ?? 'Nachbar:in',
              location: p?.location ?? null,
            }
          })
          setTestimonials(items)
          setStage('stories')
          return
        }

        // Stufe a: genehmigte DB-Testimonials
        const { data: dbRows } = await supabase
          .from('testimonials')
          .select('quote, profiles!inner(name, location, created_at)')
          .eq('approved', true)
          .order('featured', { ascending: false })
          .order('created_at', { ascending: false })
          .limit(6)

        if (cancelled) return

        if (dbRows && dbRows.length > 0) {
          const items: Testimonial[] = dbRows.map((row, i) => {
            const p = Array.isArray(row.profiles)
              ? row.profiles[0]
              : (row.profiles as { name: string; location: string | null } | null)
            return {
              quote: row.quote as string,
              name: p?.name ?? 'Nachbar:in',
              location: p?.location ?? null,
              memberIndex: i + 1,
            }
          })
          setTestimonials(items)
          setStage('db')
          return
        }

        // Stufe b: automatische Zitate aus frühen Profilen
        const { data: profiles } = await supabase
          .from('profiles')
          .select('name, location, created_at')
          .order('created_at', { ascending: true })
          .limit(3)

        if (cancelled) return

        if (profiles && profiles.length > 0) {
          const items: Testimonial[] = profiles.map((p) => {
            const days = daysSince(p.created_at as string)
            return {
              quote: `Seit ${days} ${days === 1 ? 'Tag' : 'Tagen'} Teil der Gemeinschaft – Mensaena verbindet.`,
              name: (p.name as string | null) ?? 'Nachbar:in',
              location: (p.location as string | null) ?? null,
            }
          })
          setTestimonials(items)
          setStage('generated')
          return
        }
      } catch {
        // silently fall through to static
      }

      // Stufe c: statische Platzhalter
      if (!cancelled) {
        setTestimonials(STATIC_TESTIMONIALS)
        setStage('static')
      }
    }

    load()
    return () => { cancelled = true }
  }, [])

  // ── Skeleton ───────────────────────────────────────────────────────────────

  if (stage === 'loading') {
    return (
      <CinemaSection
        id="testimonials"
        index="06"
        label="Stimmen aus der Gemeinschaft"
        title={<>Was unsere <span style={{ color: 'rgba(245,158,11,0.85)', fontStyle: 'italic' }}>Nachbarn</span> erzählen.</>}
      >
        <div className="space-y-24 md:space-y-32">
          {[1, 2, 3].map((i) => (
            <div key={i} className="max-w-3xl space-y-4 animate-pulse">
              <div className="h-7 rounded w-full" style={{ background: 'rgba(245,240,232,0.08)' }} />
              <div className="h-7 rounded w-4/5" style={{ background: 'rgba(245,240,232,0.06)' }} />
              <div className="flex items-center gap-3 mt-8">
                <div className="h-px w-10" style={{ background: 'rgba(245,240,232,0.15)' }} />
                <div className="h-4 rounded w-28" style={{ background: 'rgba(245,240,232,0.06)' }} />
              </div>
            </div>
          ))}
        </div>
      </CinemaSection>
    )
  }

  // ── Rendered ───────────────────────────────────────────────────────────────

  return (
    <CinemaSection
      id="testimonials"
      index="06"
      label="Stimmen aus der Gemeinschaft"
      title={<>Was unsere <span style={{ color: 'rgba(245,158,11,0.85)', fontStyle: 'italic' }}>Nachbarn</span> erzählen.</>}
    >
      {/* Giant atmospheric quotation mark */}
      <div
        className="absolute pointer-events-none select-none"
        style={{
          top: '8%', left: '5%',
          fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif',
          fontSize: 'clamp(20rem, 30vw, 40rem)',
          lineHeight: 1, fontStyle: 'italic', fontWeight: 400,
          color: 'rgba(245,158,11,0.04)',
          zIndex: 0,
        }}
        aria-hidden="true"
      >
        „
      </div>

      <div className="relative space-y-24 md:space-y-32">
        {testimonials.map((t, i) => (
          <figure
            key={i}
            className={`reveal reveal-delay-${Math.min(i + 1, 5)} max-w-3xl ${
              i % 2 === 1 ? 'md:ml-auto md:text-right' : ''
            }`}
          >
            <blockquote
              className="leading-[1.15] tracking-tight"
              style={{
                fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif',
                fontSize: 'clamp(1.75rem, 4vw, 3rem)',
                color: '#F5F0E8',
              }}
            >
              <span style={{ color: 'rgba(245,158,11,0.70)' }}>„</span>
              {t.quote}
              <span style={{ color: 'rgba(245,158,11,0.70)' }}>"</span>
            </blockquote>

            <figcaption className={`mt-10 flex items-center gap-4 ${i % 2 === 1 ? 'md:justify-end' : ''}`}>
              <span className="block h-px w-10" style={{ background: 'rgba(245,158,11,0.30)' }} aria-hidden="true" />
              <div>
                <div className={`flex items-center gap-2 ${i % 2 === 1 ? 'md:justify-end' : ''}`}>
                  <span
                    style={{
                      fontFamily: 'var(--font-cinema), var(--font-display), ui-serif, Georgia, serif',
                      fontSize: '1.1rem',
                      color: '#F5F0E8',
                    }}
                  >{t.name}</span>
                  {stage === 'db' && t.memberIndex != null && (
                    <span className="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-mono font-semibold leading-none"
                      style={{ background: 'rgba(245,158,11,0.10)', color: 'rgba(245,158,11,0.80)', border: '1px solid rgba(245,158,11,0.20)' }}>
                      Mitglied #{t.memberIndex}
                    </span>
                  )}
                </div>
                {t.location && (
                  <div className="cinema-meta-label cinema-meta-label--subtle mt-1">{t.location}</div>
                )}
              </div>
            </figcaption>
          </figure>
        ))}
      </div>

      {stage === 'stories' && (
        <p className="reveal mt-20 cinema-meta-label cinema-meta-label--subtle">
          Echte Erfahrungsberichte unserer Nachbarn
        </p>
      )}
      {stage === 'static' && (
        <p className="reveal mt-20 cinema-meta-label cinema-meta-label--subtle">
          * Beispielhafte Darstellung · Echte Erfahrungsberichte folgen
        </p>
      )}
    </CinemaSection>
  )
}
