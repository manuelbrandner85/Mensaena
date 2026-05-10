export default function Loading() {
  return (
    <div
      className="min-h-dvh relative flex items-center justify-center bg-paper overflow-hidden"
      role="status"
    >
      <div
        className="hero-orb-1 absolute pointer-events-none"
        style={{ top: '-20%', left: '-10%', width: '50vw', height: '50vw' }}
        aria-hidden="true"
      />
      <div
        className="hero-orb-2 absolute pointer-events-none"
        style={{ bottom: '-15%', right: '-10%', width: '45vw', height: '45vw' }}
        aria-hidden="true"
      />
      <div className="relative flex flex-col items-center gap-4">
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
