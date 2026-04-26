'use client'

import Link from 'next/link'
import { ShieldCheck, Plus } from 'lucide-react'

interface Props {
  showCreate?: boolean
}

export default function CrisisEmptyState({ showCreate = true }: Props) {
  return (
    <div className="text-center py-16 px-4" role="status">
      <div className="w-20 h-20 rounded-full bg-green-100 flex items-center justify-center mx-auto mb-4">
        <ShieldCheck className="w-10 h-10 text-green-600" />
      </div>
      <h3 className="text-lg font-bold text-ink-800 mb-2">
        Alles sicher - keine aktiven Krisen
      </h3>
      <p className="text-sm text-ink-500 max-w-sm mx-auto mb-6">
        Aktuell sind keine Krisen oder Notfälle in deiner Umgebung gemeldet. Das ist gut so!
      </p>
      {showCreate && (
        <Link
          href="/dashboard/crisis/create"
          className="inline-flex items-center gap-2 px-5 py-2.5 bg-red-600 text-white rounded-xl font-semibold text-sm hover:bg-red-700 transition-colors shadow-lg shadow-red-200"
        >
          <Plus className="w-4 h-4" />
          Krise melden
        </Link>
      )}
    </div>
  )
}
