'use client'

interface Props {
  label: string
}

export default function NotificationGroupHeader({ label }: Props) {
  return (
    <div className="flex items-center gap-3 px-4 py-2.5 bg-stone-50/80 sticky top-0 z-10 border-b border-stone-100">
      <span className="text-[11px] font-semibold text-ink-400 uppercase tracking-widest">
        {label}
      </span>
      <div className="flex-1 h-px bg-stone-200" />
    </div>
  )
}
