'use client'

import { useState, useRef } from 'react'
import {
  ChevronLeft, ChevronRight, MapPin, ImagePlus, X, Loader2,
  AlertTriangle, Users, Package, Phone, Eye, Info,
} from 'lucide-react'
import { cn } from '@/lib/utils'
import {
  CRISIS_CATEGORY_CONFIG, URGENCY_CONFIG,
  CRISIS_SKILLS, CRISIS_RESOURCES,
  type CrisisCategory, type CrisisUrgency, type CreateCrisisInput,
} from '../types'

interface Props {
  onSubmit: (input: CreateCrisisInput) => Promise<any>
  onUploadImage?: (file: File) => Promise<string>
}

export default function CrisisCreateForm({ onSubmit, onUploadImage }: Props) {
  const [step, setStep] = useState(1) // 1: category+urgency, 2: content, 3: details
  const [category, setCategory] = useState<CrisisCategory | null>(null)
  const [urgency, setUrgency] = useState<CrisisUrgency>('high')
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [locationText, setLocationText] = useState('')
  const [contactPhone, setContactPhone] = useState('')
  const [contactName, setContactName] = useState('')
  const [isAnonymous, setIsAnonymous] = useState(false)
  const [affectedCount, setAffectedCount] = useState(0)
  const [neededHelpers, setNeededHelpers] = useState(5)
  const [selectedSkills, setSelectedSkills] = useState<string[]>([])
  const [selectedResources, setSelectedResources] = useState<string[]>([])
  const [imageUrls, setImageUrls] = useState<string[]>([])
  const [uploading, setUploading] = useState(false)
  const [submitting, setSubmitting] = useState(false)
  const fileRef = useRef<HTMLInputElement>(null)

  const canNext1 = category !== null
  const canNext2 = title.length >= 5 && description.length >= 10
  const canSubmit = canNext1 && canNext2

  const handleImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file || !onUploadImage) return
    setUploading(true)
    try {
      const url = await onUploadImage(file)
      setImageUrls(prev => [...prev, url])
    } catch {
    } finally {
      setUploading(false)
    }
  }

  const handleSubmit = async () => {
    if (!canSubmit || !category) return
    setSubmitting(true)
    try {
      await onSubmit({
        title,
        description,
        category,
        urgency,
        location_text: locationText || undefined,
        contact_phone: contactPhone || undefined,
        contact_name: contactName || undefined,
        is_anonymous: isAnonymous,
        affected_count: affectedCount,
        needed_helpers: neededHelpers,
        needed_skills: selectedSkills,
        needed_resources: selectedResources,
        image_urls: imageUrls,
      })
    } catch {
    } finally {
      setSubmitting(false)
    }
  }

  const toggleSkill = (s: string) => setSelectedSkills(prev => prev.includes(s) ? prev.filter(x => x !== s) : [...prev, s])
  const toggleResource = (r: string) => setSelectedResources(prev => prev.includes(r) ? prev.filter(x => x !== r) : [...prev, r])

  return (
    <div className="bg-white border border-gray-100 rounded-2xl shadow-sm overflow-hidden">
      {/* Progress bar */}
      <div className="h-1 bg-gray-100">
        <div className="h-full bg-red-500 transition-all duration-300" style={{ width: `${(step / 3) * 100}%` }} />
      </div>

      <div className="p-4 sm:p-6">
        {/* Step 1: Category + Urgency */}
        {step === 1 && (
          <div>
            <h3 className="text-base font-bold text-gray-900 mb-1">Was ist passiert?</h3>
            <p className="text-xs text-gray-500 mb-4">Wähle die Kategorie und Dringlichkeit der Krise.</p>

            <div className="mb-6">
              <label className="text-xs font-semibold text-gray-700 mb-2 block">Kategorie *</label>
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                {(Object.entries(CRISIS_CATEGORY_CONFIG) as [CrisisCategory, typeof CRISIS_CATEGORY_CONFIG[CrisisCategory]][]).map(([key, cfg]) => {
                  const Icon = cfg.icon
                  return (
                    <button
                      key={key}
                      onClick={() => setCategory(key)}
                      className={cn(
                        'flex items-center gap-2 p-3 rounded-xl border text-left transition-all',
                        category === key
                          ? `${cfg.bgColor} ${cfg.borderColor} ${cfg.color} ring-2 ring-current/20`
                          : 'bg-white border-gray-200 text-gray-700 hover:bg-gray-50',
                      )}
                      aria-pressed={category === key}
                    >
                      <span className="text-lg">{cfg.emoji}</span>
                      <span className="text-xs font-medium">{cfg.label}</span>
                    </button>
                  )
                })}
              </div>
            </div>

            <div className="mb-6">
              <label className="text-xs font-semibold text-gray-700 mb-2 block">Dringlichkeit *</label>
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
                {(Object.entries(URGENCY_CONFIG) as [CrisisUrgency, typeof URGENCY_CONFIG[CrisisUrgency]][]).map(([key, cfg]) => {
                  const Icon = cfg.icon
                  return (
                    <button
                      key={key}
                      onClick={() => setUrgency(key)}
                      className={cn(
                        'flex items-center gap-2 p-3 rounded-xl border transition-all',
                        urgency === key
                          ? `${cfg.bgColor} ${cfg.borderColor} ${cfg.color} ring-2 ring-current/20`
                          : 'bg-white border-gray-200 text-gray-700 hover:bg-gray-50',
                      )}
                      aria-pressed={urgency === key}
                    >
                      <div className={cn('w-2.5 h-2.5 rounded-full', cfg.pulseColor)} />
                      <span className="text-xs font-medium">{cfg.label}</span>
                    </button>
                  )
                })}
              </div>
              {urgency === 'critical' && (
                <p className="mt-2 text-xs text-red-600 flex items-center gap-1">
                  <AlertTriangle className="w-3 h-3" />
                  Kritische Meldungen erfordern einen Vertrauensscore von mind. 2.0
                </p>
              )}
            </div>
          </div>
        )}

        {/* Step 2: Content */}
        {step === 2 && (
          <div>
            <h3 className="text-base font-bold text-gray-900 mb-1">Beschreibe die Krise</h3>
            <p className="text-xs text-gray-500 mb-4">Gib so viele Details wie möglich an.</p>

            <div className="space-y-4">
              <div>
                <label className="text-xs font-semibold text-gray-700 mb-1 block">Titel * (5-200 Zeichen)</label>
                <input
                  type="text"
                  value={title}
                  onChange={e => setTitle(e.target.value)}
                  placeholder="z.B. Hochwasser in der Innenstadt"
                  className="w-full px-3 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-red-200"
                  maxLength={200}
                />
                <span className="text-xs text-gray-400 mt-1 block">{title.length}/200</span>
              </div>

              <div>
                <label className="text-xs font-semibold text-gray-700 mb-1 block">Beschreibung * (10-5000 Zeichen)</label>
                <textarea
                  value={description}
                  onChange={e => setDescription(e.target.value)}
                  placeholder="Was genau ist passiert? Wie viele Menschen sind betroffen? Welche Hilfe wird gebraucht?"
                  className="w-full px-3 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-red-200 min-h-[120px] resize-y"
                  maxLength={5000}
                />
                <span className="text-xs text-gray-400 mt-1 block">{description.length}/5000</span>
              </div>

              <div>
                <label className="text-xs font-semibold text-gray-700 mb-1 block">Standort</label>
                <div className="relative">
                  <MapPin className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                  <input
                    type="text"
                    value={locationText}
                    onChange={e => setLocationText(e.target.value)}
                    placeholder="Adresse oder Gebiet"
                    className="w-full pl-9 pr-3 py-2.5 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-red-200"
                  />
                </div>
              </div>

              {/* Image upload */}
              <div>
                <label className="text-xs font-semibold text-gray-700 mb-2 block">Fotos (optional)</label>
                <div className="flex flex-wrap gap-2">
                  {imageUrls.map((url, i) => (
                    <div key={i} className="relative w-20 h-20 rounded-xl overflow-hidden border border-gray-200">
                      <img src={url} alt="" className="w-full h-full object-cover" />
                      <button
                        onClick={() => setImageUrls(prev => prev.filter((_, j) => j !== i))}
                        className="absolute top-1 right-1 w-5 h-5 bg-black/50 rounded-full flex items-center justify-center"
                        aria-label="Foto entfernen"
                      >
                        <X className="w-3 h-3 text-white" />
                      </button>
                    </div>
                  ))}
                  {onUploadImage && imageUrls.length < 4 && (
                    <button
                      onClick={() => fileRef.current?.click()}
                      disabled={uploading}
                      className="w-20 h-20 border-2 border-dashed border-gray-300 rounded-xl flex flex-col items-center justify-center text-gray-400 hover:border-red-300 hover:text-red-400 transition-colors"
                    >
                      {uploading ? <Loader2 className="w-5 h-5 animate-spin" /> : <ImagePlus className="w-5 h-5" />}
                      <span className="text-xs mt-1">Foto</span>
                    </button>
                  )}
                </div>
                <input ref={fileRef} type="file" accept="image/jpeg,image/png,image/webp" onChange={handleImageUpload} className="hidden" />
              </div>
            </div>
          </div>
        )}

        {/* Step 3: Details */}
        {step === 3 && (
          <div>
            <h3 className="text-base font-bold text-gray-900 mb-1">Details & Kontakt</h3>
            <p className="text-xs text-gray-500 mb-4">Hilf uns, die richtige Unterstützung zu koordinieren.</p>

            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-semibold text-gray-700 mb-1 block flex items-center gap-1">
                    <Eye className="w-3 h-3" /> Betroffene
                  </label>
                  <input
                    type="number"
                    value={affectedCount}
                    onChange={e => setAffectedCount(Math.max(0, parseInt(e.target.value) || 0))}
                    min={0}
                    className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-red-200"
                  />
                </div>
                <div>
                  <label className="text-xs font-semibold text-gray-700 mb-1 block flex items-center gap-1">
                    <Users className="w-3 h-3" /> Benötigte Helfer
                  </label>
                  <input
                    type="number"
                    value={neededHelpers}
                    onChange={e => setNeededHelpers(Math.max(1, parseInt(e.target.value) || 1))}
                    min={1}
                    className="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-red-200"
                  />
                </div>
              </div>

              {/* Skills */}
              <div>
                <label className="text-xs font-semibold text-gray-700 mb-2 block flex items-center gap-1">
                  <Users className="w-3 h-3" /> Benötigte Fähigkeiten
                </label>
                <div className="flex flex-wrap gap-1.5">
                  {CRISIS_SKILLS.map(s => (
                    <button
                      key={s}
                      onClick={() => toggleSkill(s)}
                      className={cn(
                        'px-2.5 py-1 rounded-full text-xs border transition-all',
                        selectedSkills.includes(s)
                          ? 'bg-blue-100 border-blue-300 text-blue-700'
                          : 'bg-white border-gray-200 text-gray-600 hover:bg-gray-50'
                      )}
                    >
                      {s}
                    </button>
                  ))}
                </div>
              </div>

              {/* Resources */}
              <div>
                <label className="text-xs font-semibold text-gray-700 mb-2 block flex items-center gap-1">
                  <Package className="w-3 h-3" /> Benötigte Materialien
                </label>
                <div className="flex flex-wrap gap-1.5">
                  {CRISIS_RESOURCES.map(r => (
                    <button
                      key={r}
                      onClick={() => toggleResource(r)}
                      className={cn(
                        'px-2.5 py-1 rounded-full text-xs border transition-all',
                        selectedResources.includes(r)
                          ? 'bg-emerald-100 border-emerald-300 text-emerald-700'
                          : 'bg-white border-gray-200 text-gray-600 hover:bg-gray-50'
                      )}
                    >
                      {r}
                    </button>
                  ))}
                </div>
              </div>

              {/* Contact */}
              <div className="pt-2 border-t border-gray-100">
                <label className="text-xs font-semibold text-gray-700 mb-2 block flex items-center gap-1">
                  <Phone className="w-3 h-3" /> Kontakt
                </label>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-3">
                  <input
                    type="text"
                    value={contactName}
                    onChange={e => setContactName(e.target.value)}
                    placeholder="Name (optional)"
                    className="px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-red-200"
                    disabled={isAnonymous}
                  />
                  <input
                    type="tel"
                    value={contactPhone}
                    onChange={e => setContactPhone(e.target.value)}
                    placeholder="Telefon (optional)"
                    className="px-3 py-2 border border-gray-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-red-200"
                    disabled={isAnonymous}
                  />
                </div>
                <label className="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={isAnonymous}
                    onChange={e => setIsAnonymous(e.target.checked)}
                    className="w-4 h-4 rounded border-gray-300 text-red-600 focus:ring-red-200"
                  />
                  <span className="text-xs text-gray-600">Anonym melden</span>
                </label>
              </div>
            </div>
          </div>
        )}

        {/* Navigation */}
        <div className="flex items-center justify-between mt-6 pt-4 border-t border-gray-100">
          {step > 1 ? (
            <button
              onClick={() => setStep(s => s - 1)}
              className="flex items-center gap-1 px-4 py-2 bg-gray-100 text-gray-700 rounded-xl text-sm font-medium hover:bg-gray-200 transition-colors"
            >
              <ChevronLeft className="w-4 h-4" />
              Zurück
            </button>
          ) : (
            <div />
          )}

          {step < 3 ? (
            <button
              onClick={() => setStep(s => s + 1)}
              disabled={step === 1 ? !canNext1 : !canNext2}
              className="flex items-center gap-1 px-4 py-2 bg-red-600 text-white rounded-xl text-sm font-semibold hover:bg-red-700 disabled:opacity-50 transition-colors"
            >
              Weiter
              <ChevronRight className="w-4 h-4" />
            </button>
          ) : (
            <button
              onClick={handleSubmit}
              disabled={!canSubmit || submitting}
              className="flex items-center gap-2 px-6 py-2.5 bg-red-600 text-white rounded-xl text-sm font-bold hover:bg-red-700 disabled:opacity-50 transition-colors shadow-lg shadow-red-200"
            >
              {submitting ? <Loader2 className="w-4 h-4 animate-spin" /> : <AlertTriangle className="w-4 h-4" />}
              Krise melden
            </button>
          )}
        </div>
      </div>
    </div>
  )
}
