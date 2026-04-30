'use client'

// UPDATE-SYSTEM: Erkennt ob die App im Browser, als PWA oder als Capacitor-App läuft
import { useState, useEffect } from 'react'
import { Capacitor } from '@capacitor/core'
import { App } from '@capacitor/app'

type AppRuntime = 'browser' | 'pwa' | 'capacitor'

export interface AppContextState {
  runtime: AppRuntime
  isNative: boolean
  installedApkVersion: string | null
  installedApkBuildCode: number | null
  platform: 'web' | 'android' | 'ios'
}

const defaultState: AppContextState = {
  runtime: 'browser',
  isNative: false,
  installedApkVersion: null,
  installedApkBuildCode: null,
  platform: 'web',
}

export function useAppContext(): AppContextState {
  const [state, setState] = useState<AppContextState>(defaultState)

  useEffect(() => {
    async function detect() {
      const isNative = Capacitor.isNativePlatform()
      const platform = Capacitor.getPlatform() as 'web' | 'android' | 'ios'

      if (isNative) {
        let installedApkVersion: string | null = null
        let installedApkBuildCode: number | null = null
        try {
          const info = await App.getInfo()
          installedApkVersion = info.version
          installedApkBuildCode = parseInt(info.build, 10)
          // Auch in localStorage sichern (für capacitor-init.ts)
          localStorage.setItem('mensaena_apk_version', info.version)
          localStorage.setItem('mensaena_apk_build', info.build)
        } catch {}
        setState({ runtime: 'capacitor', isNative: true, installedApkVersion, installedApkBuildCode, platform })
      } else if (
        typeof window !== 'undefined' &&
        window.matchMedia('(display-mode: standalone)').matches
      ) {
        setState({ runtime: 'pwa', isNative: false, installedApkVersion: null, installedApkBuildCode: null, platform })
      } else {
        setState({ runtime: 'browser', isNative: false, installedApkVersion: null, installedApkBuildCode: null, platform })
      }
    }
    detect()
  }, [])

  return state
}
