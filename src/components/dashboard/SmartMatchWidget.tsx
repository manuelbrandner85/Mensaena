'use client'

import { useEffect, useState } from 'react'
import { Sparkles, MapPin, ArrowRight, Loader2 } from 'lucide-react'
import Link from 'next/link'
import { createClient } from '@/lib/supabase/client'

interface MatchSuggestion {
  id: string
  title: string
  type: string
  category: string
  location: string | null
  created_at: string
  profiles?: { name: string | null; avatar_url: string | null }
}

export default function SmartMatchWidget() {
  const [matches, setMatches] = useState<MatchSuggestion[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const supabase = createClient()
    async function load() {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) { setLoading(false); return }

      // User-Profil laden (Standort + Skills)
      const { data: profile } = await supabase
        .from('profiles')
        .select('location, skills')
        .eq('id', user.id)
        .maybeSingle()

      // Letzte aktive Beiträge laden (nicht eigene)
      const { data: posts } = await supabase
        .from('posts')
        .select('id, title, type, category, location, created_at, profiles(name, avatar_url)')
        .neq('user_id', user.id)
        .eq('status', 'active')
        .order('created_at', { ascending: false })
        .limit(20)

      if (!posts?.length) { setLoading(false); return }

      // Einfaches Matching: Standort-Nähe + Skill-Relevanz
      const userLocation = profile?.location?.toLowerCase() || ''
      const userSkills = (profile?.skills || []) as string[]

      const scored = posts.map(p => {
        let score = 0
        // Standort-Match
        if (userLocation && p.location?.toLowerCase().includes(userLocation)) score += 3
        // Skill-Match
        const postText = `${p.title} ${p.category}`.toLowerCase()
        userSkills.forEach(skill => {
          if (postText.includes(skill.toLowerCase())) score += 2
        })
        // Hilfe-Gesuche bevorzugen
        if (p.type === 'help_request') score += 1
        return { ...p, score }
      })

      scored.sort((a, b) => b.score - a.score)
      setMatches(scored.slice(0, 3) as MatchSuggestion[])
      setLoading(false)
    }
    load()
  }, [])

  if (loading) return null
  if (matches.length === 0) return null

  return (
    <div className="bg-gradient-to-br from-primary-50 to-white border border-primary-100 rounded-2xl p-4 shadow-sm">
      <div className="flex items-center gap-2 mb-3">
        <Sparkles className="w-4 h-4 text-primary-600" />
        <h3 className="text-sm font-bold text-gray-900">Passend für dich</h3>
      </div>
      <div className="space-y-2">
        {matches.map(m => (
          <Link
            key={m.id}
            href={`/dashboard/posts/${m.id}`}
            className="flex items-center gap-3 p-3 bg-white rounded-xl border border-gray-100 hover:border-primary-200 hover:shadow-sm transition-all group"
          >
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium text-gray-900 truncate">{m.title}</p>
              <div className="flex items-center gap-2 mt-0.5">
                {m.location && (
                  <span className="text-xs text-gray-400 flex items-center gap-0.5">
                    <MapPin className="w-3 h-3" /> {m.location}
                  </span>
                )}
                <span className="text-xs text-primary-500">{m.category}</span>
              </div>
            </div>
            <ArrowRight className="w-4 h-4 text-gray-300 group-hover:text-primary-500 transition-colors flex-shrink-0" />
          </Link>
        ))}
      </div>
    </div>
  )
}
