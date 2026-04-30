// WebAudio-based dial tone — European busy-style ringback (425Hz, 1s on / 4s off).
// Generated at runtime, no MP3 needed.

let ctx: AudioContext | null = null
let activeTimer: number | null = null
let activeOscillators: OscillatorNode[] = []

interface WebAudioWindow extends Window {
  webkitAudioContext?: typeof AudioContext
}

function getCtx(): AudioContext {
  if (!ctx) {
    const AC = window.AudioContext || (window as WebAudioWindow).webkitAudioContext
    if (!AC) throw new Error('Web Audio API nicht verfügbar')
    ctx = new AC()
  }
  if (ctx.state === 'suspended') void ctx.resume().catch(() => { /* ignore */ })
  return ctx
}

function playRingback(): void {
  try {
    const audioCtx = getCtx()
    const now = audioCtx.currentTime
    const dur = 1.0

    const osc = audioCtx.createOscillator()
    const gain = audioCtx.createGain()
    osc.type = 'sine'
    osc.frequency.value = 425

    // Soft attack/release to avoid clicks
    gain.gain.setValueAtTime(0, now)
    gain.gain.linearRampToValueAtTime(0.12, now + 0.03)
    gain.gain.linearRampToValueAtTime(0.12, now + dur - 0.05)
    gain.gain.linearRampToValueAtTime(0, now + dur)

    osc.connect(gain)
    gain.connect(audioCtx.destination)
    osc.start(now)
    osc.stop(now + dur)
    activeOscillators.push(osc)
  } catch {
    // Audio policy block – still ignore
  }
}

/** Startet den Wählton (1s Ton, 4s Pause, Wiederholung). */
export function startDialTone(): void {
  stopDialTone()
  playRingback()
  // FIX-18: Fallback bei gesperrtem Audio – Vibration + Retry
  try {
    const audioCtx = getCtx()
    if (audioCtx.state === 'suspended') {
      if (typeof navigator !== 'undefined' && navigator.vibrate) {
        navigator.vibrate([400, 200, 400, 200, 400])
      }
      // FIX-18: Retry nach 500ms – User hat evtl. inzwischen getippt
      setTimeout(() => {
        audioCtx.resume().then(() => {
          if (audioCtx.state === 'running') playRingback()
        }).catch(() => {})
      }, 500)
    }
  } catch { /* ignore */ }
  activeTimer = window.setInterval(playRingback, 5000)
}

/** Stoppt den Wählton und gibt alle Oszillatoren frei. */
export function stopDialTone(): void {
  if (activeTimer !== null) {
    clearInterval(activeTimer)
    activeTimer = null
  }
  activeOscillators.forEach(o => { try { o.stop() } catch { /* ignore */ } })
  activeOscillators = []
}
