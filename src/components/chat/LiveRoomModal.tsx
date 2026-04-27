'use client'

import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import {
  X, Video, ExternalLink, Loader2, RefreshCw,
  AlertTriangle, Eye, Users, MicOff, VideoOff, ShieldCheck,
} from 'lucide-react'
import { useModalDismiss } from '@/hooks/useModalDismiss'

/**
 * Login-freier Jitsi-Server. Öffentliche Jitsi-Instanzen blockieren
 * iframe-Einbettung via X-Frame-Options. Wir umgehen das, indem wir
 * den Live-Raum in einem Popup-Fenster (Desktop) bzw. neuem Tab
 * (Mobile) öffnen — kein iframe nötig.
 */
const JITSI_DOMAIN = 'meet.ffmuc.net'

type PopupState = 'idle' | 'open' | 'closed' | 'blocked'

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

  useModalDismiss(onClose)

  /** Jitsi-URL mit allen Config-Params im Fragment */
  const jitsiUrl = useMemo(() => {
    const base = `https://${JITSI_DOMAIN}/${encodeURIComponent(roomName)}`
    const config = [
      'config.startWithVideoMuted=true',
      'config.startWithAudioMuted=true',
      'config.prejoinPageEnabled=false',
      'config.enableWelcomePage=false',
      'config.enableClosePage=false',
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

  // Geräteerkennung (nur clientseitig)
  useEffect(() => {
    const small = window.matchMedia('(max-width: 768px)').matches
    const ua = /iPhone|iPad|iPod|Android/i.test(navigator.userAgent)
    setIsMobile(small || ua)
  }, [])

  /** Live-Raum öffnen (Popup auf Desktop, neuer Tab auf Mobile) */
  const openLiveRoom = useCallback(() => {
    if (isMobile) {
      // Mobile: einfach neuer Tab — Popup-Features werden ignoriert
      const tab = window.open(jitsiUrl, '_blank', 'noopener,noreferrer')
      if (!tab) {
        setState('blocked')
        return
      }
      setState('open')
      return
    }

    // Desktop: schwebendes Popup-Fenster
    const w = Math.min(1100, window.screen.availWidth - 80)
    const h = Math.min(760, window.screen.availHeight - 80)
    const left = Math.max(0, (window.screen.availWidth - w) / 2)
    const top = Math.max(0, (window.screen.availHeight - h) / 2)
    const features = [
      'popup',
      `width=${Math.round(w)}`,
      `height=${Math.round(h)}`,
      `left=${Math.round(left)}`,
      `top=${Math.round(top)}`,
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
    setState('open')
  }, [isMobile, jitsiUrl])

  // Beim Mount: Popup direkt öffnen (Desktop) — auf Mobile wartet UI auf User-Klick,
  // weil iOS Safari neue Tabs nur im direkten User-Gesture-Kontext erlaubt
  useEffect(() => {
    if (state !== 'idle') return
    if (!isMobile) openLiveRoom()
    // mobile: User muss explizit auf Button klicken
  }, [state, isMobile, openLiveRoom])

  // Popup-Lifecycle überwachen
  useEffect(() => {
    if (state !== 'open' || isMobile) return
    const interval = setInterval(() => {
      if (popupRef.current?.closed) {
        popupRef.current = null
        setState('closed')
      }
    }, 800)
    return () => clearInterval(interval)
  }, [state, isMobile])

  // Aufräumen: wenn Modal geschlossen wird, auch Popup schließen
  useEffect(() => () => {
    try { popupRef.current?.close() } catch { /* cross-origin nach Navigation – ignorieren */ }
  }, [])

  /** Popup wieder fokussieren bzw. neu öffnen */
  const focusOrReopen = useCallback(() => {
    if (popupRef.current && !popupRef.current.closed) {
      popupRef.current.focus()
      return
    }
    openLiveRoom()
  }, [openLiveRoom])

  // ── Render ──────────────────────────────────────────────────────────────
  return (
    <div className="fixed inset-0 z-[70] bg-black/70 backdrop-blur-md flex items-center justify-center p-4 pb-[env(safe-area-inset-bottom)]">
      <div className="relative w-full max-w-md bg-white rounded-3xl shadow-2xl shadow-primary-900/30 overflow-hidden">
        {/* Header */}
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
            onClick={onClose}
            className="w-10 h-10 flex items-center justify-center rounded-xl bg-white/15 hover:bg-white/25 text-white transition-all flex-shrink-0"
            aria-label="Schließen"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Body — Status-abhängig */}
        <div className="px-6 py-7">
          {state === 'idle' && (
            <StatusBlock
              tone="primary"
              icon={<Loader2 className="w-9 h-9 text-primary-500 animate-spin" />}
              title="Live-Raum wird geöffnet…"
              description={isMobile
                ? 'Tippe auf den Button unten, um dem Raum beizutreten.'
                : 'Ein neues Fenster sollte sich gleich öffnen.'}
            />
          )}

          {state === 'open' && (
            <StatusBlock
              tone="success"
              icon={
                <div className="relative">
                  <div className="absolute inset-0 rounded-full bg-green-400/30 animate-ping" />
                  <div className="relative w-14 h-14 rounded-full bg-green-500/15 border border-green-400/40 flex items-center justify-center">
                    <Video className="w-7 h-7 text-green-600" />
                  </div>
                </div>
              }
              title="Du bist im Live-Raum"
              description={isMobile
                ? 'Der Raum läuft in einem neuen Browser-Tab. Wechsle dorthin, um teilzunehmen.'
                : 'Der Raum läuft in einem separaten Fenster. Klick darauf, um es in den Vordergrund zu holen.'}
            />
          )}

          {state === 'closed' && (
            <StatusBlock
              tone="muted"
              icon={
                <div className="w-14 h-14 rounded-full bg-stone-100 border border-stone-200 flex items-center justify-center">
                  <VideoOff className="w-7 h-7 text-stone-500" />
                </div>
              }
              title="Live-Raum wurde geschlossen"
              description="Du kannst jederzeit wieder beitreten."
            />
          )}

          {state === 'blocked' && (
            <StatusBlock
              tone="warning"
              icon={
                <div className="w-14 h-14 rounded-full bg-amber-50 border border-amber-200 flex items-center justify-center">
                  <AlertTriangle className="w-7 h-7 text-amber-600" />
                </div>
              }
              title="Popup wurde blockiert"
              description="Dein Browser hat das Popup-Fenster verhindert. Öffne den Raum in einem neuen Tab oder erlaube Popups für mensaena.de."
            />
          )}

          {/* Aktions-Buttons */}
          <div className="mt-7 space-y-2.5">
            {state === 'open' && !isMobile && (
              <button
                onClick={focusOrReopen}
                className="w-full flex items-center justify-center gap-2 px-5 py-3 rounded-2xl bg-gradient-to-r from-primary-500 to-primary-600 hover:from-primary-600 hover:to-primary-700 text-white text-sm font-bold shadow-lg shadow-primary-500/25 transition-all min-h-[48px]"
              >
                <Eye className="w-4 h-4" />
                Fenster in den Vordergrund holen
              </button>
            )}

            {state === 'open' && isMobile && (
              <a
                href={jitsiUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="w-full flex items-center justify-center gap-2 px-5 py-3 rounded-2xl bg-gradient-to-r from-primary-500 to-primary-600 hover:from-primary-600 hover:to-primary-700 text-white text-sm font-bold shadow-lg shadow-primary-500/25 transition-all min-h-[48px]"
              >
                <ExternalLink className="w-4 h-4" />
                Zum Live-Raum-Tab
              </a>
            )}

            {(state === 'closed' || state === 'blocked' || (state === 'idle' && isMobile)) && (
              <button
                onClick={openLiveRoom}
                className="w-full flex items-center justify-center gap-2 px-5 py-3 rounded-2xl bg-gradient-to-r from-primary-500 to-primary-600 hover:from-primary-600 hover:to-primary-700 text-white text-sm font-bold shadow-lg shadow-primary-500/25 transition-all min-h-[48px]"
              >
                {state === 'closed'
                  ? <><RefreshCw className="w-4 h-4" /> Wieder beitreten</>
                  : <><Video className="w-4 h-4" /> Live-Raum öffnen</>}
              </button>
            )}

            {/* Tab-Fallback ist immer als sekundärer Link verfügbar */}
            {state !== 'idle' && (
              <a
                href={jitsiUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="w-full flex items-center justify-center gap-2 px-5 py-3 rounded-2xl bg-stone-100 hover:bg-stone-200 text-ink-700 text-sm font-medium transition-all min-h-[48px]"
              >
                <ExternalLink className="w-4 h-4" />
                {state === 'blocked' ? 'In neuem Tab öffnen' : 'Stattdessen neuen Tab öffnen'}
              </a>
            )}
          </div>
        </div>

        {/* Footer mit Hinweisen */}
        <div className="border-t border-stone-100 bg-stone-50/60 px-6 py-3 grid grid-cols-3 gap-2">
          <FooterHint icon={<MicOff className="w-3.5 h-3.5" />} text="Mikrofon stumm" />
          <FooterHint icon={<VideoOff className="w-3.5 h-3.5" />} text="Kamera aus" />
          <FooterHint icon={<ShieldCheck className="w-3.5 h-3.5" />} text="Kein Login" />
        </div>

        {/* Subtiler Identitäts-Hinweis */}
        <div className="px-6 py-3 bg-white border-t border-stone-100 flex items-center gap-2">
          <Users className="w-3.5 h-3.5 text-ink-400 flex-shrink-0" />
          <p className="text-[11px] text-ink-500 truncate">
            Du trittst als <strong className="text-ink-700">{userName}</strong> bei
          </p>
        </div>
      </div>
    </div>
  )
}

// ── Hilfs-Komponenten ───────────────────────────────────────────────────────

function StatusBlock({
  icon,
  title,
  description,
  tone: _tone,
}: {
  icon: React.ReactNode
  title: string
  description: string
  tone: 'primary' | 'success' | 'warning' | 'muted'
}) {
  return (
    <div className="flex flex-col items-center text-center gap-4">
      {icon}
      <div>
        <p className="text-base font-bold text-ink-900 mb-1">{title}</p>
        <p className="text-sm text-ink-600 leading-relaxed max-w-xs">{description}</p>
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
