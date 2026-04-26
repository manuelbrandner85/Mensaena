'use client'

import { cn } from '@/lib/design-system'

export interface SliderProps {
  value: number
  onChange: (value: number) => void
  min?: number
  max?: number
  step?: number
  label?: string
  showValue?: boolean
  suffix?: string
  disabled?: boolean
  className?: string
}

export default function Slider({
  value,
  onChange,
  min = 0,
  max = 100,
  step = 1,
  label,
  showValue = false,
  suffix = '',
  disabled = false,
  className,
}: SliderProps) {
  const percentage = ((value - min) / (max - min)) * 100

  return (
    <div className={cn('w-full', className)}>
      {(label || showValue) && (
        <div className="flex items-center justify-between mb-2">
          {label && <label className="text-sm font-medium text-ink-700">{label}</label>}
          {showValue && (
            <span className="text-sm font-semibold text-primary-600">
              {value}{suffix}
            </span>
          )}
        </div>
      )}
      <div className="relative">
        <input
          type="range"
          min={min}
          max={max}
          step={step}
          value={value}
          onChange={(e) => onChange(Number(e.target.value))}
          disabled={disabled}
          className={cn(
            'w-full h-2 rounded-full appearance-none cursor-pointer',
            'bg-stone-200 outline-none',
            '[&::-webkit-slider-thumb]:appearance-none',
            '[&::-webkit-slider-thumb]:w-5 [&::-webkit-slider-thumb]:h-5',
            '[&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:bg-primary-500',
            '[&::-webkit-slider-thumb]:shadow-sm [&::-webkit-slider-thumb]:cursor-pointer',
            '[&::-webkit-slider-thumb]:transition-transform [&::-webkit-slider-thumb]:duration-150',
            '[&::-webkit-slider-thumb]:hover:scale-110',
            '[&::-moz-range-thumb]:w-5 [&::-moz-range-thumb]:h-5',
            '[&::-moz-range-thumb]:rounded-full [&::-moz-range-thumb]:bg-primary-500',
            '[&::-moz-range-thumb]:border-none [&::-moz-range-thumb]:cursor-pointer',
            disabled && 'opacity-50 pointer-events-none',
          )}
          style={{
            background: `linear-gradient(to right, #1EAAA6 0%, #1EAAA6 ${percentage}%, #e5e7eb ${percentage}%, #e5e7eb 100%)`,
          }}
          aria-label={label}
          aria-valuenow={value}
          aria-valuemin={min}
          aria-valuemax={max}
        />
      </div>
    </div>
  )
}
