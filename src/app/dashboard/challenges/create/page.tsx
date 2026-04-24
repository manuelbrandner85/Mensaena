'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { Trophy, ArrowLeft, Loader2 } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import { checkRateLimit } from '@/lib/rate-limit'

const CHALLENGE_CATEGORIES = [
  { value: 'umwelt',       label: '🌿 Umwelt' },
  { value: 'sozial',       label: '🤝 Soziales' },
  { value: 'fitness',      label: '💪 Fitness' },
  { value: 'bildung',      label: '📚 Bildung' },
  { value: 'kreativ',      label: '🎨 Kreativ' },
  { value: 'ernaehrung',   label: '🥗 Ernährung' },
  { value: 'gemeinschaft', label: '🏘️ Gemeinschaft' },
]

const DIFFICULTIES = [
  { value: 'leicht', label: '🟢 Leicht' },
  { value: 'mittel', label: '🟡 Mittel' },
  { value: 'schwer', label: '🔴 Schwer' },
]

export default function CreateChallengePage() {
  const router = useRouter()
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [category, setCategory] = useState('umwelt')
  const [difficulty, setDifficulty] = useState('mittel')
  const [points, setPoints] = useState('50')
  const [days, setDays] = useState('7')
  const [saving, setSaving] = useState(false)

  const handleCreate = async () => {
    if (title.trim().length < 5) { toast.error('Titel mindestens 5 Zeichen'); return }
    if (description.trim().length > 500) { toast.error('Beschreibung max. 500 Zeichen'); return }
    const daysNum = parseInt(days)
    if (isNaN(daysNum) || daysNum < 1 || daysNum > 90) { toast.error('Dauer: 1–90 Tage'); return }
    setSaving(true)
    try {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) { toast.error('Bitte einloggen'); setSaving(false); return }

      const allowed = await checkRateLimit(user.id, 'create_challenge', 2, 60)
      if (!allowed) { toast.error('Zu viele Challenges in kurzer Zeit.'); setSaving(false); return }

      const startDate = new Date()
      const endDate = new Date()
      endDate.setDate(endDate.getDate() + parseInt(days))

      const { error } = await supabase.from('challenges').insert({
        title: title.trim(),
        description: description.trim() || null,
        category,
        difficulty,
        points: parseInt(points) || 50,
        start_date: startDate.toISOString(),
        end_date: endDate.toISOString(),
        status: 'active',
        participant_count: 0,
        creator_id: user.id,
      })
      if (error) throw error
      toast.success('Challenge erstellt!')
      router.push('/dashboard/challenges')
    } catch (e: unknown) {
      toast.error('Fehler: ' + ((e as { message?: string })?.message ?? ''))
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="max-w-lg mx-auto px-4 py-6">
      <button
        onClick={() => router.back()}
        className="flex items-center gap-2 text-sm text-gray-500 hover:text-gray-800 transition-colors mb-6"
      >
        <ArrowLeft className="w-4 h-4" />
        Zurück zu Challenges
      </button>

      <div className="bg-white rounded-2xl border border-gray-100 shadow-soft overflow-hidden">
        <div className="flex items-center gap-3 px-6 py-5 border-b border-gray-100">
          <div className="w-9 h-9 rounded-xl bg-amber-100 flex items-center justify-center flex-shrink-0">
            <Trophy className="w-5 h-5 text-amber-600" />
          </div>
          <div>
            <h1 className="text-base font-semibold text-gray-900">Neue Challenge</h1>
            <p className="text-xs text-gray-400 mt-0.5">Motiviere deine Gemeinschaft</p>
          </div>
        </div>

        <div className="p-6 space-y-4">
          <div>
            <label className="label">Challenge-Titel *</label>
            <input
              value={title}
              onChange={e => setTitle(e.target.value)}
              maxLength={80}
              className="input"
              placeholder="z.B. 7 Tage plastikfrei"
              autoFocus
            />
            {title.trim().length > 0 && title.trim().length < 5 && (
              <p className="text-xs text-red-500 mt-1">Mindestens 5 Zeichen nötig</p>
            )}
          </div>

          <div>
            <label className="label">
              Beschreibung <span className="font-normal text-gray-400">({description.length}/500)</span>
            </label>
            <textarea
              value={description}
              onChange={e => setDescription(e.target.value)}
              rows={3}
              maxLength={500}
              className="input resize-none"
              placeholder="Was ist die Challenge? Was sollen Teilnehmer tun?"
            />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="label">Kategorie</label>
              <select value={category} onChange={e => setCategory(e.target.value)} className="input">
                {CHALLENGE_CATEGORIES.map(c => <option key={c.value} value={c.value}>{c.label}</option>)}
              </select>
            </div>
            <div>
              <label className="label">Schwierigkeit</label>
              <select value={difficulty} onChange={e => setDifficulty(e.target.value)} className="input">
                {DIFFICULTIES.map(d => <option key={d.value} value={d.value}>{d.label}</option>)}
              </select>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="label">Punkte</label>
              <input
                type="number"
                value={points}
                onChange={e => setPoints(e.target.value)}
                min="10"
                max="500"
                className="input"
              />
            </div>
            <div>
              <label className="label">Dauer (Tage)</label>
              <input
                type="number"
                value={days}
                onChange={e => setDays(e.target.value)}
                min="1"
                max="90"
                className="input"
              />
            </div>
          </div>

          <button
            onClick={handleCreate}
            disabled={saving || title.trim().length < 5}
            className="btn-primary w-full disabled:opacity-50 disabled:pointer-events-none"
          >
            {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Trophy className="w-4 h-4" />}
            Challenge starten
          </button>
        </div>
      </div>
    </div>
  )
}
