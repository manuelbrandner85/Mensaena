'use client'

import { useState, useRef } from 'react'
import { X, Camera, Save } from 'lucide-react'
import toast from 'react-hot-toast'
import { useTranslations } from 'next-intl'
import { useModalDismiss } from '@/hooks/useModalDismiss'
import type { FoodProduct } from '@/lib/api/foodfacts'

interface ManualProductFormProps {
  initialBarcode?: string
  onSave: (product: FoodProduct, photoDataUrl?: string) => void
  onClose: () => void
}

/**
 * Fallback when a barcode is NOT in OpenFoodFacts.
 * User enters name + optional brand + optional photo,
 * and we synthesize a minimal FoodProduct.
 */
export default function ManualProductForm({ initialBarcode = '', onSave, onClose }: ManualProductFormProps) {
  const t = useTranslations('common')
  const [name, setName] = useState('')
  const [brand, setBrand] = useState('')
  const [barcode, setBarcode] = useState(initialBarcode)
  const [photoDataUrl, setPhotoDataUrl] = useState<string | null>(null)
  const fileRef = useRef<HTMLInputElement>(null)

  useModalDismiss(onClose)

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

  const handleSave = () => {
    if (!name.trim()) {
      toast.error('Bitte gib einen Produktnamen ein')
      return
    }
    const product: FoodProduct = {
      barcode: barcode || `manual-${Date.now()}`,
      name: name.trim(),
      brand: brand.trim(),
      imageUrl: photoDataUrl,
      nutriScore: null,
      ecoScore: null,
      allergens: [],
      allergenTags: [],
      isVegan: false,
      isVegetarian: false,
    }
    onSave(product, photoDataUrl ?? undefined)
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
        <div className="flex items-center justify-between px-5 pt-5 pb-3 border-b border-stone-100">
          <h2 className="font-bold text-ink-900">Produkt selbst anlegen</h2>
          <button
            onClick={onClose}
            className="w-8 h-8 rounded-full bg-stone-100 flex items-center justify-center text-ink-500 hover:text-ink-900"
            aria-label={t('done')}
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto px-5 py-4 space-y-4">
          <p className="text-xs text-ink-500">
            Dein Produkt ist nicht in der OpenFoodFacts-Datenbank. Du kannst es hier kurz selbst beschreiben — perfekt für regionale oder selbstgemachte Produkte.
          </p>

          <div>
            <label className="block text-xs font-bold text-ink-700 uppercase tracking-wider mb-1.5">
              Produktname <span className="text-red-500">*</span>
            </label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="z.B. Apfelsaft vom Bauern"
              className="input w-full text-sm"
              maxLength={100}
              autoFocus
            />
          </div>

          <div>
            <label className="block text-xs font-bold text-ink-700 uppercase tracking-wider mb-1.5">
              Marke / Hersteller
            </label>
            <input
              type="text"
              value={brand}
              onChange={(e) => setBrand(e.target.value)}
              placeholder={t('optional')}
              className="input w-full text-sm"
              maxLength={80}
            />
          </div>

          <div>
            <label className="block text-xs font-bold text-ink-700 uppercase tracking-wider mb-1.5">
              Barcode
            </label>
            <input
              type="text"
              value={barcode}
              onChange={(e) => setBarcode(e.target.value.replace(/\D/g, ''))}
              placeholder={t('optional')}
              inputMode="numeric"
              className="input w-full text-sm font-mono"
              maxLength={13}
            />
          </div>

          <div>
            <label className="block text-xs font-bold text-ink-700 uppercase tracking-wider mb-1.5">
              Foto
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
                <img src={photoDataUrl} alt="Produktfoto" className="w-full h-40 object-cover rounded-xl" />
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
                Foto aufnehmen
              </button>
            )}
          </div>
        </div>

        <div className="px-5 py-4 border-t border-stone-100 bg-stone-50">
          <button
            onClick={handleSave}
            disabled={!name.trim()}
            className="w-full flex items-center justify-center gap-2 px-4 py-3 bg-primary-600 hover:bg-primary-700 disabled:bg-stone-300 text-white rounded-xl font-semibold text-sm transition-all active:scale-[0.98] shadow-soft"
          >
            <Save className="w-4 h-4" />
            Produkt übernehmen
          </button>
        </div>
      </div>
    </div>
  )
}
