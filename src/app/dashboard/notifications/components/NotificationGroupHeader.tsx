'use client'

interface Props {
  label: string
}

export default function NotificationGroupHeader({ label }: Props) {
  return (
    <div className="px-4 py-2 bg-gray-50 text-xs font-semibold text-gray-500 uppercase tracking-wider sticky top-0 z-10">
      {label}
    </div>
  )
}
