'use client'

import { useState } from 'react'
import { Bookmark, Check, X, Loader2 } from 'lucide-react'
import toast from 'react-hot-toast'
import { createClient } from '@/lib/supabase/client'
import { handleSupabaseError } from '@/lib/errors'

interface Props {
  listingId: string
  ownerId: string
  currentUserId?: string
  reservedFor: string | null
  status: string
  onChange: (patch: { reserved_for?: string | null; status?: string }) => void
}

/**
 * MarketplaceReservation – kleine Aktionsleiste für die Reservierungs-Logik:
 * - Fremder Nutzer: "Reservieren" / "Reservierung zurückziehen"
 * - Besitzer: sieht "Reserviert für X" + "Freigeben" / "Als vergeben markieren"
 * Nutzt die bestehenden Spalten `marketplace_listings.reserved_for` und `status`.
 */
export default function MarketplaceReservation({
  listingId, ownerId, currentUserId, reservedFor, status, onChange,
}: Props) {
  const [busy, setBusy] = useState(false)
  const isOwner = !!currentUserId && currentUserId === ownerId
  const reservedByMe = !!currentUserId && reservedFor === currentUserId
  const isClaimed = status === 'claimed'

  const update = async (patch: { reserved_for?: string | null; status?: string }) => {
    setBusy(true)
    const supabase = createClient()
    const { error } = await supabase
      .from('marketplace_listings')
      .update(patch)
      .eq('id', listingId)
    setBusy(false)
    if (handleSupabaseError(error)) return
    onChange(patch)
  }

  if (isClaimed) return null

  // Viewer (not owner)
  if (!isOwner) {
    if (!currentUserId) return null
    if (reservedFor && !reservedByMe) {
      return (
        <span className="inline-flex items-center gap-1 px-2 py-1 text-[11px] font-semibold bg-amber-50 border border-amber-200 text-amber-800 rounded-full">
          <Bookmark className="w-3 h-3" /> Reserviert
        </span>
      )
    }
    if (reservedByMe) {
      return (
        <button
          type="button"
          disabled={busy}
          onClick={() => { update({ reserved_for: null }); toast.success('Reservierung zurückgezogen') }}
          className="inline-flex items-center gap-1 px-2 py-1 text-[11px] font-semibold bg-amber-100 border border-amber-300 text-amber-900 rounded-full hover:bg-amber-200 transition-colors"
        >
          {busy ? <Loader2 className="w-3 h-3 animate-spin" /> : <X className="w-3 h-3" />} Zurückziehen
        </button>
      )
    }
    return (
      <button
        type="button"
        disabled={busy}
        onClick={() => { update({ reserved_for: currentUserId }); toast.success('Reserviert – der Anbieter wird informiert') }}
        className="inline-flex items-center gap-1 px-2 py-1 text-[11px] font-semibold border border-amber-300 text-amber-800 rounded-full hover:bg-amber-50 transition-colors"
      >
        {busy ? <Loader2 className="w-3 h-3 animate-spin" /> : <Bookmark className="w-3 h-3" />} Reservieren
      </button>
    )
  }

  // Owner view
  if (!reservedFor) return null
  return (
    <div className="flex items-center gap-1">
      <span className="inline-flex items-center gap-1 px-2 py-1 text-[11px] font-semibold bg-amber-50 border border-amber-200 text-amber-800 rounded-full">
        <Bookmark className="w-3 h-3" /> Reserviert
      </span>
      <button
        type="button"
        disabled={busy}
        onClick={() => { update({ reserved_for: null }); toast.success('Reservierung aufgehoben') }}
        className="p-1 text-gray-400 hover:text-red-600 transition-colors"
        aria-label="Reservierung aufheben"
      >
        <X className="w-3 h-3" />
      </button>
      <button
        type="button"
        disabled={busy}
        onClick={() => { update({ status: 'claimed', reserved_for: null }); toast.success('Als vergeben markiert') }}
        className="p-1 text-gray-400 hover:text-green-700 transition-colors"
        aria-label="Als vergeben markieren"
      >
        <Check className="w-3 h-3" />
      </button>
    </div>
  )
}
