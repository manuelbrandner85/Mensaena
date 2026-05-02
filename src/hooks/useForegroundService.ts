// Foreground-Service für Android — verhindert App-Kill während Anruf/Livestream.
// Startet beim Mount, stoppt beim Unmount. Kein Neustart bei Reconnects.

function isAndroid(): boolean {
  try {
    const w = globalThis as unknown as { Capacitor?: { isNativePlatform: () => boolean; getPlatform: () => string } }
    return !!w.Capacitor?.isNativePlatform() && w.Capacitor.getPlatform() === 'android'
  } catch { return false }
}

let running = false
let timerInterval: ReturnType<typeof setInterval> | null = null
let startedAt: number | null = null
let onHangupCb: (() => void) | null = null
let listenerHandle: { remove: () => void } | null = null

async function getForegroundService() {
  const { ForegroundService } = await import('@capawesome-team/capacitor-android-foreground-service')
  return ForegroundService
}

export async function startForegroundService(opts: {
  title: string
  onHangup?: () => void
}): Promise<void> {
  if (!isAndroid() || running) return
  running = true
  startedAt = Date.now()
  onHangupCb = opts.onHangup ?? null
  try {
    const svc = await getForegroundService()
    await svc.createNotificationChannel({
      id: 'mensaena-call',
      name: 'Anrufe',
      description: 'Aktiver Anruf',
      importance: 3,
    })
    await svc.startForegroundService({
      id: 42,
      title: opts.title,
      body: 'Verbunden…',
      smallIcon: 'ic_stat_call',
      buttons: [{ title: '🔴 Auflegen', id: 1 }],
      silent: true,
      notificationChannelId: 'mensaena-call',
    })
    listenerHandle = await svc.addListener('buttonClicked', (ev) => {
      if (ev.buttonId === 1) onHangupCb?.()
    })
    timerInterval = setInterval(async () => {
      if (!running || !startedAt) return
      const elapsed = Math.floor((Date.now() - startedAt) / 1000)
      const m = String(Math.floor(elapsed / 60)).padStart(2, '0')
      const s = String(elapsed % 60).padStart(2, '0')
      try {
        const s2 = await getForegroundService()
        await s2.updateForegroundService({ id: 42, title: opts.title, body: `${m}:${s}`, smallIcon: 'ic_stat_call' })
      } catch { /* non-critical */ }
    }, 15_000)
  } catch (e) {
    running = false
    console.error('[ForegroundService] Start failed:', e)
  }
}

export async function stopForegroundService(): Promise<void> {
  if (!running) return
  running = false
  startedAt = null
  onHangupCb = null
  if (timerInterval) { clearInterval(timerInterval); timerInterval = null }
  if (listenerHandle) { listenerHandle.remove(); listenerHandle = null }
  try {
    const svc = await getForegroundService()
    await svc.stopForegroundService()
  } catch { /* non-critical */ }
}
