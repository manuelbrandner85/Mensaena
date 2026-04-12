'use client'

import { useState, useRef } from 'react'
import { ImagePlus, X, MapPin, Locate, LoaderCircle, Globe, Video } from 'lucide-react'
import { cn } from '@/lib/utils'
import type { EventCategory, CreateEventInput } from '../hooks/useEvents'
import { EVENT_CATEGORIES, getCategoryBadgeClasses } from '../hooks/useEvents'
import EventRecurring from './EventRecurring'

interface EventCreateFormProps {
  onSubmit: (data: CreateEventInput) => Promise<unknown>
  onUploadImage: (file: File) => Promise<string>
}

const ALL_CATEGORIES: EventCategory[] = [
  'meetup', 'workshop', 'sport', 'food', 'market',
  'culture', 'kids', 'seniors', 'cleanup', 'other',
]

export default function EventCreateForm({ onSubmit, onUploadImage }: EventCreateFormProps) {
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [category, setCategory] = useState<EventCategory>('meetup')
  const [isAllDay, setIsAllDay] = useState(false)
  const [startDate, setStartDate] = useState('')
  const [startTime, setStartTime] = useState('')
  const [endDate, setEndDate] = useState('')
  const [endTime, setEndTime] = useState('')
  const [locationName, setLocationName] = useState('')
  const [locationAddress, setLocationAddress] = useState('')
  const [latitude, setLatitude] = useState<number | null>(null)
  const [longitude, setLongitude] = useState<number | null>(null)
  const [imageUrl, setImageUrl] = useState<string | null>(null)
  const [imagePreview, setImagePreview] = useState<string | null>(null)
  const [maxAttendees, setMaxAttendees] = useState('')
  const [cost, setCost] = useState('kostenlos')
  const [whatToBring, setWhatToBring] = useState('')
  const [contactInfo, setContactInfo] = useState('')
  const [isOnline, setIsOnline] = useState(false)
  const [onlineUrl, setOnlineUrl] = useState('')
  const [isRecurring, setIsRecurring] = useState(false)
  const [recurringFrequency, setRecurringFrequency] = useState('weekly')
  const [recurringUntil, setRecurringUntil] = useState('')
  const [uploading, setUploading] = useState(false)
  const [submitting, setSubmitting] = useState(false)
  const [acceptedNoTrade, setAcceptedNoTrade] = useState(false)
  const [errors, setErrors] = useState<Record<string, string>>({})
  const fileRef = useRef<HTMLInputElement>(null)

  const todayStr = new Date().toISOString().split('T')[0]

  const handleImage = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    const reader = new FileReader()
    reader.onload = () => setImagePreview(reader.result as string)
    reader.readAsDataURL(file)
    setUploading(true)
    try {
      const url = await onUploadImage(file)
      setImageUrl(url)
    } catch (err) {
      setImagePreview(null)
    } finally {
      setUploading(false)
    }
  }

  const handleLocation = () => {
    navigator.geolocation?.getCurrentPosition(
      async (pos) => {
        setLatitude(pos.coords.latitude)
        setLongitude(pos.coords.longitude)
        // Try reverse geocoding
        try {
          const res = await fetch(
            `https://nominatim.openstreetmap.org/reverse?lat=${pos.coords.latitude}&lon=${pos.coords.longitude}&format=json`,
          )
          const data = await res.json()
          if (data.display_name) {
            setLocationAddress(data.display_name)
          }
        } catch {}
      },
      () => {},
      { timeout: 10000 },
    )
  }

  const validate = (): boolean => {
    const errs: Record<string, string> = {}
    if (!title.trim() || title.length < 3) errs.title = 'Titel muss mindestens 3 Zeichen haben'
    if (title.length > 100) errs.title = 'Titel darf max. 100 Zeichen haben'
    if (!startDate) errs.startDate = 'Startdatum ist erforderlich'
    if (!isAllDay && !startTime) errs.startTime = 'Startzeit ist erforderlich'
    if (endDate && startDate && endDate < startDate) errs.endDate = 'Enddatum muss nach dem Startdatum liegen'
    if (description.length > 2000) errs.description = 'Beschreibung darf max. 2000 Zeichen haben'
    setErrors(errs)
    return Object.keys(errs).length === 0
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!validate()) return
    setSubmitting(true)
    try {
      const startISO = isAllDay
        ? new Date(`${startDate}T00:00:00`).toISOString()
        : new Date(`${startDate}T${startTime}`).toISOString()
      let endISO: string | null = null
      if (endDate) {
        endISO = isAllDay
          ? new Date(`${endDate}T23:59:59`).toISOString()
          : endTime
            ? new Date(`${endDate}T${endTime}`).toISOString()
            : null
      } else if (!isAllDay && endTime && startDate) {
        endISO = new Date(`${startDate}T${endTime}`).toISOString()
      }

      await onSubmit({
        title: title.trim(),
        description: description.trim() || null,
        category,
        start_date: startISO,
        end_date: endISO,
        is_all_day: isAllDay,
        location_name: locationName.trim() || null,
        location_address: locationAddress.trim() || null,
        latitude,
        longitude,
        image_url: imageUrl,
        max_attendees: maxAttendees ? parseInt(maxAttendees) : null,
        cost: cost.trim() || 'kostenlos',
        what_to_bring: whatToBring.trim() || null,
        contact_info: contactInfo.trim() || null,
        is_online: isOnline,
        online_url: isOnline && onlineUrl.trim() ? onlineUrl.trim() : null,
        is_recurring: isRecurring,
        recurring_pattern: isRecurring && recurringUntil
          ? { frequency: recurringFrequency, until: recurringUntil }
          : null,
      } as any)
    } catch {
      // handled by hook
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      {/* Title */}
      <div>
        <label className="text-sm font-medium text-gray-700 mb-1 block">
          Titel <span className="text-red-500">*</span>
        </label>
        <input
          type="text"
          value={title}
          onChange={(e) => setTitle(e.target.value.slice(0, 100))}
          placeholder="Wie heißt deine Veranstaltung?"
          className={cn(
            'w-full rounded-lg border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent',
            errors.title ? 'border-red-300' : 'border-gray-200',
          )}
          required
        />
        <div className="flex justify-between mt-1">
          {errors.title && <span className="text-xs text-red-500">{errors.title}</span>}
          <span className={cn('text-xs ml-auto', title.length > 90 ? 'text-red-500' : 'text-gray-400')}>
            {title.length}/100
          </span>
        </div>
      </div>

      {/* Description */}
      <div>
        <label className="text-sm font-medium text-gray-700 mb-1 block">Beschreibung</label>
        <textarea
          value={description}
          onChange={(e) => setDescription(e.target.value.slice(0, 2000))}
          placeholder="Beschreibe was passiert, wer eingeladen ist und was die Teilnehmer erwartet..."
          rows={4}
          className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm resize-none focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent"
        />
        <div className={cn('text-xs text-right mt-1', description.length > 1800 ? 'text-red-500' : 'text-gray-400')}>
          {description.length}/2000
        </div>
      </div>

      {/* Category */}
      <div>
        <label className="text-sm font-medium text-gray-700 mb-1.5 block">
          Kategorie <span className="text-red-500">*</span>
        </label>
        <div className="flex flex-wrap gap-2">
          {ALL_CATEGORIES.map((cat) => {
            const info = EVENT_CATEGORIES[cat]
            return (
              <button
                key={cat}
                type="button"
                onClick={() => setCategory(cat)}
                className={cn(
                  'inline-flex items-center gap-1 px-3 py-1.5 rounded-full text-xs font-medium transition-all',
                  category === cat
                    ? 'bg-emerald-600 text-white'
                    : 'bg-gray-100 text-gray-600 hover:bg-gray-200',
                )}
              >
                <span>{info.emoji}</span>
                <span>{info.label}</span>
              </button>
            )
          })}
        </div>
      </div>

      {/* Date & Time */}
      <div className="space-y-3">
        <div className="flex items-center justify-between">
          <label className="text-sm font-medium text-gray-700">
            Datum & Uhrzeit <span className="text-red-500">*</span>
          </label>
          <label className="flex items-center gap-2 cursor-pointer">
            <input
              type="checkbox"
              checked={isAllDay}
              onChange={(e) => setIsAllDay(e.target.checked)}
              className="rounded text-emerald-600 focus:ring-emerald-500"
            />
            <span className="text-sm text-gray-600">Ganztägig</span>
          </label>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div>
            <label className="text-xs text-gray-500 mb-1 block">Startdatum</label>
            <input
              type="date"
              value={startDate}
              onChange={(e) => setStartDate(e.target.value)}
              min={todayStr}
              className={cn(
                'w-full rounded-lg border px-3 py-2 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-emerald-500',
                errors.startDate ? 'border-red-300' : 'border-gray-200',
              )}
              required
            />
            {errors.startDate && <span className="text-xs text-red-500">{errors.startDate}</span>}
          </div>
          {!isAllDay && (
            <div>
              <label className="text-xs text-gray-500 mb-1 block">Startzeit</label>
              <input
                type="time"
                value={startTime}
                onChange={(e) => setStartTime(e.target.value)}
                className={cn(
                  'w-full rounded-lg border px-3 py-2 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-emerald-500',
                  errors.startTime ? 'border-red-300' : 'border-gray-200',
                )}
                required={!isAllDay}
              />
              {errors.startTime && <span className="text-xs text-red-500">{errors.startTime}</span>}
            </div>
          )}
          <div>
            <label className="text-xs text-gray-500 mb-1 block">Enddatum (optional)</label>
            <input
              type="date"
              value={endDate}
              onChange={(e) => setEndDate(e.target.value)}
              min={startDate || todayStr}
              className={cn(
                'w-full rounded-lg border px-3 py-2 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-emerald-500',
                errors.endDate ? 'border-red-300' : 'border-gray-200',
              )}
            />
            {errors.endDate && <span className="text-xs text-red-500">{errors.endDate}</span>}
          </div>
          {!isAllDay && (
            <div>
              <label className="text-xs text-gray-500 mb-1 block">Endzeit (optional)</label>
              <input
                type="time"
                value={endTime}
                onChange={(e) => setEndTime(e.target.value)}
                className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-emerald-500"
              />
            </div>
          )}
        </div>
      </div>

      {/* Online / Hybrid toggle */}
      <div>
        <label className="flex items-center gap-3 cursor-pointer">
          <input
            type="checkbox"
            checked={isOnline}
            onChange={(e) => setIsOnline(e.target.checked)}
            className="rounded text-emerald-600 focus:ring-emerald-500"
          />
          <span className="text-sm font-medium text-gray-700 flex items-center gap-1.5">
            <Globe className="w-4 h-4 text-blue-500" /> Online-Veranstaltung / Hybrid
          </span>
        </label>
        {isOnline && (
          <div className="mt-3">
            <label className="text-xs text-gray-500 mb-1 block">Meeting-Link (Zoom, Google Meet, etc.)</label>
            <div className="relative">
              <Video className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input
                type="url"
                value={onlineUrl}
                onChange={(e) => setOnlineUrl(e.target.value)}
                placeholder="https://zoom.us/j/... oder https://meet.google.com/..."
                className="w-full rounded-lg border border-gray-200 pl-10 pr-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent"
              />
            </div>
          </div>
        )}
      </div>

      {/* Location */}
      <div className="space-y-3">
        <label className="text-sm font-medium text-gray-700 block">Ort {isOnline ? '(optional bei Online-Events)' : ''}</label>
        <input
          type="text"
          value={locationName}
          onChange={(e) => setLocationName(e.target.value)}
          placeholder="z.B. Gemeinschaftsgarten Friedrichshain"
          className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent"
        />
        <input
          type="text"
          value={locationAddress}
          onChange={(e) => setLocationAddress(e.target.value)}
          placeholder="Straße, Hausnummer, PLZ, Ort"
          className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent"
        />
        <div className="flex gap-2">
          <button
            type="button"
            onClick={handleLocation}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm text-gray-600 border border-gray-200 rounded-lg hover:bg-gray-50 transition"
          >
            <Locate className="w-3.5 h-3.5" />
            Meinen Standort verwenden
          </button>
          {latitude && longitude && (
            <span className="text-xs text-emerald-600 self-center">
              <MapPin className="w-3 h-3 inline mr-0.5" />
              Koordinaten gesetzt
            </span>
          )}
        </div>
      </div>

      {/* Image */}
      <div>
        <label className="text-sm font-medium text-gray-700 mb-1 block">Bild (optional)</label>
        <input ref={fileRef} type="file" accept="image/*" onChange={handleImage} className="hidden" />
        {imagePreview ? (
          <div className="relative inline-block">
            <img src={imagePreview} alt="Vorschau" className="h-24 w-24 object-cover rounded-lg border border-gray-200" />
            {uploading && (
              <div className="absolute inset-0 flex items-center justify-center bg-black/40 rounded-lg">
                <LoaderCircle className="w-5 h-5 text-white animate-spin" />
              </div>
            )}
            <button
              type="button"
              onClick={() => { setImageUrl(null); setImagePreview(null); if (fileRef.current) fileRef.current.value = '' }}
              className="absolute -top-2 -right-2 bg-white rounded-full p-0.5 shadow border border-gray-200"
            >
              <X className="w-3.5 h-3.5 text-gray-500" />
            </button>
          </div>
        ) : (
          <button
            type="button"
            onClick={() => fileRef.current?.click()}
            className="inline-flex items-center gap-2 px-3 py-2 text-sm text-gray-600 border border-dashed border-gray-300 rounded-lg hover:bg-gray-50 transition"
          >
            <ImagePlus className="w-4 h-4" />
            Bild hinzufügen (max. 5 MB)
          </button>
        )}
      </div>

      {/* Max attendees */}
      <div>
        <label className="text-sm font-medium text-gray-700 mb-1 block">Maximale Teilnehmer (optional)</label>
        <input
          type="number"
          value={maxAttendees}
          onChange={(e) => setMaxAttendees(e.target.value)}
          placeholder="Unbegrenzt"
          min={2}
          className="w-full sm:w-40 rounded-lg border border-gray-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent"
        />
        {maxAttendees && (
          <p className="text-xs text-gray-500 mt-1">
            Wenn die maximale Anzahl erreicht ist, können keine weiteren Teilnehmer mehr beitreten.
          </p>
        )}
      </div>

      {/* Cost */}
      <div>
        <label className="text-sm font-medium text-gray-700 mb-1 block">Kosten</label>
        <input
          type="text"
          value={cost}
          onChange={(e) => setCost(e.target.value)}
          placeholder="kostenlos"
          className="w-full sm:w-64 rounded-lg border border-gray-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent"
        />
      </div>

      {/* What to bring */}
      <div>
        <label className="text-sm font-medium text-gray-700 mb-1 block">Was mitbringen? (optional)</label>
        <textarea
          value={whatToBring}
          onChange={(e) => setWhatToBring(e.target.value.slice(0, 500))}
          placeholder="z.B. Gute Laune, bequeme Schuhe, eine Kleinigkeit zum Teilen"
          rows={2}
          className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm resize-none focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent"
        />
      </div>

      {/* Contact */}
      <div>
        <label className="text-sm font-medium text-gray-700 mb-1 block">Kontakt (optional)</label>
        <input
          type="text"
          value={contactInfo}
          onChange={(e) => setContactInfo(e.target.value)}
          placeholder="Telefon oder E-Mail für Rückfragen"
          className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent"
        />
      </div>

      {/* Recurring */}
      <EventRecurring
        enabled={isRecurring}
        onToggle={setIsRecurring}
        frequency={recurringFrequency}
        onFrequencyChange={setRecurringFrequency}
        until={recurringUntil}
        onUntilChange={setRecurringUntil}
      />

      {/* No-trade confirmation */}
      <div className="bg-amber-50 border border-amber-200 rounded-xl p-4">
        <button
          type="button"
          onClick={() => setAcceptedNoTrade(v => !v)}
          className="flex items-start gap-3 w-full text-left group"
        >
          <div className={cn(
            'mt-0.5 w-5 h-5 rounded border-2 flex items-center justify-center flex-shrink-0 transition-colors',
            acceptedNoTrade ? 'bg-emerald-500 border-emerald-500' : 'border-amber-400 bg-white'
          )}>
            {acceptedNoTrade && <span className="text-white text-xs font-bold">✓</span>}
          </div>
          <div>
            <p className="text-sm font-semibold text-gray-900">Kein Handel / kein Geldgeschäft *</p>
            <p className="text-xs text-gray-500 mt-0.5">
              Ich bestätige, dass diese Veranstaltung <strong>keinen kommerziellen Handel, Verkauf oder Geldgeschäfte</strong> beinhaltet.
              Verstöße werden gemäß <a href="/nutzungsbedingungen" target="_blank" className="text-primary-600 underline">§4 AGB</a> geahndet.
            </p>
          </div>
        </button>
      </div>

      {/* Submit */}
      <button
        type="submit"
        disabled={submitting || uploading || !title.trim() || !startDate || !acceptedNoTrade}
        className="w-full py-3 rounded-lg bg-emerald-600 text-white font-medium text-sm hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed transition flex items-center justify-center gap-2"
      >
        {submitting ? (
          <>
            <LoaderCircle className="w-4 h-4 animate-spin" />
            Wird erstellt...
          </>
        ) : (
          'Veranstaltung erstellen'
        )}
      </button>
    </form>
  )
}
