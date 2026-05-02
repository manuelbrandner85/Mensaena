// FIX-43: Foreground Service für Hintergrund-Anrufe
// FIX-96: Lazy-Import verhindert TDZ-Crash bei Chunk-Race
// Capacitor wird nur innerhalb der Funktionen gebraucht.

// FIX-96: Synchroner Check über globales Capacitor-Objekt – kein Import nötig
function isNativeAndroid(): boolean {
  try {
    const w = globalThis as unknown as { Capacitor?: { isNativePlatform: () => boolean; getPlatform: () => string } }
    return !!w.Capacitor?.isNativePlatform() && w.Capacitor.getPlatform() === 'android'
  } catch { return false }
}

interface CallForegroundOptions {
  partnerName: string
  callType: 'audio' | 'video'
  onHangupFromNotification?: () => void
}

let serviceRunning = false
let listenerCleanup: (() => void) | null = null

export async function startCallForegroundService(
  options: CallForegroundOptions
): Promise<void> {
  if (!isNativeAndroid()) return // FIX-96
  if (serviceRunning) return
  try {
    const { ForegroundService } = await import(
      '@capawesome-team/capacitor-android-foreground-service'
    )
    await ForegroundService.createNotificationChannel({
      id: 'mensaena-call',
      name: 'Anrufe',
      description: 'Benachrichtigung während eines laufenden Anrufs',
      importance: 3,
    })
    await ForegroundService.startForegroundService({
      id: 42,
      title: options.callType === 'video' ? '📹 Videoanruf' : '📞 Sprachanruf',
      body: `Anruf mit ${options.partnerName}`,
      smallIcon: 'ic_stat_call',
      buttons: [{ title: '🔴 Auflegen', id: 1 }],
      silent: true,
      notificationChannelId: 'mensaena-call',
    })
    serviceRunning = true
    const listener = await ForegroundService.addListener(
      'buttonClicked',
      (event) => {
        if (event.buttonId === 1 && options.onHangupFromNotification) {
          options.onHangupFromNotification()
        }
      }
    )
    listenerCleanup = () => { listener.remove() }
  } catch (err) {
    console.error('[CallForegroundService] Start fehlgeschlagen:', err)
  }
}

export async function updateCallForegroundService(
  durationFormatted: string,
  partnerName: string,
  callType: 'audio' | 'video',
): Promise<void> {
  if (!serviceRunning || !isNativeAndroid()) return // FIX-96
  try {
    const { ForegroundService } = await import(
      '@capawesome-team/capacitor-android-foreground-service'
    )
    await ForegroundService.updateForegroundService({
      id: 42,
      title: callType === 'video' ? '📹 Videoanruf' : '📞 Sprachanruf',
      body: `${partnerName} · ${durationFormatted}`,
      smallIcon: 'ic_stat_call',
    })
  } catch { /* Non-critical */ }
}

export async function stopCallForegroundService(): Promise<void> {
  if (!serviceRunning) return
  try {
    const { ForegroundService } = await import(
      '@capawesome-team/capacitor-android-foreground-service'
    )
    await ForegroundService.stopForegroundService()
  } catch { /* Non-critical */ } finally {
    serviceRunning = false
    if (listenerCleanup) { listenerCleanup(); listenerCleanup = null }
  }
}
