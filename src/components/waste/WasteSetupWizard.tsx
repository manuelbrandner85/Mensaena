'use client'

import { useState, useEffect, useCallback } from 'react'
import {
  X, ChevronRight, ChevronLeft, Check, Trash2, MapPin,
  Bell, Loader2, Search, AlertCircle,
} from 'lucide-react'
import { cn } from '@/lib/utils'
import {
  fetchOrte, fetchStrassen, fetchHausnummern,
  KNOWN_REGIONS,
  type AbfallOrt, type AbfallStrasse, type AbfallHausnummer,
} from '@/lib/api/abfallnavi'

// ─── Persistence ─────────────────────────────────────────────────────────────

export const WASTE_SETTINGS_KEY = 'mensaena_waste_settings'

export interface WasteSettings {
  region: string
  regionName: string
  ortId: string
  ortName: string
  strasseId: string
  strasseName: string
  hausnummerId: string
  hausnummerName: string
  reminderEnabled: boolean
  setupAt: string
}

export function loadWasteSettings(): WasteSettings | null {
  if (typeof window === 'undefined') return null
  try {
    const raw = localStorage.getItem(WASTE_SETTINGS_KEY)
    return raw ? (JSON.parse(raw) as WasteSettings) : null
  } catch {
    return null
  }
}

export function saveWasteSettings(s: WasteSettings) {
  localStorage.setItem(WASTE_SETTINGS_KEY, JSON.stringify(s))
}

export function clearWasteSettings() {
  localStorage.removeItem(WASTE_SETTINGS_KEY)
}

// ─── Step indicator ───────────────────────────────────────────────────────────

function StepDot({ n, active, done }: { n: number; active: boolean; done: boolean }) {
  return (
    <div
      className={cn(
        'w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold transition-all duration-300',
        done
          ? 'bg-primary-600 text-white scale-100'
          : active
            ? 'bg-primary-600 text-white ring-4 ring-primary-200 scale-110'
            : 'bg-gray-100 text-gray-400',
      )}
    >
      {done ? <Check className="w-4 h-4" /> : n}
    </div>
  )
}

function StepLine({ done }: { done: boolean }) {
  return (
    <div className="flex-1 h-0.5 mx-1 transition-all duration-500">
      <div className={cn('h-full rounded-full transition-all duration-500', done ? 'bg-primary-500' : 'bg-gray-200')} />
    </div>
  )
}

// ─── Searchable dropdown ──────────────────────────────────────────────────────

function SearchableSelect<T extends { id: string; name: string }>({
  items,
  value,
  onChange,
  placeholder,
  disabled,
  loading,
}: {
  items: T[]
  value: string
  onChange: (item: T) => void
  placeholder: string
  disabled?: boolean
  loading?: boolean
}) {
  const [query, setQuery] = useState('')
  const [open, setOpen] = useState(false)

  const filtered = query.trim()
    ? items.filter((i) => i.name.toLowerCase().includes(query.toLowerCase()))
    : items

  const selected = items.find((i) => i.id === value)

  return (
    <div className="relative">
      <button
        type="button"
        onClick={() => !disabled && !loading && setOpen((o) => !o)}
        disabled={disabled || loading}
        className={cn(
          'w-full flex items-center gap-2 px-3 py-2.5 rounded-xl border text-sm text-left transition-all',
          'bg-white border-gray-200 hover:border-primary-300 focus:outline-none focus:ring-2 focus:ring-primary-200',
          (disabled || loading) && 'opacity-50 cursor-not-allowed',
          open && 'border-primary-400 ring-2 ring-primary-200',
        )}
      >
        {loading ? (
          <Loader2 className="w-4 h-4 animate-spin text-gray-400 flex-shrink-0" />
        ) : (
          <MapPin className="w-4 h-4 text-gray-400 flex-shrink-0" />
        )}
        <span className={cn('flex-1 truncate', !selected && 'text-gray-400')}>
          {selected ? selected.name : placeholder}
        </span>
        <ChevronRight className={cn('w-4 h-4 text-gray-400 flex-shrink-0 transition-transform', open && 'rotate-90')} />
      </button>

      {open && (
        <div className="absolute z-50 mt-1 w-full bg-white border border-gray-200 rounded-xl shadow-lg overflow-hidden">
          <div className="p-2 border-b border-gray-100">
            <div className="relative">
              <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-gray-400" />
              <input
                autoFocus
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder="Suchen…"
                className="w-full pl-8 pr-3 py-1.5 text-sm border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary-200"
              />
            </div>
          </div>
          <div className="max-h-48 overflow-y-auto">
            {filtered.length === 0 ? (
              <p className="px-3 py-4 text-sm text-gray-400 text-center">Keine Ergebnisse</p>
            ) : (
              filtered.map((item) => (
                <button
                  key={item.id}
                  type="button"
                  onClick={() => { onChange(item); setOpen(false); setQuery('') }}
                  className={cn(
                    'w-full flex items-center gap-2 px-3 py-2.5 text-sm text-left hover:bg-primary-50 transition-colors',
                    value === item.id && 'bg-primary-50 text-primary-700 font-medium',
                  )}
                >
                  {value === item.id && <Check className="w-3.5 h-3.5 text-primary-600 flex-shrink-0" />}
                  <span className={cn('truncate', value !== item.id && 'pl-5')}>{item.name}</span>
                </button>
              ))
            )}
          </div>
        </div>
      )}
    </div>
  )
}

// ─── Main Wizard ──────────────────────────────────────────────────────────────

interface Props {
  onClose: () => void
  onComplete: (settings: WasteSettings) => void
  initial?: WasteSettings | null
}

export default function WasteSetupWizard({ onClose, onComplete, initial }: Props) {
  const [step, setStep] = useState(0)
  const [animDir, setAnimDir] = useState<'forward' | 'back'>('forward')

  // Step 1: Region
  const [region, setRegion] = useState(initial?.region ?? '')
  const [regionName, setRegionName] = useState(initial?.regionName ?? '')

  // Step 2: Ort → Straße → Hausnummer
  const [orte, setOrte] = useState<AbfallOrt[]>([])
  const [strassen, setStrassen] = useState<AbfallStrasse[]>([])
  const [hausnummern, setHausnummern] = useState<AbfallHausnummer[]>([])
  const [loadingOrte, setLoadingOrte] = useState(false)
  const [loadingStrassen, setLoadingStrassen] = useState(false)
  const [loadingHnr, setLoadingHnr] = useState(false)
  const [step2Error, setStep2Error] = useState('')

  const [ortId, setOrtId] = useState(initial?.ortId ?? '')
  const [ortName, setOrtName] = useState(initial?.ortName ?? '')
  const [strasseId, setStrasseId] = useState(initial?.strasseId ?? '')
  const [strasseName, setStrasseName] = useState(initial?.strasseName ?? '')
  const [hausnummerId, setHausnummerId] = useState(initial?.hausnummerId ?? '')
  const [hausnummerName, setHausnummerName] = useState(initial?.hausnummerName ?? '')

  // Step 3: Reminder
  const [reminderEnabled, setReminderEnabled] = useState(initial?.reminderEnabled ?? true)

  // ── Load orte when region changes ──
  useEffect(() => {
    if (!region) return
    setOrte([])
    setStrassen([])
    setHausnummern([])
    setOrtId('')
    setStrasseId('')
    setHausnummerId('')
    setStep2Error('')
    setLoadingOrte(true)
    fetchOrte(region)
      .then(setOrte)
      .catch(() => setStep2Error('Orte konnten nicht geladen werden.'))
      .finally(() => setLoadingOrte(false))
  }, [region])

  // ── Load strassen when ort changes ──
  useEffect(() => {
    if (!region || !ortId) return
    setStrassen([])
    setHausnummern([])
    setStrasseId('')
    setHausnummerId('')
    setLoadingStrassen(true)
    fetchStrassen(region, ortId)
      .then(setStrassen)
      .catch(() => setStep2Error('Straßen konnten nicht geladen werden.'))
      .finally(() => setLoadingStrassen(false))
  }, [region, ortId])

  // ── Load hausnummern when strasse changes ──
  useEffect(() => {
    if (!region || !strasseId) return
    setHausnummern([])
    setHausnummerId('')
    setLoadingHnr(true)
    fetchHausnummern(region, strasseId)
      .then(setHausnummern)
      .catch(() => setStep2Error('Hausnummern konnten nicht geladen werden.'))
      .finally(() => setLoadingHnr(false))
  }, [region, strasseId])

  const goNext = useCallback(() => {
    setAnimDir('forward')
    setStep((s) => s + 1)
  }, [])

  const goBack = useCallback(() => {
    setAnimDir('back')
    setStep((s) => s - 1)
  }, [])

  const handleFinish = useCallback(() => {
    const settings: WasteSettings = {
      region,
      regionName,
      ortId,
      ortName,
      strasseId,
      strasseName,
      hausnummerId,
      hausnummerName,
      reminderEnabled,
      setupAt: new Date().toISOString(),
    }
    saveWasteSettings(settings)
    onComplete(settings)
  }, [region, regionName, ortId, ortName, strasseId, strasseName, hausnummerId, hausnummerName, reminderEnabled, onComplete])

  // ── Step validity ──
  const step0Valid = !!region
  const step1Valid = !!hausnummerId

  // ── Content per step ──
  const steps = [
    {
      title: 'Region wählen',
      subtitle: 'Wähle deinen Entsorgungsträger',
      icon: <MapPin className="w-5 h-5 text-primary-600" />,
      content: (
        <div className="space-y-4">
          <p className="text-sm text-gray-600">
            Wähle die Region, in der du wohnst. Dein Entsorgungsträger bestimmt, welche Termine verfügbar sind.
          </p>
          <SearchableSelect
            items={KNOWN_REGIONS}
            value={region}
            onChange={(item) => { setRegion(item.id); setRegionName(item.name) }}
            placeholder="Region / Entsorgungsträger wählen…"
          />
          <p className="text-xs text-gray-400">
            Deine Region nicht dabei?{' '}
            <a href="https://abfallnavi.de" target="_blank" rel="noopener noreferrer" className="text-primary-600 underline">
              abfallnavi.de
            </a>{' '}
            für die vollständige Liste.
          </p>
        </div>
      ),
      valid: step0Valid,
    },
    {
      title: 'Deine Adresse',
      subtitle: 'Ort → Straße → Hausnummer',
      icon: <MapPin className="w-5 h-5 text-primary-600" />,
      content: (
        <div className="space-y-3">
          {step2Error && (
            <div className="flex items-center gap-2 text-sm text-red-600 bg-red-50 px-3 py-2 rounded-lg">
              <AlertCircle className="w-4 h-4 flex-shrink-0" />
              {step2Error}
            </div>
          )}
          <div>
            <label className="text-xs font-medium text-gray-500 mb-1 block">Ort</label>
            <SearchableSelect
              items={orte}
              value={ortId}
              onChange={(item) => { setOrtId(item.id); setOrtName(item.name) }}
              placeholder="Ort wählen…"
              loading={loadingOrte}
              disabled={!region}
            />
          </div>
          <div>
            <label className="text-xs font-medium text-gray-500 mb-1 block">Straße</label>
            <SearchableSelect
              items={strassen}
              value={strasseId}
              onChange={(item) => { setStrasseId(item.id); setStrasseName(item.name) }}
              placeholder="Straße wählen…"
              loading={loadingStrassen}
              disabled={!ortId}
            />
          </div>
          <div>
            <label className="text-xs font-medium text-gray-500 mb-1 block">Hausnummer</label>
            <SearchableSelect
              items={hausnummern}
              value={hausnummerId}
              onChange={(item) => { setHausnummerId(item.id); setHausnummerName(item.name) }}
              placeholder="Hausnummer wählen…"
              loading={loadingHnr}
              disabled={!strasseId}
            />
          </div>
        </div>
      ),
      valid: step1Valid,
    },
    {
      title: 'Fertig!',
      subtitle: 'Erinnerungen einrichten',
      icon: <Bell className="w-5 h-5 text-primary-600" />,
      content: (
        <div className="space-y-5">
          {/* Summary */}
          <div className="bg-primary-50 border border-primary-100 rounded-xl p-4 space-y-2">
            <div className="flex items-center gap-2">
              <Check className="w-4 h-4 text-primary-600" />
              <span className="text-sm font-medium text-primary-700">{regionName}</span>
            </div>
            <div className="flex items-center gap-2">
              <Check className="w-4 h-4 text-primary-600" />
              <span className="text-sm text-primary-700">
                {ortName}, {strasseName} {hausnummerName}
              </span>
            </div>
          </div>

          {/* Reminder toggle */}
          <div className="flex items-start gap-3 bg-white border border-gray-200 rounded-xl p-4">
            <Bell className="w-5 h-5 text-amber-500 flex-shrink-0 mt-0.5" />
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium text-gray-900">Push-Erinnerung am Vorabend</p>
              <p className="text-xs text-gray-500 mt-0.5">
                Du wirst am Abend vorher erinnert, die Tonne rauszustellen.
              </p>
            </div>
            <button
              type="button"
              onClick={() => setReminderEnabled((r) => !r)}
              aria-label={reminderEnabled ? 'Erinnerung deaktivieren' : 'Erinnerung aktivieren'}
              className={cn(
                'relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 focus:outline-none focus:ring-2 focus:ring-primary-500 focus:ring-offset-2',
                reminderEnabled ? 'bg-primary-600' : 'bg-gray-200',
              )}
            >
              <span
                className={cn(
                  'inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition-transform duration-200',
                  reminderEnabled ? 'translate-x-5' : 'translate-x-0',
                )}
              />
            </button>
          </div>

          <p className="text-xs text-gray-400 text-center">
            Die Einstellungen werden lokal auf deinem Gerät gespeichert.
          </p>
        </div>
      ),
      valid: true,
    },
  ]

  const current = steps[step]

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm animate-fade-in"
      onClick={(e) => e.target === e.currentTarget && onClose()}
    >
      <div
        className="bg-white rounded-2xl shadow-2xl w-full max-w-md overflow-hidden animate-slide-up"
        role="dialog"
        aria-modal="true"
        aria-label="Mülltermine einrichten"
      >
        {/* Header */}
        <div className="relative px-6 pt-6 pb-4 border-b border-gray-100">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 rounded-xl bg-primary-50 border border-primary-100 flex items-center justify-center">
              <Trash2 className="w-5 h-5 text-primary-600" />
            </div>
            <div>
              <h2 className="text-base font-bold text-gray-900">Mülltermine einrichten</h2>
              <p className="text-xs text-gray-500">{current.subtitle}</p>
            </div>
          </div>

          {/* Step indicator */}
          <div className="flex items-center">
            {steps.map((s, i) => (
              <div key={i} className="flex items-center flex-1">
                <StepDot n={i + 1} active={step === i} done={step > i} />
                {i < steps.length - 1 && <StepLine done={step > i} />}
              </div>
            ))}
          </div>

          <button
            onClick={onClose}
            className="absolute top-4 right-4 p-1.5 rounded-lg hover:bg-gray-100 text-gray-400 transition-colors"
            aria-label="Schließen"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Step content */}
        <div
          key={step}
          className={cn(
            'px-6 py-5 transition-all duration-300',
            animDir === 'forward' ? 'animate-slide-up' : 'animate-fade-in',
          )}
        >
          <h3 className="text-sm font-semibold text-gray-700 mb-4">{current.title}</h3>
          {current.content}
        </div>

        {/* Footer */}
        <div className="px-6 pb-6 flex items-center justify-between gap-3">
          {step > 0 ? (
            <button
              type="button"
              onClick={goBack}
              className="flex items-center gap-1.5 px-4 py-2.5 rounded-xl text-sm font-medium text-gray-600 hover:bg-gray-100 transition-colors"
            >
              <ChevronLeft className="w-4 h-4" />
              Zurück
            </button>
          ) : (
            <div />
          )}

          {step < steps.length - 1 ? (
            <button
              type="button"
              onClick={goNext}
              disabled={!current.valid}
              className={cn(
                'flex items-center gap-1.5 px-5 py-2.5 rounded-xl text-sm font-semibold transition-all',
                current.valid
                  ? 'bg-primary-600 text-white hover:bg-primary-700 shadow-sm'
                  : 'bg-gray-100 text-gray-400 cursor-not-allowed',
              )}
            >
              Weiter
              <ChevronRight className="w-4 h-4" />
            </button>
          ) : (
            <button
              type="button"
              onClick={handleFinish}
              className="flex items-center gap-1.5 px-5 py-2.5 rounded-xl text-sm font-semibold bg-primary-600 text-white hover:bg-primary-700 shadow-sm transition-all"
            >
              <Check className="w-4 h-4" />
              Fertig
            </button>
          )}
        </div>
      </div>
    </div>
  )
}
