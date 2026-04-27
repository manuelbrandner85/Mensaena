'use client'

import { useState, useRef } from 'react'
import { X, Camera, Calendar, Send, Share2, Loader2, Image as ImageIcon } from 'lucide-react'
import toast from 'react-hot-toast'
import { useTranslations } from 'next-intl'
import { cn } from '@/lib/utils'
import { nativeShare } from '@/lib/share'
import { useModalDismiss } from '@/hooks/useModalDismiss'
import type { FoodProduct } from '@/lib/api/foodfacts'

const QUICK_AMOUNTS = ['1 Stk', '500 g', '1 kg', 'Ganze Packung', 'Halb voll']

export interface FoodShareData {
  product: FoodProduct
  amount: string
  bestBefore?: string  // ISO date string
  photoDataUrl?: string  // user-captured actual photo
}

export interface FoodShareModalProps {
  product: FoodProduct
  /** Called when user picks "Auf Mensaena teilen" – navigate to create form */
  onShareToMensaena: (data: FoodShareData) => void
  onClose: () => void
}

export default function FoodShareModal({ product, onShareToMensaena, onClose }: FoodShareModalProps) {
  const t = useTranslations('common')
  const [amount, setAmount] = useState<string>(QUICK_AMOUNTS[0])
  const [customAmount, setCustomAmount] = useState('')
  const [bestBefore, setBestBefore] = useState('')
  const [photoDataUrl, setPhotoDataUrl] = useState<string | null>(null)
  const [sharing, setSharing] = useState(false)
  const fileRef = useRef<HTMLInputElement>(null)

  useModalDismiss(onClose)

  const finalAmount = customAmount.trim() || amount

  const handlePhotoSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    if (file.size > 5 * 1024 * 1024) {
      toast.error('Bild zu groß (max. 5 MB)')
      return
    }
    const reader = new FileReader()
    reader.onload = (ev) => setPhotoDataUrl(ev.target?.result as string)
    reader.readAsDataURL(file)
  }

  const buildShareText = (): { title: string; text: string; url: string } => {
    const lines: string[] = []
    lines.push(`🥗 ${product.name}`)
    if (product.brand) lines.push(`Marke: ${product.brand}`)
    lines.push(`Menge: ${finalAmount}`)
    if (bestBefore) {
      const formatted = new Date(bestBefore).toLocaleDateString('de-DE')
      lines.push(`Mindestens haltbar bis: ${formatted}`)
    }
    if (product.isVegan) lines.push('🌱 Vegan')
    else if (product.isVegetarian) lines.push('🌿 Vegetarisch')
    if (product.allergens.length > 0) {
      lines.push(`⚠️ Enthält: ${product.allergens.join(', ')}`)
    }
    lines.push('')
    lines.push('Über Mensaena geteilt – die Nachbarschafts-App')
    return {
      title: product.name,
      text: lines.join('\n'),
      url: 'https://www.mensaena.de',
    }
  }

  const handleNativeShare = async () => {
    setSharing(true)
    const data = buildShareText()
    const result = await nativeShare(data)
    setSharing(false)
    if (result === 'shared') {
      onClose()
    } else if (result === 'copied') {
      toast.success('In Zwischenablage kopiert')
      onClose()
    } else if (result === 'cancelled') {
      // do nothing - user closed the share sheet
    } else {
      toast.error('Teilen wird auf diesem Gerät nicht unterstützt')
    }
  }

  const handleMensaenaShare = () => {
    onShareToMensaena({
      product,
      amount: finalAmount,
      bestBefore: bestBefore || undefined,
      photoDataUrl: photoDataUrl || undefined,
    })
  }

  return (
    <div
      className="fixed inset-0 z-[60] bg-black/70 sm:backdrop-blur-sm flex items-end sm:items-center justify-center sm:p-4"
      role="dialog"
      aria-modal="true"
      onClick={(e) => { if (e.target === e.currentTarget) onClose() }}
    >
      <div
        className="relative w-full sm:max-w-md bg-white rounded-t-3xl sm:rounded-2xl shadow-2xl overflow-hidden flex flex-col max-h-[92dvh]"
        style={{ paddingBottom: 'env(safe-area-inset-bottom, 0px)' }}
      >
        {/* Header */}
        <div className="flex items-center justify-between px-5 pt-5 pb-3 border-b border-stone-100">
          <h2 className="font-bold text-ink-900">Teilen vorbereiten</h2>
          <button
            onClick={onClose}
            className="w-8 h-8 rounded-full bg-stone-100 flex items-center justify-center text-ink-500 hover:text-ink-900"
            aria-label={t('done')}
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Body */}
        <div className="flex-1 overflow-y-auto px-5 py-4 space-y-5">
          {/* Product summary */}
          <div className="flex items-center gap-3 p-3 bg-stone-50 rounded-xl">
            {product.imageUrl ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={product.imageUrl} alt={product.name} className="w-12 h-12 rounded-lg object-contain bg-white p-1" />
            ) : (
              <div className="w-12 h-12 rounded-lg bg-white flex items-center justify-center text-2xl">🍽️</div>
            )}
            <div className="flex-1 min-w-0">
              <p className="text-sm font-semibold text-ink-900 truncate">{product.name}</p>
              {product.brand && <p className="text-xs text-ink-500 truncate">{product.brand}</p>}
            </div>
          </div>

          {/* Quantity picker */}
          <div>
            <label className="block text-xs font-bold text-ink-700 uppercase tracking-wider mb-2">
              Menge
            </label>
            <div className="grid grid-cols-3 gap-2 mb-2">
              {QUICK_AMOUNTS.map((opt) => (
                <button
                  key={opt}
                  type="button"
                  onClick={() => { setAmount(opt); setCustomAmount('') }}
                  className={cn(
                    'px-3 py-2 rounded-xl text-xs font-semibold transition-all border',
                    !customAmount && amount === opt
                      ? 'bg-primary-600 text-white border-primary-600 shadow-soft'
                      : 'bg-white text-ink-700 border-stone-200 hover:border-primary-300',
                  )}
                >
                  {opt}
                </button>
              ))}
            </div>
            <input
              type="text"
              value={customAmount}
              onChange={(e) => setCustomAmount(e.target.value)}
              placeholder="Andere Menge eingeben…"
              className="input w-full text-sm"
              maxLength={50}
            />
          </div>

          {/* MHD */}
          <div>
            <label className="block text-xs font-bold text-ink-700 uppercase tracking-wider mb-2">
              <Calendar className="w-3 h-3 inline mr-1 -mt-0.5" />
              Mindestens haltbar bis (optional)
            </label>
            <input
              type="date"
              value={bestBefore}
              onChange={(e) => setBestBefore(e.target.value)}
              className="input w-full text-sm"
              min={new Date().toISOString().split('T')[0]}
            />
          </div>

          {/* Photo capture */}
          <div>
            <label className="block text-xs font-bold text-ink-700 uppercase tracking-wider mb-2">
              <ImageIcon className="w-3 h-3 inline mr-1 -mt-0.5" />
              Eigenes Foto (optional)
            </label>
            <input
              ref={fileRef}
              type="file"
              accept="image/*"
              capture="environment"
              onChange={handlePhotoSelect}
              className="hidden"
            />
            {photoDataUrl ? (
              <div className="relative">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={photoDataUrl} alt="Eigenes Produktfoto" className="w-full h-40 object-cover rounded-xl" />
                <button
                  type="button"
                  onClick={() => { setPhotoDataUrl(null); if (fileRef.current) fileRef.current.value = '' }}
                  className="absolute top-2 right-2 w-8 h-8 rounded-full bg-black/60 text-white flex items-center justify-center hover:bg-black/80"
                  aria-label="Foto entfernen"
                >
                  <X className="w-4 h-4" />
                </button>
              </div>
            ) : (
              <button
                type="button"
                onClick={() => fileRef.current?.click()}
                className="w-full flex items-center justify-center gap-2 px-4 py-3 border-2 border-dashed border-stone-300 hover:border-primary-400 rounded-xl text-sm font-medium text-ink-600 hover:text-primary-600 transition-colors"
              >
                <Camera className="w-4 h-4" />
                Foto aufnehmen oder auswählen
              </button>
            )}
            <p className="text-[11px] text-ink-400 mt-1.5">
              Optional. Hilft Empfängern zu sehen, was du wirklich hast.
            </p>
          </div>
        </div>

        {/* Footer with action buttons */}
        <div className="flex flex-col gap-2 px-5 py-4 border-t border-stone-100 bg-stone-50">
          <button
            onClick={handleMensaenaShare}
            className="w-full flex items-center justify-center gap-2 px-4 py-3 bg-primary-600 hover:bg-primary-700 text-white rounded-xl font-semibold text-sm transition-all active:scale-[0.98] shadow-soft"
          >
            <Send className="w-4 h-4" />
            Auf Mensaena teilen
          </button>
          <button
            onClick={handleNativeShare}
            disabled={sharing}
            className="w-full flex items-center justify-center gap-2 px-4 py-3 bg-white hover:bg-stone-100 text-ink-800 border border-stone-200 rounded-xl font-semibold text-sm transition-all active:scale-[0.98] disabled:opacity-50"
          >
            {sharing ? <Loader2 className="w-4 h-4 animate-spin" /> : <Share2 className="w-4 h-4" />}
            An Freunde teilen (WhatsApp, …)
          </button>
        </div>
      </div>
    </div>
  )
}
