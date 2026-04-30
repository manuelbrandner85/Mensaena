// WebAudio-based ringtone — alternating two-tone like a classic phone ring.
// No MP3 needed, generated at runtime.

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

function playRingPattern() {
  try {
    const audioCtx = getCtx()
    const now = audioCtx.currentTime

    // Two-tone classic phone ring: high tone + low tone alternating
    const tones = [
      { freq: 480, start: 0,   dur: 0.4 },
      { freq: 620, start: 0.4, dur: 0.4 },
      { freq: 480, start: 0.8, dur: 0.4 },
      { freq: 620, start: 1.2, dur: 0.4 },
    ]

    activeOscillators = []

    tones.forEach(({ freq, start, dur }) => {
      const osc = audioCtx.createOscillator()
      const gain = audioCtx.createGain()
      osc.type = 'sine'
      osc.frequency.value = freq

      // Soft attack/release to avoid clicks
      gain.gain.setValueAtTime(0, now + start)
      gain.gain.linearRampToValueAtTime(0.18, now + start + 0.02)
      gain.gain.linearRampToValueAtTime(0.18, now + start + dur - 0.05)
      gain.gain.linearRampToValueAtTime(0, now + start + dur)

      osc.connect(gain)
      gain.connect(audioCtx.destination)
      osc.start(now + start)
      osc.stop(now + start + dur)
      activeOscillators.push(osc)
    })
  } catch { /* ignore audio errors */ }
}

export function startRingtone(): void {
  stopRingtone()
  playRingPattern()
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
          if (audioCtx.state === 'running') playRingPattern()
        }).catch(() => {})
      }, 500)
    }
  } catch { /* ignore */ }
  // Repeat every 2.5 seconds (1.6s tones + 0.9s pause)
  activeTimer = window.setInterval(playRingPattern, 2500)
}

export function stopRingtone(): void {
  if (activeTimer !== null) {
    clearInterval(activeTimer)
    activeTimer = null
  }
  activeOscillators.forEach(o => { try { o.stop() } catch { /* ignore */ } })
  activeOscillators = []
}
