'use client'

import { useEffect, useState } from 'react'
import { HandHelping, Search as SearchIcon, Plus, X, Loader2 } from 'lucide-react'
import toast from 'react-hot-toast'
import { createClient } from '@/lib/supabase/client'
import { handleSupabaseError } from '@/lib/errors'

/**
 * ProfileOfferSeekTags – Nutzer können Tags pflegen: was sie anbieten
 * (z.B. "Rasenmähen", "Deutsch-Nachhilfe") und was sie suchen
 * (z.B. "Werkzeug leihen"). Tags werden auf dem Profil sichtbar und
 * dienen als Grundlage für Matching im Nachbarschafts-Feed.
 */

const MAX_TAGS = 8
const MAX_LEN = 40

export default function ProfileOfferSeekTags() {
  const [userId, setUserId] = useState<string | null>(null)
  const [offers, setOffers] = useState<string[]>([])
  const [seeks, setSeeks] = useState<string[]>([])
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [offerDraft, setOfferDraft] = useState('')
  const [seekDraft, setSeekDraft] = useState('')

  useEffect(() => {
    let cancelled = false
    ;(async () => {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) { if (!cancelled) setLoading(false); return }
      if (cancelled) return
      setUserId(user.id)
      const { data } = await supabase
        .from('profiles')
        .select('offer_tags, seek_tags')
        .eq('id', user.id)
        .maybeSingle()
      if (cancelled) return
      setOffers(Array.isArray(data?.offer_tags) ? data!.offer_tags : [])
      setSeeks(Array.isArray(data?.seek_tags) ? data!.seek_tags : [])
      setLoading(false)
    })()
    return () => { cancelled = true }
  }, [])

  const addTag = (kind: 'offer' | 'seek', raw: string) => {
    const tag = raw.trim().slice(0, MAX_LEN)
    if (!tag) return
    if (kind === 'offer') {
      if (offers.length >= MAX_TAGS) { toast.error(`Maximal ${MAX_TAGS} Tags`); return }
      if (offers.includes(tag)) return
      setOffers([...offers, tag])
      setOfferDraft('')
    } else {
      if (seeks.length >= MAX_TAGS) { toast.error(`Maximal ${MAX_TAGS} Tags`); return }
      if (seeks.includes(tag)) return
      setSeeks([...seeks, tag])
      setSeekDraft('')
    }
  }

  const removeTag = (kind: 'offer' | 'seek', tag: string) => {
    if (kind === 'offer') setOffers(offers.filter(t => t !== tag))
    else setSeeks(seeks.filter(t => t !== tag))
  }

  const save = async () => {
    if (!userId) return
    setSaving(true)
    const supabase = createClient()
    const { error } = await supabase
      .from('profiles')
      .update({ offer_tags: offers, seek_tags: seeks })
      .eq('id', userId)
    setSaving(false)
    if (handleSupabaseError(error)) return
    toast.success('Tags gespeichert')
  }

  if (loading) {
    return (
      <div className="bg-white rounded-2xl border border-gray-100 p-5 animate-pulse">
        <div className="h-4 w-40 bg-gray-200 rounded mb-3" />
        <div className="h-10 bg-gray-100 rounded-xl" />
      </div>
    )
  }

  return (
    <div className="bg-white rounded-2xl shadow-soft border border-stone-100 p-5">
      <div className="mb-4">
        <h3 className="text-sm font-bold text-gray-900">Ich biete &amp; ich suche</h3>
        <p className="text-xs text-gray-500 mt-0.5">
          Pflege kurze Stichworte. Nachbarn mit passenden Angeboten/Gesuchen werden dir vorgeschlagen.
        </p>
      </div>

      {/* Offers */}
      <div className="mb-5">
        <div className="flex items-center gap-2 mb-2">
          <HandHelping className="w-4 h-4 text-primary-700" />
          <h4 className="text-xs font-semibold tracking-wide uppercase text-gray-600">Ich biete</h4>
        </div>
        <div className="flex flex-wrap gap-2 mb-2 min-h-[28px]">
          {offers.length === 0 && (
            <span className="text-xs text-gray-400 italic">Noch nichts eingetragen</span>
          )}
          {offers.map(tag => (
            <span key={tag} className="inline-flex items-center gap-1 px-2.5 py-1 bg-primary-50 border border-primary-100 text-primary-800 text-xs font-medium rounded-full">
              {tag}
              <button type="button" onClick={() => removeTag('offer', tag)} className="hover:text-primary-900" aria-label={`${tag} entfernen`}>
                <X className="w-3 h-3" />
              </button>
            </span>
          ))}
        </div>
        <div className="flex gap-2">
          <input
            value={offerDraft}
            onChange={e => setOfferDraft(e.target.value)}
            onKeyDown={e => { if (e.key === 'Enter') { e.preventDefault(); addTag('offer', offerDraft) } }}
            placeholder="z.B. Rasenmähen, Nachhilfe Mathe"
            maxLength={MAX_LEN}
            className="flex-1 h-10 px-3 border border-gray-200 rounded-xl text-sm focus:border-primary-400 focus:outline-none focus:ring-2 focus:ring-primary-100"
          />
          <button
            type="button"
            onClick={() => addTag('offer', offerDraft)}
            className="inline-flex items-center gap-1 h-10 px-3 border border-primary-200 text-primary-700 text-xs font-semibold rounded-xl hover:bg-primary-50 transition-colors"
          >
            <Plus className="w-3.5 h-3.5" /> Hinzu
          </button>
        </div>
      </div>

      {/* Seeks */}
      <div className="mb-5">
        <div className="flex items-center gap-2 mb-2">
          <SearchIcon className="w-4 h-4 text-rose-700" />
          <h4 className="text-xs font-semibold tracking-wide uppercase text-gray-600">Ich suche</h4>
        </div>
        <div className="flex flex-wrap gap-2 mb-2 min-h-[28px]">
          {seeks.length === 0 && (
            <span className="text-xs text-gray-400 italic">Noch nichts eingetragen</span>
          )}
          {seeks.map(tag => (
            <span key={tag} className="inline-flex items-center gap-1 px-2.5 py-1 bg-rose-50 border border-rose-100 text-rose-800 text-xs font-medium rounded-full">
              {tag}
              <button type="button" onClick={() => removeTag('seek', tag)} className="hover:text-rose-900" aria-label={`${tag} entfernen`}>
                <X className="w-3 h-3" />
              </button>
            </span>
          ))}
        </div>
        <div className="flex gap-2">
          <input
            value={seekDraft}
            onChange={e => setSeekDraft(e.target.value)}
            onKeyDown={e => { if (e.key === 'Enter') { e.preventDefault(); addTag('seek', seekDraft) } }}
            placeholder="z.B. Bohrmaschine leihen"
            maxLength={MAX_LEN}
            className="flex-1 h-10 px-3 border border-gray-200 rounded-xl text-sm focus:border-rose-400 focus:outline-none focus:ring-2 focus:ring-rose-100"
          />
          <button
            type="button"
            onClick={() => addTag('seek', seekDraft)}
            className="inline-flex items-center gap-1 h-10 px-3 border border-rose-200 text-rose-700 text-xs font-semibold rounded-xl hover:bg-rose-50 transition-colors"
          >
            <Plus className="w-3.5 h-3.5" /> Hinzu
          </button>
        </div>
      </div>

      <div className="flex justify-end">
        <button
          type="button"
          onClick={save}
          disabled={saving || !userId}
          className="inline-flex items-center gap-2 px-4 h-10 bg-primary-600 text-white text-xs font-semibold rounded-xl hover:bg-primary-700 transition-colors disabled:opacity-60"
        >
          {saving && <Loader2 className="w-3.5 h-3.5 animate-spin" />}
          Tags speichern
        </button>
      </div>
    </div>
  )
}
