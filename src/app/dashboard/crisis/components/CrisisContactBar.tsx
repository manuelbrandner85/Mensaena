'use client'

import { Phone, MessageCircle, MapPin, User } from 'lucide-react'
import { cn } from '@/lib/utils'
import type { Crisis } from '../types'

interface Props {
  crisis: Crisis
  className?: string
}

export default function CrisisContactBar({ crisis, className }: Props) {
  if (crisis.is_anonymous && !crisis.contact_phone) return null

  return (
    <div className={cn('flex flex-wrap items-center gap-2', className)}>
      {crisis.contact_name && !crisis.is_anonymous && (
        <span className="inline-flex items-center gap-1 text-xs text-mn-ink-soft bg-mn-surface px-2 py-1 rounded-lg border border-white/5">
          <User className="w-3 h-3" />
          {crisis.contact_name}
        </span>
      )}
      {crisis.contact_phone && (
        <>
          <a
            href={`tel:${crisis.contact_phone.replace(/[\s\-()]/g, '')}`}
            className="inline-flex items-center gap-1 text-xs font-medium text-mn-amber bg-mn-amber/5 px-2 py-1 rounded-lg border border-mn-amber/20 hover:bg-mn-amber/10 transition-colors"
            aria-label={`Anrufen: ${crisis.contact_phone}`}
          >
            <Phone className="w-3 h-3" />
            Anrufen
          </a>
          <a
            href={`https://wa.me/${crisis.contact_phone.replace(/[\s\-()+ ]/g, '')}`}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1 text-xs font-medium text-mn-leben bg-mn-surface px-2 py-1 rounded-lg border border-white/5 hover:bg-mn-elevated transition-colors"
            aria-label="WhatsApp schreiben"
          >
            <MessageCircle className="w-3 h-3" />
            WhatsApp
          </a>
        </>
      )}
      {crisis.location_text && (
        <span className="inline-flex items-center gap-1 text-xs text-mn-mute bg-mn-surface px-2 py-1 rounded-lg border border-white/5">
          <MapPin className="w-3 h-3" />
          {crisis.location_text}
        </span>
      )}
    </div>
  )
}
