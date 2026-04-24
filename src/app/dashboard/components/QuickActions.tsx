'use client'

import Link from 'next/link'
import { PlusCircle, Map, MessageCircle, Search } from 'lucide-react'
import { cn } from '@/lib/design-system'
import { Badge } from '@/components/ui'
import { useNavigationStore } from '@/store/useNavigationStore'

interface QuickActionsProps {
  unreadCount: number
  crisisActive?: boolean
}

const actions = [
  {
    id: 'create',
    icon: PlusCircle,
    label: 'Beitrag erstellen',
    href: '/dashboard/create' as string | null,
    gradient: 'from-primary-500 to-primary-600',
    glow: 'rgba(30,170,166,0.35)',
    iconColor: 'text-white',
  },
  {
    id: 'map',
    icon: Map,
    label: 'Karte öffnen',
    href: '/dashboard/map' as string | null,
    gradient: 'from-primary-400 to-teal-500',
    glow: 'rgba(30,170,166,0.25)',
    iconColor: 'text-white',
  },
  {
    id: 'chat',
    icon: MessageCircle,
    label: 'Nachrichten',
    href: '/dashboard/chat' as string | null,
    gradient: 'from-[#4F6D8A] to-[#3a5470]',
    glow: 'rgba(79,109,138,0.3)',
    iconColor: 'text-white',
  },
  {
    id: 'search',
    icon: Search,
    label: 'Suche',
    href: null,
    gradient: 'from-stone-700 to-stone-800',
    glow: 'rgba(87,83,78,0.25)',
    iconColor: 'text-white',
  },
]

// ── SuggestionBar ────────────────────────────────────────────────────────────

interface Suggestion {
  label: string
  href: string
}

function getTimeSuggestions(): Suggestion[] {
  const h = new Date().getHours()
  if (h >= 6 && h < 12) return [
    { label: '☀️ Ich habe frisches Gemüse übrig', href: '/dashboard/create?type=sharing&category=food' },
    { label: '🚶 Ich biete einen Spaziergang an', href: '/dashboard/create?type=offer&category=everyday' },
    { label: '📦 Ich verschenke Haushaltssachen', href: '/dashboard/create?type=sharing&category=household' },
  ]
  if (h >= 12 && h < 18) return [
    { label: '🚗 Ich fahre heute Nachmittag – Mitfahrer?', href: '/dashboard/create?type=offer&category=mobility' },
    { label: '🔧 Ich kann bei Reparaturen helfen', href: '/dashboard/create?type=offer&category=repair' },
    { label: '📚 Ich habe Bücher zu verschenken', href: '/dashboard/create?type=sharing&category=education' },
  ]
  if (h >= 18 && h < 23) return [
    { label: '🍲 Ich habe Essen übrig', href: '/dashboard/create?type=sharing&category=food' },
    { label: '💬 Ich hätte gern jemanden zum Reden', href: '/dashboard/create?type=request&category=social' },
    { label: '🌿 Ich teile Kräuter aus meinem Garten', href: '/dashboard/create?type=sharing&category=garden' },
  ]
  return [
    { label: '🆘 Ich brauche dringend Hilfe', href: '/dashboard/create?type=request&urgency=high' },
    { label: '🏠 Ich biete Notunterkunft', href: '/dashboard/create?type=offer&category=housing' },
    { label: '📞 Ich suche jemanden zum Reden', href: '/dashboard/create?type=request&category=social' },
  ]
}

function SuggestionBar({ crisisActive }: { crisisActive?: boolean }) {
  const suggestions = getTimeSuggestions()

  return (
    <div className="relative mt-3">
      <div className="overflow-x-auto no-scrollbar">
        <div className="flex gap-2 snap-x snap-mandatory pb-0.5 w-max min-w-full">
          {crisisActive && (
            <Link
              href="/dashboard/create?type=rescue&urgency=high"
              className="snap-start flex-shrink-0 inline-flex items-center px-4 py-2 rounded-full text-sm font-medium border transition-all bg-red-50 border-red-200 text-red-700 hover:bg-red-100 hover:border-red-300"
            >
              ⚠️ Krise aktiv – Ich biete Hilfe an
            </Link>
          )}
          {suggestions.map((s) => (
            <Link
              key={s.href}
              href={s.href}
              className="snap-start flex-shrink-0 inline-flex items-center px-4 py-2 rounded-full text-sm border border-stone-200 bg-white text-gray-700 hover:bg-primary-50 hover:border-primary-300 hover:text-primary-700 transition-all"
            >
              {s.label}
            </Link>
          ))}
        </div>
      </div>

      {/* Right fade-out gradient */}
      <div className="pointer-events-none absolute inset-y-0 right-0 w-8 bg-gradient-to-l from-[#EEF9F9] to-transparent" />
    </div>
  )
}

// ── QuickActions ─────────────────────────────────────────────────────────────

export default function QuickActions({ unreadCount, crisisActive }: QuickActionsProps) {
  const { toggleSearch } = useNavigationStore()

  return (
    <div className="space-y-0">
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {actions.map((action, i) => {
          const Icon = action.icon
          const inner = (
            <div
              className={cn(
                'shine relative rounded-2xl p-4 flex flex-col items-center gap-2.5 overflow-hidden',
                'cursor-pointer transition-all duration-300',
                'hover:scale-[1.04] hover:-translate-y-0.5',
                `bg-gradient-to-br ${action.gradient}`,
              )}
              style={{
                boxShadow: `0 4px 20px ${action.glow}, 0 1px 4px rgba(0,0,0,0.08)`,
                animationDelay: `${i * 60}ms`,
              }}
            >
              {/* Noise grain overlay */}
              <div className="bg-noise absolute inset-0 opacity-20 pointer-events-none" />

              {/* Icon with float-idle */}
              <div className="relative z-10 float-idle" style={{ animationDelay: `${i * 0.4}s` }}>
                <Icon className={cn('w-6 h-6', action.iconColor)} strokeWidth={1.75} />
              </div>

              <span className={cn('relative z-10 text-xs font-semibold tracking-wide', action.iconColor, 'opacity-90')}>
                {action.label}
              </span>

              {action.id === 'chat' && unreadCount > 0 && (
                <Badge
                  variant="danger"
                  size="sm"
                  animated
                  className="absolute top-2 right-2 min-w-[20px] h-5 flex items-center justify-center z-20"
                >
                  {unreadCount > 9 ? '9+' : unreadCount}
                </Badge>
              )}
            </div>
          )

          if (action.href) {
            return (
              <Link key={action.id} href={action.href}>
                {inner}
              </Link>
            )
          }

          return (
            <button
              key={action.id}
              onClick={toggleSearch}
              className="text-left"
            >
              {inner}
            </button>
          )
        })}
      </div>

      <SuggestionBar crisisActive={crisisActive} />
    </div>
  )
}
