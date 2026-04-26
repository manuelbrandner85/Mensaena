'use client'

import { useEffect, useRef, useState, useCallback } from 'react'
import { Camera, CameraOff, Keyboard, Loader2, ScanLine, X, Search } from 'lucide-react'
import { cn } from '@/lib/utils'
import { getProductByBarcode, searchProducts, type FoodProduct } from '@/lib/api/foodfacts'

// ── BarcodeDetector feature-detection ─────────────────────────

declare global {
  interface Window {
    BarcodeDetector?: typeof BarcodeDetector
  }
}

interface BarcodeDetector {
  detect(source: ImageBitmapSource): Promise<{ rawValue: string; format: string }[]>
}
interface BarcodeDetectorConstructor {
  new (opts?: { formats?: string[] }): BarcodeDetector
  getSupportedFormats(): Promise<string[]>
}
declare let BarcodeDetector: BarcodeDetectorConstructor

function isBarcodeDetectorSupported(): boolean {
  return typeof window !== 'undefined' && 'BarcodeDetector' in window
}

// ── Types ──────────────────────────────────────────────────────

export interface BarcodeScannerProps {
  onProduct: (product: FoodProduct) => void
  onClose: () => void
  /** Wird aufgerufen wenn der Barcode erkannt wurde aber noch kein Produkt geladen ist */
  onBarcodeDetected?: (barcode: string) => void
}

type ScanState = 'idle' | 'requesting' | 'scanning' | 'loading' | 'denied' | 'manual'

// ── Component ─────────────────────────────────────────────────

export default function BarcodeScanner({ onProduct, onClose, onBarcodeDetected }: BarcodeScannerProps) {
  const videoRef        = useRef<HTMLVideoElement>(null)
  const canvasRef       = useRef<HTMLCanvasElement>(null)
  const streamRef       = useRef<MediaStream | null>(null)
  const rafRef          = useRef<number>(0)
  const detectorRef     = useRef<BarcodeDetector | null>(null)
  const lastBarcodeRef  = useRef<string>('')
  const throttleRef     = useRef<number>(0)

  const [state, setState]           = useState<ScanState>('idle')
  const [manualInput, setManualInput] = useState('')
  const [searchInput, setSearchInput] = useState('')
  const [error, setError]           = useState<string | null>(null)
  const [statusMsg, setStatusMsg]   = useState<string>('')
  const [searching, setSearching]   = useState(false)
  const [searchResults, setSearchResults] = useState<FoodProduct[]>([])

  const hasDetector = isBarcodeDetectorSupported()
  const isNative = typeof window !== 'undefined' &&
    !!(window as unknown as { Capacitor?: { isNativePlatform?: () => boolean } }).Capacitor?.isNativePlatform?.()
  const isAndroid = typeof window !== 'undefined' &&
    (window as unknown as { Capacitor?: { getPlatform?: () => string } }).Capacitor?.getPlatform?.() === 'android'

  // ── Stop camera ───────────────────────────────────────────────

  const stopCamera = useCallback(() => {
    cancelAnimationFrame(rafRef.current)
    if (streamRef.current) {
      streamRef.current.getTracks().forEach(t => t.stop())
      streamRef.current = null
    }
    if (videoRef.current) videoRef.current.srcObject = null
  }, [])

  useEffect(() => () => stopCamera(), [stopCamera])

  // ── Load product ──────────────────────────────────────────────

  const loadProduct = useCallback(async (barcode: string) => {
    stopCamera()
    setState('loading')
    setStatusMsg('Produkt wird gesucht…')
    onBarcodeDetected?.(barcode)

    if (typeof navigator !== 'undefined' && 'vibrate' in navigator) {
      try { navigator.vibrate([80, 40, 80]) } catch { /* noop */ }
    }

    const product = await getProductByBarcode(barcode)
    if (product) {
      onProduct(product)
    } else {
      setError(`Kein Produkt für Barcode „${barcode}" gefunden.`)
      setState('manual')
      setManualInput(barcode)
    }
  }, [stopCamera, onBarcodeDetected, onProduct])

  // ── Scan loop ─────────────────────────────────────────────────

  const scanFrame = useCallback(async () => {
    const video   = videoRef.current
    const canvas  = canvasRef.current
    const detector = detectorRef.current
    if (!video || !canvas || !detector || video.readyState < 2) {
      rafRef.current = requestAnimationFrame(scanFrame)
      return
    }

    const now = Date.now()
    if (now - throttleRef.current < 300) {
      rafRef.current = requestAnimationFrame(scanFrame)
      return
    }
    throttleRef.current = now

    canvas.width  = video.videoWidth
    canvas.height = video.videoHeight
    const ctx = canvas.getContext('2d', { willReadFrequently: true })
    if (!ctx) { rafRef.current = requestAnimationFrame(scanFrame); return }
    ctx.drawImage(video, 0, 0)

    try {
      const barcodes = await detector.detect(canvas)
      if (barcodes.length > 0) {
        const raw = barcodes[0].rawValue
        if (raw && raw !== lastBarcodeRef.current) {
          lastBarcodeRef.current = raw
          await loadProduct(raw)
          return
        }
      }
    } catch { /* detector error – continue */ }

    rafRef.current = requestAnimationFrame(scanFrame)
  }, [loadProduct])

  // ── Start camera ──────────────────────────────────────────────

  const startCamera = useCallback(async () => {
    setError(null)
    setState('requesting')

    if (!hasDetector) {
      setState('manual')
      return
    }

    // Auf nativen Plattformen die Runtime-Permission explizit über das
    // @capacitor/camera Plugin anfragen, BEVOR getUserMedia() läuft.
    // Capacitor's WebChromeClient.onPermissionRequest greift sonst evtl. nicht
    // zuverlässig (Race-Condition, Activity-Lifecycle, WebView-Version).
    if (isNative) {
      try {
        const { Camera } = await import('@capacitor/camera')
        const status = await Camera.checkPermissions()
        if (status.camera !== 'granted') {
          const result = await Camera.requestPermissions({ permissions: ['camera'] })
          if (result.camera !== 'granted') {
            setState('denied')
            setError(
              result.camera === 'denied'
                ? 'Kamera-Zugriff verweigert. Bitte aktiviere die Berechtigung in den App-Einstellungen.'
                : 'Kamera-Berechtigung wurde nicht erteilt.',
            )
            return
          }
        }
      } catch {
        // Plugin nicht verfügbar – getUserMedia() unten kümmert sich.
      }
    }

    try {
      // Build BarcodeDetector with common 1D + 2D formats
      const supported = await BarcodeDetector.getSupportedFormats().catch(() => [] as string[])
      const formats = supported.length > 0 ? supported : [
        'ean_13', 'ean_8', 'upc_a', 'upc_e',
        'code_128', 'code_39', 'qr_code', 'data_matrix',
      ]
      detectorRef.current = new BarcodeDetector({ formats })

      const stream = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: { ideal: 'environment' },
          width: { ideal: 1280 },
          height: { ideal: 720 },
        },
        audio: false,
      })
      streamRef.current = stream

      if (videoRef.current) {
        videoRef.current.srcObject = stream
        await videoRef.current.play()
      }
      setState('scanning')
      setStatusMsg('Barcode in den Rahmen halten…')
      lastBarcodeRef.current = ''
      rafRef.current = requestAnimationFrame(scanFrame)
    } catch (err: unknown) {
      const name = (err instanceof Error) ? err.name : ''
      if (name === 'NotAllowedError' || name === 'PermissionDeniedError') {
        setState('denied')
        setError(
          isNative
            ? 'Kamera-Zugriff verweigert. Bitte erlaube den Kamera-Zugriff in den App-Einstellungen deines Geräts.'
            : 'Kamera-Zugriff blockiert. Bitte erlaube den Zugriff in den Browser-Einstellungen und versuche es erneut.',
        )
      } else {
        setState('manual')
        setError('Kamera konnte nicht gestartet werden. Bitte Barcode manuell eingeben.')
      }
    }
  }, [hasDetector, isNative, scanFrame])

  // Request camera permission immediately when scanner opens
  useEffect(() => {
    if (hasDetector) startCamera()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // ── Manual submit ─────────────────────────────────────────────

  const handleManualSubmit = useCallback(async (e: React.FormEvent) => {
    e.preventDefault()
    const code = manualInput.trim()
    if (!code) return
    await loadProduct(code)
  }, [manualInput, loadProduct])

  // ── Search ────────────────────────────────────────────────────

  const handleSearch = useCallback(async (e: React.FormEvent) => {
    e.preventDefault()
    const q = searchInput.trim()
    if (!q) return
    setSearching(true)
    setSearchResults([])
    const results = await searchProducts(q)
    setSearchResults(results)
    setSearching(false)
    if (results.length === 0) setError('Keine Produkte gefunden.')
  }, [searchInput])

  // ── Render helpers ─────────────────────────────────────────────

  const showManual    = state === 'manual' || state === 'denied'
  const isLoadingProduct = state === 'loading'

  return (
    <div
      className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-end sm:items-center justify-center [padding-bottom:env(safe-area-inset-bottom,0px)] sm:p-4"
      role="dialog"
      aria-modal="true"
      aria-label="Barcode-Scanner"
    >
      <div className="relative w-full sm:max-w-lg bg-white dark:bg-ink-900 rounded-t-3xl sm:rounded-2xl shadow-2xl overflow-hidden max-h-[95dvh] flex flex-col">

        {/* Header */}
        <div className="flex items-center justify-between px-5 pt-5 pb-3 border-b border-stone-100 dark:border-ink-800 flex-shrink-0">
          <div>
            <h2 className="font-bold text-ink-900 dark:text-white flex items-center gap-2">
              <ScanLine className="w-5 h-5 text-primary-600" />
              Lebensmittel scannen
            </h2>
            <p className="text-xs text-ink-500 dark:text-ink-400 mt-0.5">
              {hasDetector ? 'Kamera oder manuelle Eingabe' : 'Barcode-Nummer eingeben'}
            </p>
          </div>
          <button
            onClick={() => { stopCamera(); onClose() }}
            className="w-8 h-8 rounded-full bg-stone-100 dark:bg-ink-800 flex items-center justify-center text-ink-500 hover:text-ink-900 dark:hover:text-white transition-colors"
            aria-label="Schließen"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Body */}
        <div className="overflow-y-auto flex-1">

          {/* Camera View */}
          {(state === 'idle' || state === 'requesting' || state === 'scanning' || state === 'loading') && (
            <div className="relative bg-black" style={{ aspectRatio: '4/3', minHeight: '200px' }}>
              <video
                ref={videoRef}
                className={cn(
                  'w-full h-full object-cover',
                  state !== 'scanning' && 'opacity-0',
                )}
                playsInline
                muted
                aria-hidden
              />
              {/* Hidden canvas for frame capture */}
              <canvas ref={canvasRef} className="hidden" aria-hidden />

              {/* Overlay: idle */}
              {state === 'idle' && (
                <div className="absolute inset-0 flex flex-col items-center justify-center gap-4 bg-ink-900">
                  <div className="w-16 h-16 rounded-2xl bg-primary-600/20 border border-primary-500/30 flex items-center justify-center">
                    <Camera className="w-8 h-8 text-primary-400" />
                  </div>
                  <button
                    onClick={startCamera}
                    className="px-6 py-3 bg-primary-600 text-white rounded-xl font-semibold text-sm hover:bg-primary-700 transition-colors active:scale-95"
                  >
                    Kamera aktivieren
                  </button>
                  {hasDetector && (
                    <p className="text-xs text-ink-500 text-center px-8">
                      Für den Scan benötigt die App kurz Zugriff auf die Kamera.
                    </p>
                  )}
                </div>
              )}

              {/* Overlay: requesting / loading */}
              {(state === 'requesting' || state === 'loading') && (
                <div className="absolute inset-0 flex flex-col items-center justify-center gap-3 bg-ink-900/90">
                  <Loader2 className="w-8 h-8 text-primary-400 animate-spin" />
                  <p className="text-sm text-stone-400">
                    {state === 'requesting' ? 'Kamera wird gestartet…' : statusMsg}
                  </p>
                </div>
              )}

              {/* Scanner frame + animated line */}
              {state === 'scanning' && (
                <>
                  {/* Corner brackets */}
                  <div className="absolute inset-0 flex items-center justify-center pointer-events-none" aria-hidden>
                    <div className="relative w-56 h-44">
                      {/* corners */}
                      {(['tl','tr','bl','br'] as const).map(c => (
                        <span key={c} className={cn(
                          'absolute w-8 h-8 border-primary-400',
                          c === 'tl' && 'top-0 left-0 border-t-[3px] border-l-[3px] rounded-tl-lg',
                          c === 'tr' && 'top-0 right-0 border-t-[3px] border-r-[3px] rounded-tr-lg',
                          c === 'bl' && 'bottom-0 left-0 border-b-[3px] border-l-[3px] rounded-bl-lg',
                          c === 'br' && 'bottom-0 right-0 border-b-[3px] border-r-[3px] rounded-br-lg',
                        )} />
                      ))}
                      {/* Scanner line */}
                      <div className="absolute left-1 right-1 top-1/2 -translate-y-1/2 h-0.5 bg-primary-400/80 animate-scanner-line rounded-full shadow-[0_0_8px_2px_rgba(30,170,166,0.6)]" />
                    </div>
                  </div>

                  {/* Status */}
                  <div className="absolute bottom-4 left-0 right-0 flex justify-center">
                    <span
                      className="bg-black/60 backdrop-blur-sm text-white text-xs px-4 py-2 rounded-full"
                      aria-live="polite"
                    >
                      {statusMsg}
                    </span>
                  </div>

                  {/* Stop button */}
                  <button
                    onClick={() => { stopCamera(); setState('idle') }}
                    className="absolute top-3 right-3 w-9 h-9 bg-black/60 backdrop-blur-sm rounded-full flex items-center justify-center text-white hover:bg-black/80 transition-colors"
                    aria-label="Kamera stoppen"
                  >
                    <CameraOff className="w-4 h-4" />
                  </button>
                </>
              )}
            </div>
          )}

          {/* Denied */}
          {state === 'denied' && (
            <div className="flex flex-col items-center gap-4 py-8 px-6 text-center">
              <div className="w-16 h-16 bg-red-50 rounded-2xl flex items-center justify-center">
                <CameraOff className="w-8 h-8 text-red-500" />
              </div>
              <div>
                <p className="font-semibold text-ink-900 dark:text-white mb-1">Kamera-Zugriff erforderlich</p>
                <p className="text-sm text-ink-600 dark:text-ink-400">{error}</p>
              </div>
              {isAndroid ? (
                /* Android: Primär-Button triggert den In-App-Permission-Dialog neu.
                   Nur wenn die Berechtigung dauerhaft blockiert ist ("Nie fragen"),
                   braucht der User die manuelle Einstellungs-Route. */
                <div className="w-full space-y-3">
                  <button
                    onClick={startCamera}
                    className="w-full px-5 py-3 bg-primary-600 text-white text-sm font-semibold rounded-xl hover:bg-primary-700 transition-colors active:scale-95"
                  >
                    Berechtigung erneut anfragen
                  </button>
                  <details className="w-full group">
                    <summary className="text-xs text-ink-500 cursor-pointer hover:text-ink-700 text-center list-none">
                      Immer noch gesperrt? Manuell aktivieren ▾
                    </summary>
                    <div className="mt-2 px-4 py-3 bg-amber-50 border border-amber-200 rounded-xl text-left">
                      <p className="text-xs font-semibold text-amber-900 mb-1.5">In Android-Einstellungen aktivieren:</p>
                      <ol className="text-xs text-amber-800 space-y-1 list-decimal list-inside">
                        <li>Einstellungen → Apps → Mensaena</li>
                        <li>Berechtigungen → Kamera</li>
                        <li>„Nur beim Benutzen der App" wählen</li>
                      </ol>
                    </div>
                  </details>
                </div>
              ) : isNative ? (
                <a
                  href="app-settings:"
                  className="w-full px-5 py-3 bg-primary-600 text-white text-sm font-semibold rounded-xl hover:bg-primary-700 transition-colors active:scale-95 text-center block"
                >
                  App-Einstellungen öffnen
                </a>
              ) : (
                <button
                  onClick={startCamera}
                  className="w-full px-5 py-3 bg-primary-600 text-white text-sm font-semibold rounded-xl hover:bg-primary-700 transition-colors active:scale-95"
                >
                  Nochmal versuchen
                </button>
              )}
            </div>
          )}

          {/* Error banner */}
          {error && state !== 'denied' && (
            <div className="mx-5 mt-4 px-4 py-3 bg-red-50 dark:bg-red-900/20 border border-red-100 dark:border-red-800 rounded-xl text-sm text-red-700 dark:text-red-300" aria-live="assertive">
              {error}
            </div>
          )}

          {/* Manual input + search */}
          <div className="px-5 py-5 space-y-5">

            {/* Toggle to manual if camera is showing */}
            {(state === 'idle' || state === 'scanning') && hasDetector && (
              <button
                onClick={() => { stopCamera(); setState('manual') }}
                className="flex items-center gap-2 text-sm text-primary-600 hover:text-primary-700 font-medium"
              >
                <Keyboard className="w-4 h-4" />
                Barcode manuell eingeben
              </button>
            )}

            {/* Manual barcode field */}
            {showManual && (
              <form onSubmit={handleManualSubmit} className="flex gap-2">
                <div className="relative flex-1">
                  <input
                    type="text"
                    inputMode="numeric"
                    pattern="[0-9]*"
                    value={manualInput}
                    onChange={e => setManualInput(e.target.value.replace(/\D/g, ''))}
                    placeholder="Barcode-Nummer eingeben…"
                    className="input w-full pr-10"
                    autoFocus={showManual}
                    aria-label="Barcode-Nummer"
                  />
                </div>
                <button
                  type="submit"
                  disabled={!manualInput.trim() || isLoadingProduct}
                  className="px-4 py-2.5 bg-primary-600 text-white rounded-xl font-semibold text-sm hover:bg-primary-700 disabled:opacity-50 transition-colors active:scale-95 flex items-center gap-1.5"
                >
                  {isLoadingProduct ? <Loader2 className="w-4 h-4 animate-spin" /> : 'Suchen'}
                </button>
              </form>
            )}

            {/* Back to camera */}
            {showManual && hasDetector && (
              <button
                onClick={() => { setError(null); setState('idle') }}
                className="flex items-center gap-2 text-sm text-primary-600 hover:text-primary-700 font-medium"
              >
                <Camera className="w-4 h-4" />
                Zurück zur Kamera
              </button>
            )}

            {/* Divider */}
            <div className="flex items-center gap-3">
              <div className="flex-1 h-px bg-stone-100 dark:bg-ink-800" />
              <span className="text-xs text-ink-400">oder nach Produktnamen suchen</span>
              <div className="flex-1 h-px bg-stone-100 dark:bg-ink-800" />
            </div>

            {/* Product name search */}
            <form onSubmit={handleSearch} className="flex gap-2">
              <div className="relative flex-1">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-ink-400" />
                <input
                  type="text"
                  value={searchInput}
                  onChange={e => setSearchInput(e.target.value)}
                  placeholder="z.B. Nutella, Vollmilch, Toastbrot…"
                  className="input w-full pl-9"
                  aria-label="Produkt suchen"
                />
              </div>
              <button
                type="submit"
                disabled={!searchInput.trim() || searching}
                className="px-4 py-2.5 bg-ink-800 dark:bg-ink-700 text-white rounded-xl font-semibold text-sm hover:bg-ink-900 disabled:opacity-50 transition-colors active:scale-95 flex items-center gap-1.5"
              >
                {searching ? <Loader2 className="w-4 h-4 animate-spin" /> : <Search className="w-4 h-4" />}
              </button>
            </form>

            {/* Search results */}
            {searchResults.length > 0 && (
              <div className="space-y-2" aria-live="polite" aria-label="Suchergebnisse">
                {searchResults.map(p => (
                  <button
                    key={p.barcode}
                    onClick={() => onProduct(p)}
                    className="w-full flex items-center gap-3 px-3 py-2.5 bg-stone-50 dark:bg-ink-800 rounded-xl hover:bg-primary-50 dark:hover:bg-ink-700 transition-colors text-left group"
                  >
                    {p.imageUrl ? (
                      <img src={p.imageUrl} alt={p.name} className="w-10 h-10 rounded-lg object-cover flex-shrink-0 bg-stone-100" />
                    ) : (
                      <div className="w-10 h-10 rounded-lg bg-stone-200 dark:bg-ink-700 flex items-center justify-center flex-shrink-0 text-lg">🍽️</div>
                    )}
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-semibold text-ink-900 dark:text-white truncate group-hover:text-primary-700">{p.name}</p>
                      {p.brand && <p className="text-xs text-ink-500 truncate">{p.brand}</p>}
                    </div>
                    {p.nutriScore && (
                      <span className="text-xs font-bold text-white px-1.5 py-0.5 rounded flex-shrink-0"
                        style={{ backgroundColor: { a:'#038141',b:'#85BB2F',c:'#FECB02',d:'#EE8100',e:'#E63312' }[p.nutriScore] }}>
                        {p.nutriScore.toUpperCase()}
                      </span>
                    )}
                  </button>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Global scanner-line animation (keyframes injected via style tag) */}
      <style>{`
        @keyframes scanner-line {
          0%   { transform: translateY(-80px); opacity: 0; }
          10%  { opacity: 1; }
          90%  { opacity: 1; }
          100% { transform: translateY(80px); opacity: 0; }
        }
        .animate-scanner-line {
          animation: scanner-line 2s ease-in-out infinite;
        }
      `}</style>
    </div>
  )
}
