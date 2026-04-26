'use client'

/*
 * Beispiel-Steps für häufig genutzte Module:
 *
 * animals:
 *   [
 *     { emoji: '🐱', text: 'Tier vermisst? Erstelle einen Notfall-Beitrag' },
 *     { emoji: '🐕', text: 'Tier gefunden? Melde es hier' },
 *     { emoji: '🏥', text: 'Tierheim braucht Hilfe? Rufe zur Unterstützung auf' },
 *   ]
 *
 * harvest:
 *   [
 *     { emoji: '🌿', text: 'Du hast zu viel Obst oder Gemüse? Erstelle ein Angebot' },
 *     { emoji: '🔍', text: 'Du suchst frische Naturprodukte? Stöbere in den Angeboten' },
 *     { emoji: '🗺️', text: 'Du kennst einen Hof? Trage ihn in die Karte ein' },
 *   ]
 *
 * mobility:
 *   [
 *     { emoji: '🚗', text: 'Du fährst irgendwohin? Biete freie Plätze an' },
 *     { emoji: '🙋', text: 'Du brauchst eine Fahrt? Suche hier eine Mitfahrgelegenheit' },
 *     { emoji: '📅', text: 'Regelmäßige Strecke? Erstelle ein wiederkehrendes Angebot' },
 *   ]
 */

const VISITED_KEY = 'mensaena_visited_modules'

function markVisited(moduleKey: string) {
  try {
    const existing: string[] = JSON.parse(localStorage.getItem(VISITED_KEY) ?? '[]')
    if (!existing.includes(moduleKey)) {
      localStorage.setItem(VISITED_KEY, JSON.stringify([...existing, moduleKey]))
    }
  } catch {}
}

interface ModuleFirstVisitIntroProps {
  moduleKey: string
  title: string
  steps: { emoji: string; text: string }[]
  onDismiss: () => void
}

export default function ModuleFirstVisitIntro({
  moduleKey,
  title,
  steps,
  onDismiss,
}: ModuleFirstVisitIntroProps) {
  // Secondary guard: renders nothing if already visited
  if (typeof window !== 'undefined') {
    try {
      const visited: string[] = JSON.parse(localStorage.getItem(VISITED_KEY) ?? '[]')
      if (visited.includes(moduleKey)) return null
    } catch {}
  }

  function handleDismiss() {
    markVisited(moduleKey)
    onDismiss()
  }

  return (
    <div className="absolute inset-0 z-40 bg-white/95 backdrop-blur-sm flex items-center justify-center px-4 animate-fade-in">
      <div className="w-full max-w-md py-8">
        {/* Title */}
        <h2 className="text-2xl font-bold text-ink-900 mb-1 text-center">{title}</h2>
        <p className="text-sm text-stone-500 text-center mb-6">So funktioniert's:</p>

        {/* Steps */}
        <div className="bg-white rounded-2xl border border-stone-200 shadow-sm overflow-hidden mb-6">
          {steps.map((step, i) => (
            <div
              key={i}
              className="flex items-start gap-3 px-5 py-4 border-b last:border-0 border-stone-100 animate-fade-in"
              style={{ animationDelay: `${i * 150}ms` }}
            >
              <div className="w-8 h-8 rounded-full bg-primary-100 text-primary-700 font-bold flex items-center justify-center flex-shrink-0 text-sm">
                {i + 1}
              </div>
              <div className="flex items-start gap-2 pt-0.5">
                <span className="text-lg leading-none">{step.emoji}</span>
                <span className="text-sm text-ink-700 leading-relaxed">{step.text}</span>
              </div>
            </div>
          ))}
        </div>

        {/* CTA */}
        <button
          type="button"
          onClick={handleDismiss}
          className="w-full bg-primary-600 text-white rounded-xl px-8 py-3 text-lg font-semibold hover:bg-primary-700 transition-colors shadow-sm"
        >
          Los geht's →
        </button>
      </div>
    </div>
  )
}
