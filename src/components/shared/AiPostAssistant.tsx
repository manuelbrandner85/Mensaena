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
    <div className="bg-gradient-to-br from-violet-50 to-primary-50 border border-violet-100 rounded-2xl p-4 space-y-3">
      <div className="flex items-center gap-2">
        <Wand2 className="w-4 h-4 text-violet-600" />
        <h4 className="text-xs font-bold text-violet-800">KI-Beitrags-Assistent</h4>
      </div>

      <div className="flex gap-2">
        <input
          type="text"
          value={prompt}
          onChange={e => setPrompt(e.target.value)}
          placeholder="Beschreibe kurz worum es geht (z.B. 'Einkaufshilfe für Rentnerin')"
          className="flex-1 px-3 py-2 border border-violet-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-violet-300 bg-white"
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
              <p className="text-xs font-bold text-violet-700 mb-1">Titel-Vorschläge:</p>
              <div className="space-y-1">
                {suggestions.titles.map((t, i) => (
                  <button
                    key={i}
                    onClick={() => { onSuggestTitle(t); toast.success('Titel übernommen') }}
                    className="block w-full text-left text-xs text-violet-800 hover:bg-violet-100 px-2.5 py-1.5 rounded-lg transition-colors bg-white border border-violet-100"
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
              <p className="text-xs font-bold text-violet-700 mb-1">Vorgeschlagene Beschreibung:</p>
              <div className="bg-white border border-violet-100 rounded-xl p-2.5 text-xs text-ink-700 leading-relaxed">
                {suggestions.description}
              </div>
              <button
                onClick={() => { onSuggestDescription(suggestions.description!); toast.success('Beschreibung übernommen') }}
                className="mt-1 text-xs text-violet-600 hover:underline font-medium"
              >
                Übernehmen
              </button>
            </div>
          )}

          {/* Kategorie */}
          {suggestions.category && (
            <div className="flex items-center gap-2">
              <p className="text-xs text-violet-700">Empfohlene Kategorie:</p>
              <button
                onClick={() => { onSuggestCategory(suggestions.category!); toast.success('Kategorie gesetzt') }}
                className="px-2.5 py-1 bg-violet-100 text-violet-700 rounded-lg text-xs font-medium hover:bg-violet-200 transition-colors"
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
