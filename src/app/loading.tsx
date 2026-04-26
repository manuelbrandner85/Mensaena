export default function Loading() {
  return (
    <div
      className="min-h-screen flex items-center justify-center bg-background"
      role="status"
    >
      <div className="flex flex-col items-center gap-4">
        <div
          className="w-10 h-10 border-[3px] border-primary-200 border-t-primary-600 rounded-full animate-spin"
          aria-hidden="true"
        />
        <p className="text-sm text-ink-400 animate-pulse">Laden…</p>
        <span className="sr-only">Seite wird geladen</span>
      </div>
    </div>
  )
}
