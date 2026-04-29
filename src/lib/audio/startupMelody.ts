// WebAudio-based startup melody — warm, friendly 4-note chime fitting Mensaena.
// Uses sine waves with soft attack/release + subtle reverb-like delay for warmth.
// Generated at runtime → no MP3 download needed.

let ctx: AudioContext | null = null

function getCtx(): AudioContext {
  if (!ctx) {
    const AC = (window as any).AudioContext || (window as any).webkitAudioContext
    ctx = new AC()
  }
  const c = ctx as AudioContext
  if (c.state === 'suspended') c.resume()
  return c
}

function playNote(audioCtx: AudioContext, freq: number, startOffset: number, dur: number, vol = 0.12) {
  const t0 = audioCtx.currentTime + startOffset

  // Main sine voice
  const osc = audioCtx.createOscillator()
  osc.type = 'sine'
  osc.frequency.value = freq

  // Subtle harmonic for warmth (octave above, quieter)
  const harm = audioCtx.createOscillator()
  harm.type = 'sine'
  harm.frequency.value = freq * 2

  const gain = audioCtx.createGain()
  const harmGain = audioCtx.createGain()

  // Smooth attack & long release
  gain.gain.setValueAtTime(0, t0)
  gain.gain.linearRampToValueAtTime(vol, t0 + 0.06)
  gain.gain.exponentialRampToValueAtTime(0.0001, t0 + dur)

  harmGain.gain.setValueAtTime(0, t0)
  harmGain.gain.linearRampToValueAtTime(vol * 0.3, t0 + 0.06)
  harmGain.gain.exponentialRampToValueAtTime(0.0001, t0 + dur)

  osc.connect(gain).connect(audioCtx.destination)
  harm.connect(harmGain).connect(audioCtx.destination)

  osc.start(t0)
  osc.stop(t0 + dur + 0.05)
  harm.start(t0)
  harm.stop(t0 + dur + 0.05)
}

let played = false

/** Plays the Mensaena startup melody once per page load. */
export function playStartupMelody(): void {
  if (played) return
  played = true
  try {
    const audioCtx = getCtx()

    // Mensaena chime — pentatonic, warm, optimistic
    // E5, G5, B5, E6 in C major (warm major chord arpeggio)
    // Frequencies: E5=659.25, G5=783.99, B5=987.77, E6=1318.51
    const notes = [
      { freq: 659.25, t: 0.00, dur: 0.55 },
      { freq: 783.99, t: 0.16, dur: 0.55 },
      { freq: 987.77, t: 0.32, dur: 0.55 },
      { freq: 1318.51, t: 0.48, dur: 1.0 },
    ]

    notes.forEach(({ freq, t, dur }) => playNote(audioCtx, freq, t, dur, 0.1))
  } catch { /* ignore audio errors */ }
}

/** Resets the played flag (useful for testing / preview button). */
export function resetStartupMelody(): void { played = false }
