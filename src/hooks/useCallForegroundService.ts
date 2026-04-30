// FIX-43: Foreground Service für Hintergrund-Anrufe
import { Capacitor } from '@capacitor/core'

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
  if (!Capacitor.isNativePlatform() || Capacitor.getPlatform() !== 'android') return
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
  if (!serviceRunning || !Capacitor.isNativePlatform()) return
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
