// UPDATE-SYSTEM: Capacitor-Native-Initialisierung beim App-Start
// FIX-96: Alle Capacitor-Imports dynamisch – verhindert TDZ bei SSR/Chunk-Race

export async function initCapacitor(): Promise<void> {
  // FIX-96: Synchroner Quick-Check ohne Import via globales Capacitor-Objekt
  const w = globalThis as unknown as { Capacitor?: { isNativePlatform: () => boolean } }
  if (!w.Capacitor?.isNativePlatform()) return

  try {
    const { SplashScreen } = await import('@capacitor/splash-screen')
    await SplashScreen.hide()
  } catch {}

  try {
    const { StatusBar, Style } = await import('@capacitor/status-bar')
    await StatusBar.setStyle({ style: Style.Light })
    await StatusBar.setBackgroundColor({ color: '#1EAAA6' })
  } catch {}

  try {
    const { Keyboard, KeyboardResize } = await import('@capacitor/keyboard')
    await Keyboard.setResizeMode({ mode: KeyboardResize.Body })
  } catch {}

  // APK-Version für useAppContext in localStorage sichern
  try {
    const { App } = await import('@capacitor/app')
    const info = await App.getInfo()
    localStorage.setItem('mensaena_apk_version', info.version)
    localStorage.setItem('mensaena_apk_build', info.build)
  } catch {}
}
