'use client'

import { useState, useCallback } from 'react'
import { X, Save, Loader2, Settings, MapPin, Tag, Shield, Bell, Zap, Info, Sparkles } from 'lucide-react'
import { cn } from '@/lib/design-system'
import { toast } from 'react-hot-toast'
import type { MatchPreferences } from '../types'
import { DEFAULT_PREFERENCES } from '../types'

interface PreferencesModalProps {
  preferences: MatchPreferences | null
  onSave: (updates: Partial<MatchPreferences>) => Promise<boolean>
  onClose: () => void
}

const CATEGORIES = [
  { value: 'food', label: 'Lebensmittel' },
  { value: 'everyday', label: 'Alltag' },
  { value: 'moving', label: 'Umzug' },
  { value: 'animals', label: 'Tiere' },
  { value: 'housing', label: 'Wohnen' },
  { value: 'knowledge', label: 'Wissen' },
  { value: 'skills', label: 'Skills' },
  { value: 'mental', label: 'Mentale Hilfe' },
  { value: 'mobility', label: 'Mobilität' },
  { value: 'sharing', label: 'Teilen' },
  { value: 'emergency', label: 'Notfall' },
  { value: 'general', label: 'Allgemein' },
]

export default function PreferencesModal({ preferences, onSave, onClose }: PreferencesModalProps) {
  const initial = preferences ?? { ...DEFAULT_PREFERENCES } as MatchPreferences
  const [enabled, setEnabled] = useState(initial.matching_enabled)
  const [maxDistance, setMaxDistance] = useState(initial.max_distance_km)
  const [preferred, setPreferred] = useState<string[]>(initial.preferred_categories || [])
  const [excluded, setExcluded] = useState<string[]>(initial.excluded_categories || [])
  const [minTrust, setMinTrust] = useState(initial.min_trust_score)
  const [maxPerDay, setMaxPerDay] = useState(initial.max_matches_per_day)
  const [notify, setNotify] = useState(initial.notify_on_match)
  const [autoAccept, setAutoAccept] = useState(initial.auto_accept_threshold)
  const [saving, setSaving] = useState(false)

  const toggleCategory = useCallback((cat: string, list: string[], setList: (v: string[]) => void) => {
    setList(list.includes(cat) ? list.filter((c) => c !== cat) : [...list, cat])
  }, [])

  const handleSave = useCallback(async () => {
    setSaving(true)
    const ok = await onSave({
      matching_enabled: enabled,
      max_distance_km: maxDistance,
      preferred_categories: preferred,
      excluded_categories: excluded,
      min_trust_score: minTrust,
      max_matches_per_day: maxPerDay,
      notify_on_match: notify,
      auto_accept_threshold: autoAccept,
    })
    setSaving(false)
    if (ok) {
      toast.success('Einstellungen gespeichert')
      onClose()
    } else {
      toast.error('Fehler beim Speichern')
    }
  }, [enabled, maxDistance, preferred, excluded, minTrust, maxPerDay, notify, autoAccept, onSave, onClose])

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center">
      <div className="absolute inset-0 bg-black/40 backdrop-blur-sm" onClick={onClose} />

      <div className="relative bg-white w-full max-w-md max-h-[90vh] rounded-t-2xl sm:rounded-2xl overflow-hidden flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between p-4 border-b border-stone-100">
          <div className="flex items-center gap-2">
            <Settings className="w-5 h-5 text-indigo-600" />
            <h3 className="text-base font-semibold text-ink-900">Matching-Einstellungen</h3>
          </div>
          <button onClick={onClose} className="p-1.5 rounded-lg hover:bg-stone-100 text-ink-400">
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Scrollable body */}
        <div className="flex-1 overflow-y-auto p-4 space-y-5">
          {/* Matching toggle */}
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Zap className="w-4 h-4 text-indigo-600" />
              <span className="text-sm font-medium text-ink-800">Matching aktiviert</span>
            </div>
            <button
              onClick={() => setEnabled(!enabled)}
              className={cn(
                'relative w-10 h-5 rounded-full transition-colors',
                enabled ? 'bg-indigo-600' : 'bg-stone-300',
              )}
            >
              <span className={cn(
                'absolute top-0.5 w-4 h-4 rounded-full bg-white shadow transition-transform',
                enabled ? 'translate-x-5' : 'translate-x-0.5',
              )} />
            </button>
          </div>

          {enabled && (
            <>
              {/* Max distance */}
              <div>
                <div className="flex items-center gap-2 mb-2">
                  <MapPin className="w-4 h-4 text-green-600" />
                  <span className="text-sm font-medium text-ink-800">Max. Entfernung</span>
                  <span className="ml-auto text-sm font-semibold text-indigo-600">{maxDistance} km</span>
                </div>
                <input
                  type="range"
                  min={1}
                  max={100}
                  value={maxDistance}
                  onChange={(e) => setMaxDistance(Number(e.target.value))}
                  className="w-full accent-indigo-600"
                />
                <div className="flex justify-between text-[10px] text-ink-400 mt-0.5">
                  <span>1 km</span>
                  <span>100 km</span>
                </div>
              </div>

              {/* Preferred categories */}
              <div>
                <div className="flex items-center gap-2 mb-2">
                  <Tag className="w-4 h-4 text-blue-600" />
                  <span className="text-sm font-medium text-ink-800">Bevorzugte Kategorien</span>
                </div>
                <div className="flex flex-wrap gap-1.5">
                  {CATEGORIES.map((cat) => (
                    <button
                      key={cat.value}
                      onClick={() => toggleCategory(cat.value, preferred, setPreferred)}
                      className={cn(
                        'px-2.5 py-1 rounded-full text-xs font-medium transition-all border',
                        preferred.includes(cat.value)
                          ? 'bg-indigo-100 text-indigo-700 border-indigo-200'
                          : 'bg-white text-ink-600 border-stone-200 hover:bg-stone-50',
                      )}
                    >
                      {cat.label}
                    </button>
                  ))}
                </div>
              </div>

              {/* Excluded categories */}
              <div>
                <div className="flex items-center gap-2 mb-2">
                  <Tag className="w-4 h-4 text-red-500" />
                  <span className="text-sm font-medium text-ink-800">Ausgeschlossene Kategorien</span>
                </div>
                <div className="flex flex-wrap gap-1.5">
                  {CATEGORIES.map((cat) => (
                    <button
                      key={cat.value}
                      onClick={() => toggleCategory(cat.value, excluded, setExcluded)}
                      className={cn(
                        'px-2.5 py-1 rounded-full text-xs font-medium transition-all border',
                        excluded.includes(cat.value)
                          ? 'bg-red-100 text-red-700 border-red-200'
                          : 'bg-white text-ink-600 border-stone-200 hover:bg-stone-50',
                      )}
                    >
                      {cat.label}
                    </button>
                  ))}
                </div>
              </div>

              {/* Min trust score */}
              <div>
                <div className="flex items-center gap-2 mb-2">
                  <Shield className="w-4 h-4 text-amber-600" />
                  <span className="text-sm font-medium text-ink-800">Min. Vertrauenswert</span>
                  <span className="ml-auto text-sm font-semibold text-indigo-600">{minTrust.toFixed(1)}</span>
                </div>
                <input
                  type="range"
                  min={0}
                  max={5}
                  step={0.5}
                  value={minTrust}
                  onChange={(e) => setMinTrust(Number(e.target.value))}
                  className="w-full accent-indigo-600"
                />
                <div className="flex justify-between text-[10px] text-ink-400 mt-0.5">
                  <span>0 (Alle)</span>
                  <span>5.0</span>
                </div>
              </div>

              {/* Max matches per day */}
              <div>
                <div className="flex items-center gap-2 mb-2">
                  <Sparkles className="w-4 h-4 text-purple-600" />
                  <span className="text-sm font-medium text-ink-800">Max. Matches pro Tag</span>
                  <span className="ml-auto text-sm font-semibold text-indigo-600">{maxPerDay}</span>
                </div>
                <input
                  type="range"
                  min={1}
                  max={20}
                  value={maxPerDay}
                  onChange={(e) => setMaxPerDay(Number(e.target.value))}
                  className="w-full accent-indigo-600"
                />
              </div>

              {/* Notifications toggle */}
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Bell className="w-4 h-4 text-blue-600" />
                  <span className="text-sm font-medium text-ink-800">Benachrichtigungen</span>
                </div>
                <button
                  onClick={() => setNotify(!notify)}
                  className={cn(
                    'relative w-10 h-5 rounded-full transition-colors',
                    notify ? 'bg-indigo-600' : 'bg-stone-300',
                  )}
                >
                  <span className={cn(
                    'absolute top-0.5 w-4 h-4 rounded-full bg-white shadow transition-transform',
                    notify ? 'translate-x-5' : 'translate-x-0.5',
                  )} />
                </button>
              </div>

              {/* Auto-accept threshold */}
              <div>
                <div className="flex items-center gap-2 mb-2">
                  <Zap className="w-4 h-4 text-green-600" />
                  <span className="text-sm font-medium text-ink-800">Auto-Akzeptieren ab</span>
                  <span className="ml-auto text-sm font-semibold text-indigo-600">
                    {autoAccept != null ? `${autoAccept}%` : 'Aus'}
                  </span>
                </div>
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => setAutoAccept(autoAccept != null ? null : 80)}
                    className={cn(
                      'px-2 py-1 rounded-lg text-xs font-medium border transition-colors',
                      autoAccept != null
                        ? 'bg-green-50 text-green-700 border-green-200'
                        : 'bg-stone-50 text-ink-600 border-stone-200',
                    )}
                  >
                    {autoAccept != null ? 'Aktiv' : 'Aktivieren'}
                  </button>
                  {autoAccept != null && (
                    <input
                      type="range"
                      min={50}
                      max={100}
                      step={5}
                      value={autoAccept}
                      onChange={(e) => setAutoAccept(Number(e.target.value))}
                      className="flex-1 accent-green-600"
                    />
                  )}
                </div>
                <p className="text-[10px] text-ink-400 mt-1 flex items-start gap-1">
                  <Info className="w-3 h-3 flex-shrink-0 mt-0.5" />
                  Matches mit hohem Score werden automatisch angenommen.
                </p>
              </div>
            </>
          )}
        </div>

        {/* Footer */}
        <div className="p-4 border-t border-stone-100 flex gap-2">
          <button
            onClick={onClose}
            className="flex-1 px-4 py-2.5 bg-stone-100 text-ink-700 text-sm font-medium rounded-xl hover:bg-stone-200 transition-colors"
          >
            Abbrechen
          </button>
          <button
            onClick={handleSave}
            disabled={saving}
            className="flex-1 inline-flex items-center justify-center gap-1.5 px-4 py-2.5 bg-indigo-600 text-white text-sm font-medium rounded-xl hover:bg-indigo-700 transition-colors disabled:opacity-50"
          >
            {saving ? (
              <Loader2 className="w-4 h-4 animate-spin" />
            ) : (
              <Save className="w-4 h-4" />
            )}
            Speichern
          </button>
        </div>
      </div>
    </div>
  )
}


