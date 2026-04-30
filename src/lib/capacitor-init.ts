// UPDATE-SYSTEM: Capacitor-Native-Initialisierung beim App-Start
import { Capacitor } from '@capacitor/core'
import { App } from '@capacitor/app'
import { SplashScreen } from '@capacitor/splash-screen'
import { StatusBar, Style } from '@capacitor/status-bar'
import { Keyboard, KeyboardResize } from '@capacitor/keyboard'

export async function initCapacitor(): Promise<void> {
  if (!Capacitor.isNativePlatform()) return

  try {
    await SplashScreen.hide()
  } catch {}

  try {
    await StatusBar.setStyle({ style: Style.Light })
    await StatusBar.setBackgroundColor({ color: '#1EAAA6' })
  } catch {}

  try {
    await Keyboard.setResizeMode({ mode: KeyboardResize.Body })
  } catch {}

  // APK-Version für useAppContext in localStorage sichern
  try {
    const info = await App.getInfo()
    localStorage.setItem('mensaena_apk_version', info.version)
    localStorage.setItem('mensaena_apk_build', info.build)
  } catch {}
}
