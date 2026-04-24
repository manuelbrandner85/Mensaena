'use client'

import { useState, useRef } from 'react'
import { X, ImagePlus, Loader2 } from 'lucide-react'
import { cn } from '@/lib/utils'
import showToast from '@/components/ui/Toast'
import type { BoardCategory, BoardColor, CreateBoardPostInput } from '../hooks/useBoard'
import { CATEGORY_LABELS, CATEGORY_ICONS } from '../hooks/useBoard'
import PinColorPicker from './PinColorPicker'

interface BoardCreateFormProps {
  onSubmit: (input: CreateBoardPostInput) => Promise<unknown>
  onUploadImage: (file: File) => Promise<string>
  onClose: () => void
  /** If provided, the form pre-fills with existing values (edit mode) */
  initialData?: {
    content: string
    category: BoardCategory
    color: BoardColor
    contact_info?: string | null
    image_url?: string | null
  }
  /** Replaces 'Aushang erstellen' with 'Aushang aktualisieren' etc. */
  editMode?: boolean
}

const CATEGORIES: BoardCategory[] = [
  'general', 'gesucht', 'biete', 'event', 'info', 'warnung', 'verloren', 'fundbuero',
]

const EXPIRY_OPTIONS = [
  { label: 'Kein Ablauf', value: '' },
  { label: '1 Tag', value: '1' },
  { label: '3 Tage', value: '3' },
  { label: '7 Tage', value: '7' },
  { label: '14 Tage', value: '14' },
  { label: '30 Tage', value: '30' },
]

export default function BoardCreateForm({ onSubmit, onUploadImage, onClose, initialData, editMode }: BoardCreateFormProps) {
  const [content, setContent] = useState(initialData?.content ?? '')
  const [category, setCategory] = useState<BoardCategory>(initialData?.category ?? 'general')
  const [color, setColor] = useState<BoardColor>(initialData?.color ?? 'yellow')
  const [contact, setContact] = useState(initialData?.contact_info ?? '')
  const [expiryDays, setExpiryDays] = useState('')
  const [mediaUrls, setMediaUrls] = useState<string[]>(
    initialData?.image_url ? [initialData.image_url] : []
  )
  const [previews, setPreviews] = useState<string[]>(
    initialData?.image_url ? [initialData.image_url] : []
  )
  const [uploading, setUploading] = useState(false)
  const [submitting, setSubmitting] = useState(false)
  const [acceptedNoTrade, setAcceptedNoTrade] = useState(false)
  const fileRef = useRef<HTMLInputElement>(null)

  const charCount = content.length
  const maxChars = 500

  const MAX_IMAGES = 3

  const handleImageSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    if (mediaUrls.length >= MAX_IMAGES) {
      showToast.error(`Maximal ${MAX_IMAGES} Bilder erlaubt`)
      return
    }

    const reader = new FileReader()
    reader.onload = () => setPreviews((p) => [...p, reader.result as string])
    reader.readAsDataURL(file)

    setUploading(true)
    try {
      const url = await onUploadImage(file)
      setMediaUrls((p) => [...p, url])
      showToast.success('Bild hochgeladen')
    } catch (err) {
      showToast.error(err instanceof Error ? err.message : 'Bild-Upload fehlgeschlagen')
      setPreviews((p) => p.slice(0, -1))
    } finally {
      setUploading(false)
      if (fileRef.current) fileRef.current.value = ''
    }
  }

  const removeImage = (idx: number) => {
    setMediaUrls((p) => p.filter((_, i) => i !== idx))
    setPreviews((p) => p.filter((_, i) => i !== idx))
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!content.trim() || content.length > maxChars) return

    setSubmitting(true)
    try {
      let expires_at: string | null = null
      if (expiryDays) {
        const d = new Date()
        d.setDate(d.getDate() + parseInt(expiryDays))
        expires_at = d.toISOString()
      }

      await onSubmit({
        content: content.trim(),
        category,
        color,
        media_urls: mediaUrls,
        image_url: mediaUrls[0] ?? null,
        contact_info: contact.trim() || null,
        expires_at,
      })
      showToast.success(editMode ? 'Aushang aktualisiert!' : 'Aushang erstellt!')
      onClose()
    } catch (err) {
      showToast.error(err instanceof Error ? err.message : 'Fehler beim Erstellen')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <form
      onSubmit={handleSubmit}
      className="bg-white rounded-2xl border border-gray-200 shadow-lg p-5 space-y-4 animate-in slide-in-from-top-2 duration-300"
    >
      <div className="flex items-center justify-between">
        <h3 className="font-semibold text-gray-900">{editMode ? 'Aushang bearbeiten' : 'Neuer Aushang'}</h3>
        <button type="button" onClick={onClose} className="p-1 rounded-full hover:bg-gray-100">
          <X className="w-5 h-5 text-gray-400" />
        </button>
      </div>

      {/* Content textarea */}
      <div>
        <textarea
          value={content}
          onChange={(e) => setContent(e.target.value.slice(0, maxChars))}
          placeholder="Was möchtest du an die Pinnwand hängen?"
          rows={4}
          className="w-full rounded-lg border border-gray-200 p-3 text-sm resize-none
                     focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent"
          required
        />
        <div className={cn('text-xs text-right mt-1', charCount > maxChars * 0.9 ? 'text-red-500' : 'text-gray-400')}>
          {charCount}/{maxChars}
        </div>
      </div>

      {/* Category chips */}
      <div>
        <label className="text-sm font-medium text-gray-700 mb-1.5 block">Kategorie</label>
        <div className="flex flex-wrap gap-2">
          {CATEGORIES.map((cat) => (
            <button
              key={cat}
              type="button"
              onClick={() => setCategory(cat)}
              className={cn(
                'inline-flex items-center gap-1 px-3 py-1 rounded-full text-xs font-medium transition-all',
                category === cat
                  ? 'bg-primary-600 text-white'
                  : 'bg-gray-100 text-gray-600 hover:bg-gray-200',
              )}
            >
              <span>{CATEGORY_ICONS[cat]}</span>
              <span>{CATEGORY_LABELS[cat]}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Color picker */}
      <PinColorPicker value={color} onChange={setColor} />

      {/* Image upload – bis zu 3 Bilder */}
      <div>
        <input
          ref={fileRef}
          type="file"
          accept="image/jpeg,image/png,image/webp,image/gif"
          onChange={handleImageSelect}
          className="hidden"
        />
        <div className="flex flex-wrap gap-2">
          {previews.map((src, idx) => (
            <div key={idx} className="relative">
              <img src={src} alt="" className="h-20 w-20 object-cover rounded-lg border border-gray-200" />
              <button
                type="button"
                onClick={() => removeImage(idx)}
                className="absolute -top-1.5 -right-1.5 bg-white rounded-full p-0.5 shadow border border-gray-200"
              >
                <X className="w-3 h-3 text-gray-500" />
              </button>
            </div>
          ))}
          {uploading && (
            <div className="h-20 w-20 rounded-lg border border-dashed border-gray-300 flex items-center justify-center bg-gray-50">
              <Loader2 className="w-5 h-5 text-gray-400 animate-spin" />
            </div>
          )}
          {previews.length < MAX_IMAGES && !uploading && (
            <button
              type="button"
              onClick={() => fileRef.current?.click()}
              className="h-20 w-20 inline-flex flex-col items-center justify-center gap-1 text-xs text-gray-500 border border-dashed border-gray-300 rounded-lg hover:bg-gray-50 transition"
            >
              <ImagePlus className="w-4 h-4" />
              {previews.length === 0 ? 'Bild' : 'Weiteres'}
            </button>
          )}
        </div>
        {previews.length === 0 && (
          <p className="text-xs text-gray-400 mt-1">Bis zu {MAX_IMAGES} Bilder · max. 5 MB je Bild</p>
        )}
      </div>

      {/* Contact info */}
      <div>
        <label className="text-sm font-medium text-gray-700 mb-1 block">Kontakt (optional)</label>
        <input
          type="text"
          value={contact}
          onChange={(e) => setContact(e.target.value)}
          placeholder="Telefon, E-Mail oder sonstiges..."
          className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm
                     focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent"
        />
      </div>

      {/* Expiry selector */}
      <div>
        <label className="text-sm font-medium text-gray-700 mb-1 block">Ablaufdatum</label>
        <select
          value={expiryDays}
          onChange={(e) => setExpiryDays(e.target.value)}
          className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm bg-white
                     focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent"
        >
          {EXPIRY_OPTIONS.map((opt) => (
            <option key={opt.value} value={opt.value}>
              {opt.label}
            </option>
          ))}
        </select>
      </div>

      {/* No-trade confirmation */}
      <div>
        <button
          type="button"
          onClick={() => setAcceptedNoTrade(v => !v)}
          className="flex items-start gap-3 w-full text-left group"
        >
          <div className={cn(
            'mt-0.5 w-5 h-5 rounded border-2 flex items-center justify-center flex-shrink-0 transition-colors',
            acceptedNoTrade ? 'bg-primary-500 border-primary-500' : 'border-amber-400 bg-white'
          )}>
            {acceptedNoTrade && <span className="text-white text-xs font-bold">✓</span>}
          </div>
          <div>
            <p className="text-sm font-semibold text-gray-900">Kein Handel / kein Geldgeschäft *</p>
            <p className="text-xs text-gray-500 mt-0.5">
              Ich bestätige, dass dieser Aushang <strong>keinen kommerziellen Handel, Verkauf oder Geldgeschäfte</strong> beinhaltet.
              Verstöße werden gemäß <a href="/nutzungsbedingungen" target="_blank" className="text-primary-600 underline">§4 AGB</a> geahndet.
            </p>
          </div>
        </button>
      </div>

      {/* Submit */}
      <button
        type="submit"
        disabled={!content.trim() || charCount > maxChars || submitting || uploading || !acceptedNoTrade}
        className="w-full py-2.5 rounded-lg bg-primary-600 text-white font-medium text-sm
                   hover:bg-primary-700 disabled:opacity-50 disabled:cursor-not-allowed transition
                   flex items-center justify-center gap-2"
      >
        {submitting ? (
          <>
            <Loader2 className="w-4 h-4 animate-spin" />
            {editMode ? 'Wird aktualisiert...' : 'Wird erstellt...'}
          </>
        ) : (
          editMode ? 'Aushang aktualisieren' : 'Aushang erstellen'
        )}
      </button>
    </form>
  )
}
