'use client'

import { useState } from 'react'
import { Sparkles, Loader2, Wand2 } from 'lucide-react'
import toast from 'react-hot-toast'

interface Props {
  currentTitle: string
  currentDescription: string
  currentType: string
  onSuggestTitle: (title: string) => void
  onSuggestDescription: (text: string) => void
  onSuggestCategory: (category: string) => void
}

export default function AiPostAssistant({
  currentTitle, currentDescription, currentType,
  onSuggestTitle, onSuggestDescription, onSuggestCategory,
}: Props) {
  const [loading, setLoading] = useState(false)
  const [suggestions, setSuggestions] = useState<{
    titles?: string[]
    description?: string
    category?: string
  } | null>(null)
  const [prompt, setPrompt] = useState('')

  const generate = async () => {
    const input = prompt || currentTitle || currentDescription
    if (!input.trim()) {
      toast.error('Gib zuerst ein Thema, einen Titel oder eine Beschreibung ein')
      return
    }
    setLoading(true)
    setSuggestions(null)
    try {
      const res = await fetch('/api/posts/ai-assist', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ input, type: currentType }),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || 'KI-Fehler')
      setSuggestions(data)
    } catch (e) {
      toast.error(e instanceof Error ? e.message : 'Fehler')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="bg-gradient-to-br from-mn-amber/8 to-primary-50 border border-white/5 rounded-2xl p-4 space-y-3">
      <div className="flex items-center gap-2">
        <Wand2 className="w-4 h-4 text-mn-amber" />
        <h4 className="text-xs font-bold text-mn-amber">KI-Beitrags-Assistent</h4>
      </div>

      <div className="flex gap-2">
        <input
          type="text"
          value={prompt}
          onChange={e => setPrompt(e.target.value)}
          placeholder="Beschreibe kurz worum es geht (z.B. 'Einkaufshilfe für Rentnerin')"
          className="flex-1 px-3 py-2 border border-white/5 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-primary-300 bg-mn-elevated"
          onKeyDown={e => e.key === 'Enter' && generate()}
        />
        <button
          onClick={generate}
          disabled={loading}
          className="px-4 py-2 bg-violet-500 hover:bg-violet-600 text-white rounded-xl text-xs font-medium shadow-sm disabled:opacity-50 transition-colors whitespace-nowrap"
        >
          {loading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Sparkles className="w-4 h-4" />}
        </button>
      </div>

      {suggestions && (
        <div className="space-y-2">
          {/* Titel-Vorschläge */}
          {suggestions.titles?.length ? (
            <div>
              <p className="text-xs font-bold text-mn-amber mb-1">Titel-Vorschläge:</p>
              <div className="space-y-1">
                {suggestions.titles.map((t, i) => (
                  <button
                    key={i}
                    onClick={() => { onSuggestTitle(t); toast.success('Titel übernommen') }}
                    className="block w-full text-left text-xs text-mn-amber hover:bg-mn-elevated px-2.5 py-1.5 rounded-lg transition-colors bg-mn-elevated border border-white/5"
                  >
                    {t}
                  </button>
                ))}
              </div>
            </div>
          ) : null}

          {/* Beschreibung */}
          {suggestions.description && (
            <div>
              <p className="text-xs font-bold text-mn-amber mb-1">Vorgeschlagene Beschreibung:</p>
              <div className="bg-mn-elevated border border-white/5 rounded-xl p-2.5 text-xs text-mn-ink-soft leading-relaxed">
                {suggestions.description}
              </div>
              <button
                onClick={() => { onSuggestDescription(suggestions.description!); toast.success('Beschreibung übernommen') }}
                className="mt-1 text-xs text-mn-amber hover:underline font-medium"
              >
                Übernehmen
              </button>
            </div>
          )}

          {/* Kategorie */}
          {suggestions.category && (
            <div className="flex items-center gap-2">
              <p className="text-xs text-mn-amber">Empfohlene Kategorie:</p>
              <button
                onClick={() => { onSuggestCategory(suggestions.category!); toast.success('Kategorie gesetzt') }}
                className="px-2.5 py-1 bg-mn-elevated text-mn-amber rounded-lg text-xs font-medium hover:bg-violet-200 transition-colors"
              >
                {suggestions.category}
              </button>
            </div>
          )}
        </div>
      )}
    </div>
  )
}
