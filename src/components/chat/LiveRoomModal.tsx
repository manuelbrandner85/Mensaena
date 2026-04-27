'use client'

import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import {
  X, Video, ExternalLink, RefreshCw, AlertTriangle,
  Eye, MicOff, VideoOff, ShieldCheck, Loader2, LogOut,
} from 'lucide-react'
import { useModalDismiss } from '@/hooks/useModalDismiss'
import { Capacitor } from '@capacitor/core'
import { Jitsi } from 'capacitor-jitsi-meet'

const JITSI_DOMAIN = 'meet.ffmuc.net'

type PopupState = 'idle' | 'loading' | 'open' | 'closed' | 'blocked'

interface LiveRoomModalProps {
  roomName: string
  channelLabel: string
  userName: string
  userAvatar?: string | null
  onClose: () => void
}

export default function LiveRoomModal({
  roomName,
  channelLabel,
  userName,
  userAvatar,
  onClose,
}: LiveRoomModalProps) {
  const popupRef = useRef<Window | null>(null)
  const [state, setState] = useState<PopupState>('idle')
  const [isMobile, setIsMobile] = useState(false)
  const [isNative, setIsNative] = useState(false)
  const [mobileDetected, setMobileDetected] = useState(false)
  // CSS entrance animation
  const [visible, setVisible] = useState(false)

  useModalDismiss(onClose)

  const jitsiUrl = useMemo(() => {
    const base = `https://${JITSI_DOMAIN}/${encodeURIComponent(roomName)}`
    const config = [
      'config.startWithVideoMuted=true',
      'config.startWithAudioMuted=true',
      'config.prejoinPageEnabled=false',
      'config.enableWelcomePage=false',
      // enableClosePage=true: after hangup Jitsi shows close3.html which
      // calls window.close() and sends readyToClose to window.opener.
      // This closes the popup automatically and returns user to Mensaena.
      'config.enableClosePage=true',
      `userInfo.displayName=${encodeURIComponent(userName)}`,
      'config.readOnlyName=true',
      ...(userAvatar ? [`userInfo.avatarURL=${encodeURIComponent(userAvatar)}`] : []),
      `config.subject=${encodeURIComponent('Mensaena · ' + channelLabel)}`,
      'config.disableDeepLinking=true',
      'config.disableInviteFunctions=true',
      'config.disableThirdPartyRequests=true',
      'config.toolbarButtons=["microphone","camera","chat","participants-pane","tileview","fullscreen","hangup"]',
      'interfaceConfig.SHOW_JITSI_WATERMARK=false',
      'interfaceConfig.SHOW_WATERMARK_FOR_GUESTS=false',
      'interfaceConfig.SHOW_BRAND_WATERMARK=false',
      'interfaceConfig.DEFAULT_REMOTE_DISPLAY_NAME=Mitglied',
      'interfaceConfig.TOOLBAR_ALWAYS_VISIBLE=false',
      'interfaceConfig.MOBILE_APP_PROMO=false',
      'interfaceConfig.HIDE_INVITE_MORE_HEADER=true',
    ]
    return `${base}#${config.join('&')}`
  }, [roomName, userName, userAvatar, channelLabel])

  // Detect mobile + native platform after mount (avoids SSR mismatch)
  useEffect(() => {
    const small = window.matchMedia('(max-width: 768px)').matches
    const ua = /iPhone|iPad|iPod|Android/i.test(navigator.userAgent)
    setIsMobile(small || ua)
    setIsNative(Capacitor.isNativePlatform())
    setMobileDetected(true)
  }, [])

  // Native APK: listen for Jitsi conference lifecycle events
  useEffect(() => {
    if (!isNative) return
    const handleLeft = () => {
      setState('closed')
      onClose()
    }
    window.addEventListener('onConferenceLeft', handleLeft)
    window.addEventListener('onConferenceTerminated', handleLeft)
    return () => {
      window.removeEventListener('onConferenceLeft', handleLeft)
      window.removeEventListener('onConferenceTerminated', handleLeft)
    }
  }, [isNative, onClose])

  // Entrance animation — one frame delay for CSS to pick up transition
  useEffect(() => {
    const id = requestAnimationFrame(() => setVisible(true))
    return () => cancelAnimationFrame(id)
  }, [])

  const openLiveRoom = useCallback(async () => {
    setState('loading')

    // Native APK: launch the native Jitsi Meet SDK (no browser, fully in-app)
    if (isNative) {
      try {
        await Jitsi.joinConference({
          roomName,
          url: `https://${JITSI_DOMAIN}`,
          displayName: userName,
          avatarURL: userAvatar ?? undefined,
          startWithAudioMuted: true,
          startWithVideoMuted: true,
          featureFlags: {
            'prejoinpage.enabled': false,
            'recording.enabled': false,
            'live-streaming.enabled': false,
            'android.screensharing.enabled': false,
          },
          configOverrides: {
            subject: `Mensaena · ${channelLabel}`,
            disableDeepLinking: true,
            disableInviteFunctions: true,
          },
        })
        setState('open')
      } catch {
        setState('blocked')
      }
      return
    }

    // Mobile web browser: open in new tab (requires direct gesture on iOS)
    if (isMobile) {
      const tab = window.open(jitsiUrl, '_blank', 'noopener,noreferrer')
      if (!tab) {
        setState('blocked')
        return
      }
      setTimeout(() => setState(s => s === 'loading' ? 'open' : s), 3000)
      return
    }

    // Desktop: floating popup window
    const w = Math.min(1100, window.screen.availWidth - 80)
    const h = Math.min(760, window.screen.availHeight - 80)
    const left = Math.max(0, Math.round((window.screen.availWidth - w) / 2))
    const top  = Math.max(0, Math.round((window.screen.availHeight - h) / 2))
    const features = [
      'popup',
      `width=${Math.round(w)}`,
      `height=${Math.round(h)}`,
      `left=${left}`,
      `top=${top}`,
      'menubar=no',
      'toolbar=no',
      'location=no',
      'status=no',
      'resizable=yes',
      'scrollbars=no',
    ].join(',')

    const popup = window.open(jitsiUrl, 'mensaena-live-room', features)
    if (!popup || popup.closed) {
      setState('blocked')
      return
    }
    popupRef.current = popup
    popup.focus()
    setTimeout(() => setState(s => s === 'loading' ? 'open' : s), 2500)
  }, [isNative, roomName, userName, userAvatar, channelLabel, isMobile, jitsiUrl])

  // Auto-open on mount for desktop + native APK (wait until detection is done)
  useEffect(() => {
    if (!mobileDetected || state !== 'idle') return
    // Auto-open: desktop (web popup) OR native APK (native SDK)
    // Mobile web: user must click manually (iOS requires direct gesture)
    if (isNative || !isMobile) openLiveRoom()
  }, [mobileDetected, state, isNative, isMobile, openLiveRoom])

  // Monitor popup closure (desktop)
  useEffect(() => {
    if ((state !== 'open' && state !== 'loading') || isMobile) return
    const interval = setInterval(() => {
      if (popupRef.current?.closed) {
        popupRef.current = null
        setState('closed')
      }
    }, 800)
    return () => clearInterval(interval)
  }, [state, isMobile])

  // Jitsi sends readyToClose / videoConferenceLeft via postMessage to window.opener
  // on some self-hosted instances — catch it here and close the popup cleanly
  useEffect(() => {
    const handler = (e: MessageEvent) => {
      if (!e.data || typeof e.data !== 'object') return
      const evt = (e.data as { event?: string; type?: string }).event
               ?? (e.data as { event?: string; type?: string }).type
      if (evt === 'readyToClose' || evt === 'videoConferenceLeft') {
        try { popupRef.current?.close() } catch { /* cross-origin */ }
        popupRef.current = null
        setState('closed')
      }
    }
    window.addEventListener('message', handler)
    return () => window.removeEventListener('message', handler)
  }, [])

  // Close popup when modal unmounts
  useEffect(() => () => {
    try { popupRef.current?.close() } catch { /* cross-origin */ }
  }, [])

  // "Verlassen" — closes conference AND modal; user lands back in Community-Chat
  const handleLeave = useCallback(async () => {
    if (isNative) {
      try { await Jitsi.leaveConference() } catch { /* ignore */ }
      onClose()
      return
    }
    try { popupRef.current?.close() } catch { /* cross-origin */ }
    popupRef.current = null
    onClose()
  }, [isNative, onClose])

  // Focus existing popup or open a new one (Improvement D)
  const focusOrReopen = useCallback(() => {
    if (popupRef.current && !popupRef.current.closed) {
      popupRef.current.focus()
      return
    }
    openLiveRoom()
  }, [openLiveRoom])

  // ── Compact floating pill — shown while Live-Raum is active on desktop ───
  // Lets the user keep chatting while the live room runs in its own window
  if (state === 'open' && !isMobile) {
    return (
      <div
        className={[
          'fixed top-4 left-1/2 z-[70] -translate-x-1/2',
          'transition-all duration-300 ease-out',
          visible ? 'opacity-100 translate-y-0' : 'opacity-0 -translate-y-3',
        ].join(' ')}
      >
        <div className="flex items-center gap-2 pl-4 pr-2 py-2.5 bg-white rounded-2xl shadow-2xl border border-primary-100 shadow-primary-500/10">
          {/* Live dot */}
          <div className="relative w-2.5 h-2.5 flex-shrink-0">
            <div className="absolute inset-0 rounded-full bg-green-400 animate-ping opacity-60" />
            <div className="relative w-2.5 h-2.5 rounded-full bg-green-500" />
          </div>

          <Video className="w-4 h-4 text-primary-500 flex-shrink-0" />

          <span className="text-sm font-semibold text-ink-800 pr-1">
            {channelLabel}
            <span className="ml-2 text-xs font-normal text-ink-400">Live</span>
          </span>

          {/* Focus popup */}
          <button
            onClick={focusOrReopen}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-primary-50 hover:bg-primary-100 text-primary-600 text-xs font-semibold transition-all"
            title="Popup-Fenster in den Vordergrund holen"
          >
            <Eye className="w-3.5 h-3.5" />
            <span className="hidden sm:inline">Fokussieren</span>
          </button>

          {/* Leave — closes popup and returns user to chat */}
          <button
            onClick={handleLeave}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-red-50 hover:bg-red-100 text-red-600 text-xs font-semibold transition-all"
            title="Live-Raum verlassen und zum Chat zurückkehren"
          >
            <LogOut className="w-3.5 h-3.5" />
            <span className="hidden sm:inline">Verlassen</span>
          </button>

          {/* Dismiss pill only (popup keeps running) */}
          <button
            onClick={onClose}
            className="w-8 h-8 flex items-center justify-center rounded-xl hover:bg-stone-100 text-ink-400 hover:text-ink-600 transition-all"
            title="Leiste ausblenden (Raum läuft weiter)"
          >
            <X className="w-3.5 h-3.5" />
          </button>
        </div>
      </div>
    )
  }

  // ── Full modal — shown on mobile + all non-open desktop states ────────────
  return (
    <div
      className={[
        'fixed inset-0 z-[70] bg-black/70 backdrop-blur-md',
        'flex items-center justify-center p-4 pb-[env(safe-area-inset-bottom)]',
        'transition-opacity duration-200',
        visible ? 'opacity-100' : 'opacity-0',
      ].join(' ')}
    >
      <div
        className={[
          'relative w-full max-w-md bg-white rounded-3xl shadow-2xl shadow-primary-900/20 overflow-hidden',
          'transition-all duration-300 ease-out',
          visible ? 'scale-100 translate-y-0' : 'scale-95 translate-y-3',
        ].join(' ')}
      >
        {/* ── Header ───────────────────────────────────────────────────────── */}
        <div className="flex items-center justify-between gap-2 px-5 py-4 bg-gradient-to-r from-primary-600 to-primary-500">
          <div className="flex items-center gap-3 min-w-0">
            <div className="w-10 h-10 rounded-2xl bg-white/20 border border-white/20 flex items-center justify-center flex-shrink-0">
              <Video className="w-5 h-5 text-white" />
            </div>
            <div className="min-w-0">
              <p className="text-sm font-bold text-white">Live-Raum</p>
              <p className="text-xs text-white/70 truncate">{channelLabel}</p>
            </div>
          </div>
          <button
            onClick={state === 'open' ? handleLeave : onClose}
            className="w-10 h-10 flex items-center justify-center rounded-xl bg-white/15 hover:bg-white/25 text-white transition-all flex-shrink-0"
            aria-label="Schließen"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* ── Status body ──────────────────────────────────────────────────── */}
        <div className="px-6 py-7">
          <div className="flex flex-col items-center text-center gap-4">

            {/* idle */}
            {state === 'idle' && (
              <>
                <Loader2 className="w-12 h-12 text-primary-300 animate-spin" />
                <p className="text-sm text-ink-500">Einen Moment…</p>
              </>
            )}

            {/* loading */}
            {state === 'loading' && (
              <>
                <div className="relative">
                  <div className="w-16 h-16 rounded-2xl bg-primary-50 border border-primary-100 flex items-center justify-center">
                    <Video className="w-8 h-8 text-primary-400" />
                  </div>
                  <div className="absolute -bottom-1.5 -right-1.5 w-7 h-7 rounded-full bg-white border border-stone-100 flex items-center justify-center shadow-sm">
                    <Loader2 className="w-4 h-4 text-primary-500 animate-spin" />
                  </div>
                </div>
                <div>
                  <p className="text-base font-bold text-ink-900 mb-1">Live-Raum wird aufgebaut…</p>
                  <p className="text-sm text-ink-500 max-w-xs leading-relaxed">
                    {isNative
                      ? 'Der Live-Raum wird direkt in der App geöffnet…'
                      : isMobile
                        ? 'Der Raum wurde in einem neuen Tab geöffnet.'
                        : 'Das Popup-Fenster öffnet sich — Jitsi braucht einen Moment zum Laden.'}
                  </p>
                </div>
              </>
            )}

            {/* open (mobile only — desktop shows pill) */}
            {state === 'open' && isMobile && (
              <>
                <div className="relative w-16 h-16">
                  <div className="absolute inset-0 rounded-full bg-green-400/20 animate-ping" />
                  <div className="relative w-16 h-16 rounded-full bg-green-50 border border-green-100 flex items-center justify-center">
                    <Video className="w-8 h-8 text-green-600" />
                  </div>
                </div>
                <div>
                  <p className="text-base font-bold text-ink-900 mb-1">Du bist im Live-Raum</p>
                  <p className="text-sm text-ink-500 max-w-xs leading-relaxed">
                    Der Raum läuft in einem neuen Browser-Tab.
                  </p>
                </div>
              </>
            )}

            {/* closed */}
            {state === 'closed' && (
              <>
                <div className="w-16 h-16 rounded-full bg-stone-50 border border-stone-200 flex items-center justify-center">
                  <VideoOff className="w-8 h-8 text-stone-400" />
                </div>
                <div>
                  <p className="text-base font-bold text-ink-900 mb-1">Live-Raum wurde beendet</p>
                  <p className="text-sm text-ink-500 max-w-xs leading-relaxed">Du kannst jederzeit wieder beitreten.</p>
                </div>
              </>
            )}

            {/* blocked */}
            {state === 'blocked' && (
              <>
                <div className="w-16 h-16 rounded-full bg-amber-50 border border-amber-200 flex items-center justify-center">
                  <AlertTriangle className="w-8 h-8 text-amber-500" />
                </div>
                <div>
                  <p className="text-base font-bold text-ink-900 mb-1">Popup blockiert</p>
                  <p className="text-sm text-ink-500 max-w-xs leading-relaxed">
                    Dein Browser hat das Popup verhindert. Bitte erlaube Popups für mensaena.de — oder öffne den Raum direkt im Browser.
                  </p>
                </div>
              </>
            )}
          </div>

          {/* ── Action buttons ─────────────────────────────────────────────── */}
          <div className="mt-6 space-y-2.5">

            {/* Mobile: open live room (requires direct gesture) */}
            {(state === 'idle' || state === 'blocked') && isMobile && (
              <button
                onClick={openLiveRoom}
                className="w-full flex items-center justify-center gap-2 px-5 py-3 rounded-2xl bg-gradient-to-r from-primary-500 to-primary-600 hover:from-primary-600 hover:to-primary-700 text-white text-sm font-bold shadow-lg shadow-primary-500/20 transition-all min-h-[48px]"
              >
                <Video className="w-4 h-4" />
                Live-Raum öffnen
              </button>
            )}

            {/* Rejoin after close */}
            {state === 'closed' && (
              <button
                onClick={openLiveRoom}
                className="w-full flex items-center justify-center gap-2 px-5 py-3 rounded-2xl bg-gradient-to-r from-primary-500 to-primary-600 hover:from-primary-600 hover:to-primary-700 text-white text-sm font-bold shadow-lg shadow-primary-500/20 transition-all min-h-[48px]"
              >
                <RefreshCw className="w-4 h-4" />
                Wieder beitreten
              </button>
            )}

            {/* Focus popup (mobile: switch to tab) */}
            {state === 'open' && isMobile && (
              <a
                href={jitsiUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="w-full flex items-center justify-center gap-2 px-5 py-3 rounded-2xl bg-gradient-to-r from-primary-500 to-primary-600 hover:from-primary-600 hover:to-primary-700 text-white text-sm font-bold shadow-lg shadow-primary-500/20 transition-all min-h-[48px]"
              >
                <ExternalLink className="w-4 h-4" />
                Zum Live-Raum-Tab
              </a>
            )}

            {/* Leave — closes popup and returns to chat */}
            {(state === 'open' || state === 'loading') && (
              <button
                onClick={handleLeave}
                className="w-full flex items-center justify-center gap-2 px-5 py-3 rounded-2xl bg-red-50 hover:bg-red-100 text-red-600 text-sm font-bold border border-red-100 transition-all min-h-[48px]"
              >
                <LogOut className="w-4 h-4" />
                Verlassen & zurück zum Chat
              </button>
            )}

            {/* Always-visible tab fallback */}
            {(state === 'closed' || state === 'blocked' || (state === 'open' && isMobile)) && (
              <a
                href={jitsiUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="w-full flex items-center justify-center gap-2 px-5 py-3 rounded-2xl bg-stone-100 hover:bg-stone-200 text-ink-600 text-sm font-medium transition-all min-h-[48px]"
              >
                <ExternalLink className="w-4 h-4" />
                In neuem Tab öffnen
              </a>
            )}
          </div>
        </div>

        {/* ── Footer hints ─────────────────────────────────────────────────── */}
        <div className="border-t border-stone-100 bg-stone-50/60 px-6 py-3 grid grid-cols-3 gap-2">
          <FooterHint icon={<MicOff className="w-3.5 h-3.5" />} text="Mikrofon stumm" />
          <FooterHint icon={<VideoOff className="w-3.5 h-3.5" />} text="Kamera aus" />
          <FooterHint icon={<ShieldCheck className="w-3.5 h-3.5" />} text="Kein Login" />
        </div>

        {/* Identity strip */}
        <div className="px-6 py-3 bg-white border-t border-stone-100 flex items-center gap-2">
          <div className="w-1.5 h-1.5 rounded-full bg-primary-400 flex-shrink-0" />
          <p className="text-[11px] text-ink-500 truncate">
            Du trittst als <strong className="text-ink-700">{userName}</strong> bei
          </p>
        </div>
      </div>
    </div>
  )
}

function FooterHint({ icon, text }: { icon: React.ReactNode; text: string }) {
  return (
    <div className="flex items-center justify-center gap-1.5 text-[11px] text-ink-500">
      <span className="text-ink-400">{icon}</span>
      <span>{text}</span>
    </div>
  )
}
