'use client'

import { Search, X } from 'lucide-react'
import { useRef } from 'react'

interface BoardSearchProps {
  value: string
  onChange: (val: string) => void
}

export default function BoardSearch({ value, onChange }: BoardSearchProps) {
  const inputRef = useRef<HTMLInputElement>(null)

  return (
    <div className="relative">
      <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-ink-400" />
      <input
        ref={inputRef}
        type="text"
        placeholder="Aushänge durchsuchen..."
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="w-full pl-9 pr-8 py-2 rounded-lg border border-stone-200 bg-white text-sm
                   placeholder:text-ink-400 focus:outline-none focus:ring-2 focus:ring-primary-500
                   focus:border-transparent transition"
      />
      {value && (
        <button
          type="button"
          onClick={() => {
            onChange('')
            inputRef.current?.focus()
          }}
          className="absolute right-2 top-1/2 -translate-y-1/2 p-1 rounded-full hover:bg-stone-100"
        >
          <X className="w-3.5 h-3.5 text-ink-400" />
        </button>
      )}
    </div>
  )
}
