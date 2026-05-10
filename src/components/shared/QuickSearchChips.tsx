'use client'

/*
 * ══════════════════════════════════════════════════════════════════════════════
 * QuickSearchChips
 * ══════════════════════════════════════════════════════════════════════════════
 * Renders 8 preset-filter chips below the search field in the CommandPalette
 * (or any other search overlay). Each chip maps to a Supabase filter definition.
 *
 * ── INTEGRATION IN CommandPalette.tsx ────────────────────────────────────────
 *
 * 1. Import the component + type:
 *      import QuickSearchChips, { type ChipFilter } from '@/components/shared/QuickSearchChips'
 *      import { createClient } from '@/lib/supabase/client'
 *
 * 2. Add state inside CommandPalette():
 *      const [chipResults, setChipResults] = useState<PostResult[]>([])
 *      const [chipLoading, setChipLoading] = useState(false)
 *      const [activeChip, setActiveChip] = useState<string | null>(null)
 *
 *    Where PostResult is e.g.:
 *      interface PostResult { id: string; title: string; type: string; location_text: string | null }
 *
 * 3. Add the handler:
 *      const handleChipClick = async (filter: ChipFilter) => {
 *        setActiveChip(filter.label)
 *        setChipLoading(true)
 *        setChipResults([])
 *        if (filter.searchTerm) setQuery(filter.searchTerm)
 *        const supabase = createClient()
 *        let q = supabase
 *          .from('posts')
 *          .select('id, title, type, location_text')
 *          .in('type', filter.types)
 *          .eq('status', 'active')
 *          .limit(8)
 *        if (filter.categories?.length) q = q.in('category', filter.categories)
 *        if (filter.titleIlike) q = q.ilike('title', `%${filter.titleIlike}%`)
 *        const { data } = await q
 *        setChipResults(data ?? [])
 *        setChipLoading(false)
 *      }
 *
 * 4. Render the chips below the search input, visible when query is empty:
 *      {!query && (
 *        <QuickSearchChips onChipClick={handleChipClick} activeChip={activeChip} />
 *      )}
 *
 * 5. In the results area, show chip results when available:
 *      {chipResults.length > 0 ? (
 *        <div className="py-2">
 *          {chipLoading && <div className="px-4 py-2 text-sm text-mn-ghost">Lädt…</div>}
 *          {chipResults.map(post => (
 *            <button key={post.id} onClick={() => { router.push(`/dashboard/posts/${post.id}`); setOpen(false) }}
 *              className="w-full text-left flex items-center gap-3 px-4 py-2.5 hover:bg-mn-elevated/[0.02] transition-colors">
 *              <span className="text-sm font-medium text-mn-ink truncate">{post.title}</span>
 *              {post.location_text && (
 *                <span className="text-xs text-mn-ghost ml-auto flex-shrink-0">{post.location_text}</span>
 *              )}
 *            </button>
 *          ))}
 *        </div>
 *      ) : (
 *        // ... existing filtered commands rendering
 *      )}
 *
 * 6. Reset chip state when query is cleared or overlay closes:
 *      // In the close handler:
 *      setChipResults([]); setActiveChip(null)
 *      // In the query onChange:
 *      if (e.target.value) { setChipResults([]); setActiveChip(null) }
 *
 * ── NOTE on DB types ──────────────────────────────────────────────────────────
 * Valid post types in production: rescue, help_offered, animal, housing,
 * supply, sharing, mobility, community, crisis.
 * "help_needed" is mapped to "rescue" in the DB — adjust filters if needed.
 * ══════════════════════════════════════════════════════════════════════════════
 */

import { cn } from '@/lib/utils'

export interface ChipFilter {
  label: string
  types: string[]
  categories?: string[]
  searchTerm?: string
  titleIlike?: string
}

const CHIPS: ChipFilter[] = [
  {
    label: '🏠 Umzugshilfe',
    types: ['rescue', 'help_offered'],
    searchTerm: 'umzug',
    titleIlike: 'umzug',
  },
  {
    label: '🚗 Mitfahrgelegenheit',
    types: ['mobility'],
  },
  {
    label: '🔧 Werkzeug leihen',
    types: ['sharing'],
    categories: ['everyday'],
  },
  {
    label: '🍎 Lebensmittel teilen',
    types: ['sharing', 'supply'],
    categories: ['everyday', 'general'],
  },
  {
    label: '🐾 Tierbetreuung',
    types: ['animal', 'help_offered'],
    categories: ['animals'],
  },
  {
    label: '💬 Jemand zum Reden',
    types: ['community', 'rescue'],
    categories: ['mental'],
  },
  {
    label: '📚 Bücher & Medien',
    types: ['sharing'],
    categories: ['knowledge'],
  },
  {
    label: '🌿 Garten & Ernte',
    types: ['supply', 'sharing'],
    categories: ['everyday'],
  },
]

interface QuickSearchChipsProps {
  onChipClick: (filter: ChipFilter) => void
  activeChip?: string | null
  className?: string
}

export default function QuickSearchChips({ onChipClick, activeChip, className }: QuickSearchChipsProps) {
  return (
    <div className={cn('px-4 py-3', className)}>
      <p className="text-xs text-mn-mute uppercase tracking-wider mb-2 font-semibold">
        Häufig gesucht
      </p>
      <div className="flex flex-wrap gap-2">
        {CHIPS.map((chip) => (
          <button
            key={chip.label}
            type="button"
            onClick={() => onChipClick(chip)}
            className={cn(
              'px-4 py-2 rounded-full text-sm border transition-all cursor-pointer',
              activeChip === chip.label
                ? 'bg-mn-amber/5 border-mn-amber/20 text-mn-amber font-medium'
                : 'bg-mn-elevated hover:bg-mn-amber/5 border-white/5 hover:border-mn-amber/20 text-stone-700 hover:text-mn-amber',
            )}
          >
            {chip.label}
          </button>
        ))}
      </div>
    </div>
  )
}
