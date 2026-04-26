'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { BookOpen, FileText, Clock, ArrowLeft, Loader2 } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import { checkRateLimit } from '@/lib/rate-limit'

const WIKI_CATEGORIES = [
  { value: 'everyday', label: '📖 Alltag & Ratgeber' },
  { value: 'skills',   label: '🔧 Handwerk & Anleitung' },
  { value: 'knowledge',label: '🧠 Wissen & Bildung' },
  { value: 'housing',  label: '⚖️ Wohnen & Recht' },
  { value: 'mental',   label: '💚 Gesundheit & Wohlbefinden' },
  { value: 'emergency',label: '🚨 Notfall-Tipps' },
  { value: 'sharing',  label: '🌱 Nachhaltigkeit & Teilen' },
  { value: 'food',     label: '🍽️ Ernährung & Kochen' },
  { value: 'mobility', label: '🚲 Mobilität & Unterwegs' },
  { value: 'animals',  label: '🐾 Tiere & Natur' },
  { value: 'moving',   label: '📦 Umzug & Neuanfang' },
  { value: 'general',  label: '💻 Digital & Sonstiges' },
]

export default function CreateWikiArticlePage() {
  const router = useRouter()
  const [title, setTitle] = useState('')
  const [content, setContent] = useState('')
  const [category, setCategory] = useState('everyday')
  const [tagsInput, setTagsInput] = useState('')
  const [saving, setSaving] = useState(false)

  const handleSave = async () => {
    if (title.trim().length < 5) { toast.error('Titel mindestens 5 Zeichen'); return }
    if (content.trim().length < 20) { toast.error('Inhalt mindestens 20 Zeichen'); return }
    setSaving(true)
    try {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) { toast.error('Bitte einloggen'); setSaving(false); return }

      const allowed = await checkRateLimit(user.id, 'create_article', 3, 60)
      if (!allowed) { toast.error('Zu viele Artikel in kurzer Zeit. Bitte warte etwas.'); setSaving(false); return }

      const tags = tagsInput.split(',').map(t => t.trim().toLowerCase()).filter(Boolean)

      const { error } = await supabase.from('knowledge_articles').insert({
        title: title.trim(),
        content: content.trim(),
        category,
        tags,
        author_id: user.id,
        status: 'published',
      })
      if (error) throw error
      toast.success('Artikel veröffentlicht!')
      router.push('/dashboard/wiki')
    } catch (err: unknown) {
      toast.error('Fehler: ' + ((err as { message?: string })?.message ?? ''))
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="max-w-2xl mx-auto px-4 py-6">
      <button
        onClick={() => router.back()}
        className="flex items-center gap-2 text-sm text-ink-500 hover:text-ink-800 transition-colors mb-6"
      >
        <ArrowLeft className="w-4 h-4" />
        Zurück zur Wissensbasis
      </button>

      <div className="bg-white rounded-2xl border border-stone-100 shadow-soft overflow-hidden">
        <div className="flex items-center gap-3 px-6 py-5 border-b border-stone-100">
          <div className="w-9 h-9 rounded-xl bg-blue-100 flex items-center justify-center flex-shrink-0">
            <BookOpen className="w-5 h-5 text-blue-600" />
          </div>
          <div>
            <h1 className="text-base font-semibold text-ink-900">Neuer Artikel</h1>
            <p className="text-xs text-ink-400 mt-0.5">Teile dein Wissen mit der Gemeinschaft</p>
          </div>
        </div>

        <div className="p-6 space-y-4">
          <div className="flex items-center gap-2 bg-blue-50 border border-blue-200 rounded-xl px-3 py-2">
            <Clock className="w-4 h-4 text-blue-500 flex-shrink-0" />
            <p className="text-xs text-blue-700">Max. <strong>3 Artikel pro Stunde</strong> – neue Artikel erscheinen sofort.</p>
          </div>

          <div>
            <label className="label">Titel *</label>
            <input
              value={title}
              onChange={e => setTitle(e.target.value)}
              maxLength={120}
              className="input"
              placeholder="z.B. Wie beantrage ich Wohngeld?"
              autoFocus
            />
            {title.trim().length > 0 && title.trim().length < 5 && (
              <p className="text-xs text-red-500 mt-1">Mindestens 5 Zeichen nötig ({title.trim().length}/5)</p>
            )}
          </div>

          <div>
            <label className="label">Kategorie</label>
            <select value={category} onChange={e => setCategory(e.target.value)} className="input">
              {WIKI_CATEGORIES.map(c => <option key={c.value} value={c.value}>{c.label}</option>)}
            </select>
          </div>

          <div>
            <label className="label">
              Inhalt *{' '}
              <span className="font-normal text-ink-400">(Markdown: **fett**, # Überschrift, - Liste)</span>
            </label>
            <textarea
              value={content}
              onChange={e => setContent(e.target.value)}
              rows={14}
              className="input resize-none font-mono text-sm"
              placeholder={'# Überschrift\n\nSchreibe hier deinen Artikel...\n\n- Punkt 1\n- Punkt 2\n\n**Wichtig:** ...'}
            />
            {content.trim().length > 0 && content.trim().length < 20 && (
              <p className="text-xs text-red-500 mt-1">Mindestens 20 Zeichen nötig ({content.trim().length}/20)</p>
            )}
          </div>

          <div>
            <label className="label">Tags <span className="font-normal text-ink-400">(kommagetrennt)</span></label>
            <input
              value={tagsInput}
              onChange={e => setTagsInput(e.target.value)}
              className="input"
              placeholder="z.B. wohngeld, soziales, antrag"
            />
          </div>

          <button
            onClick={handleSave}
            disabled={saving || title.trim().length < 5 || content.trim().length < 20}
            className="btn-primary w-full disabled:opacity-50 disabled:pointer-events-none"
          >
            {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <FileText className="w-4 h-4" />}
            Veröffentlichen
          </button>
        </div>
      </div>
    </div>
  )
}
