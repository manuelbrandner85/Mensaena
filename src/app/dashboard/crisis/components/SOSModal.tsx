'use client'

import { useEffect, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import Link from 'next/link'
import { X, Phone, Siren, AlertTriangle, Heart, ShieldCheck } from 'lucide-react'
import { cn } from '@/lib/utils'
import QuickHelpNumbers from './QuickHelpNumbers'

interface Props {
  isOpen: boolean
  onClose: () => void
}

export default function SOSModal({ isOpen, onClose }: Props) {
  const overlayRef = useRef<HTMLDivElement>(null)
  const firstFocusRef = useRef<HTMLAnchorElement>(null)
  const [mounted, setMounted] = useState(false)

  // Ensure we only use createPortal on the client
  useEffect(() => { setMounted(true) }, [])

  // Focus trap
  useEffect(() => {
    if (!isOpen) return
    const timeout = setTimeout(() => firstFocusRef.current?.focus(), 100)
    return () => clearTimeout(timeout)
  }, [isOpen])

  // Escape key
  useEffect(() => {
    if (!isOpen) return
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    document.addEventListener('keydown', handleKey)
    return () => document.removeEventListener('keydown', handleKey)
  }, [isOpen, onClose])

  // Prevent body scroll
  useEffect(() => {
    if (isOpen) {
      document.body.style.overflow = 'hidden'
    } else {
      document.body.style.overflow = ''
    }
    return () => { document.body.style.overflow = '' }
  }, [isOpen])

  if (!isOpen || !mounted) return null

  return createPortal(
    <div
      ref={overlayRef}
      className="fixed inset-0 z-[60] flex items-end sm:items-center justify-center"
      role="dialog"
      aria-modal="true"
      aria-label="SOS Notruf"
    >
      {/* Backdrop – clicking it closes the modal */}
      <div
        className="absolute inset-0 bg-black/60 backdrop-blur-sm"
        aria-hidden="true"
        onClick={onClose}
      />

      {/* Modal */}
      <div className="relative w-full sm:max-w-md bg-white rounded-t-3xl sm:rounded-3xl max-h-[90dvh] overflow-y-auto animate-slide-up z-10">
        {/* Header */}
        <div className="sticky top-0 bg-red-600 px-4 py-4 sm:rounded-t-3xl z-10">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Siren className="w-6 h-6 text-white" />
              <h2 className="text-lg font-bold text-white">SOS - Soforthilfe</h2>
            </div>
            <button
              onClick={(e) => { e.stopPropagation(); onClose() }}
              className="w-9 h-9 rounded-full bg-white/20 flex items-center justify-center hover:bg-white/40 active:bg-white/50 transition-colors touch-target"
              aria-label="Schließen"
            >
              <X className="w-5 h-5 text-white" strokeWidth={3} />
            </button>
          </div>
        </div>

        <div className="p-4 space-y-4">
          {/* Emergency call 112 */}
          <a
            ref={firstFocusRef}
            href="tel:112"
            className="flex items-center gap-3 p-4 bg-red-50 border-2 border-red-300 rounded-2xl hover:bg-red-100 transition-colors group"
            aria-label="Notruf 112 anrufen"
          >
            <div className="w-14 h-14 rounded-full bg-red-600 flex items-center justify-center flex-shrink-0 group-hover:scale-110 transition-transform">
              <Phone className="w-7 h-7 text-white" />
            </div>
            <div>
              <p className="text-lg font-black text-red-700">112 anrufen</p>
              <p className="text-xs text-red-600">EU-weit kostenlos, 24/7 - Feuerwehr & Rettung</p>
            </div>
          </a>

          {/* Polizei */}
          <a
            href="tel:110"
            className="flex items-center gap-3 p-3 bg-blue-50 border border-blue-200 rounded-2xl hover:bg-blue-100 transition-colors"
          >
            <div className="w-10 h-10 rounded-full bg-blue-600 flex items-center justify-center flex-shrink-0">
              <ShieldCheck className="w-5 h-5 text-white" />
            </div>
            <div>
              <p className="text-sm font-bold text-blue-700">Polizei: 110</p>
              <p className="text-xs text-blue-600">Deutschlandweit kostenlos, 24/7</p>
            </div>
          </a>

          {/* Report crisis */}
          <Link
            href="/dashboard/crisis/create"
            onClick={onClose}
            className="flex items-center gap-3 p-3 bg-orange-50 border border-orange-200 rounded-2xl hover:bg-orange-100 transition-colors"
          >
            <div className="w-10 h-10 rounded-full bg-orange-500 flex items-center justify-center flex-shrink-0">
              <AlertTriangle className="w-5 h-5 text-white" />
            </div>
            <div>
              <p className="text-sm font-bold text-orange-700">Krise melden</p>
              <p className="text-xs text-orange-600">Nachbarn mobilisieren und Hilfe koordinieren</p>
            </div>
          </Link>

          {/* Telefonseelsorge */}
          <a
            href="tel:08001110111"
            className="flex items-center gap-3 p-3 bg-cyan-50 border border-cyan-200 rounded-2xl hover:bg-cyan-100 transition-colors"
          >
            <div className="w-10 h-10 rounded-full bg-cyan-500 flex items-center justify-center flex-shrink-0">
              <Heart className="w-5 h-5 text-white" />
            </div>
            <div>
              <p className="text-sm font-bold text-cyan-700">TelefonSeelsorge: 0800 111 0 111</p>
              <p className="text-xs text-cyan-600">Kostenlos, anonym, 24/7</p>
            </div>
          </a>

          {/* Full emergency numbers */}
          <div className="pt-2">
            <QuickHelpNumbers compact={false} />
          </div>

          {/* Disclaimer */}
          <p className="text-xs text-ink-400 text-center px-4 pb-2">
            Bei akuter Lebensgefahr immer zuerst 112 anrufen!
          </p>
        </div>
      </div>
    </div>,
    document.body,
  )
}
