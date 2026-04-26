'use client'

import { cn } from '@/lib/utils'
import type { BoardColor } from '../hooks/useBoard'
import { COLOR_MAP } from '../hooks/useBoard'

interface PinColorPickerProps {
  value: BoardColor
  onChange: (color: BoardColor) => void
}

const COLORS: BoardColor[] = ['yellow', 'green', 'blue', 'pink', 'orange', 'purple']

const COLOR_LABELS: Record<BoardColor, string> = {
  yellow: 'Gelb',
  green: 'Grün',
  blue: 'Blau',
  pink: 'Rosa',
  orange: 'Orange',
  purple: 'Lila',
}

const COLOR_SWATCHES: Record<BoardColor, string> = {
  yellow: 'bg-yellow-400',
  green: 'bg-green-400',
  blue: 'bg-blue-400',
  pink: 'bg-pink-400',
  orange: 'bg-orange-400',
  purple: 'bg-purple-400',
}

export default function PinColorPicker({ value, onChange }: PinColorPickerProps) {
  return (
    <div className="flex items-center gap-2">
      <span className="text-sm text-ink-600 mr-1">Farbe:</span>
      {COLORS.map((c) => (
        <button
          key={c}
          type="button"
          onClick={() => onChange(c)}
          title={COLOR_LABELS[c]}
          className={cn(
            'w-7 h-7 rounded-full border-2 transition-all duration-150 hover:scale-110',
            COLOR_SWATCHES[c],
            value === c
              ? 'border-ink-800 ring-2 ring-stone-400 scale-110'
              : 'border-transparent',
          )}
          aria-label={COLOR_LABELS[c]}
        />
      ))}
    </div>
  )
}
