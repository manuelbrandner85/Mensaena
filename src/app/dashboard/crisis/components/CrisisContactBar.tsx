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
        <span className="inline-flex items-center gap-1 text-xs text-gray-600 bg-gray-50 px-2 py-1 rounded-lg border border-gray-100">
          <User className="w-3 h-3" />
          {crisis.contact_name}
        </span>
      )}
      {crisis.contact_phone && (
        <>
          <a
            href={`tel:${crisis.contact_phone.replace(/[\s\-()]/g, '')}`}
            className="inline-flex items-center gap-1 text-xs font-medium text-primary-700 bg-primary-50 px-2 py-1 rounded-lg border border-primary-200 hover:bg-primary-100 transition-colors"
            aria-label={`Anrufen: ${crisis.contact_phone}`}
          >
            <Phone className="w-3 h-3" />
            Anrufen
          </a>
          <a
            href={`https://wa.me/${crisis.contact_phone.replace(/[\s\-()+ ]/g, '')}`}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1 text-xs font-medium text-green-700 bg-green-50 px-2 py-1 rounded-lg border border-green-200 hover:bg-green-100 transition-colors"
            aria-label="WhatsApp schreiben"
          >
            <MessageCircle className="w-3 h-3" />
            WhatsApp
          </a>
        </>
      )}
      {crisis.location_text && (
        <span className="inline-flex items-center gap-1 text-xs text-gray-500 bg-gray-50 px-2 py-1 rounded-lg border border-gray-100">
          <MapPin className="w-3 h-3" />
          {crisis.location_text}
        </span>
      )}
    </div>
  )
}
