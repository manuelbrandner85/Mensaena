// FEATURE: Anruf-Ende-Ton
export function playEndTone(): void {
  try {
    const AC = window.AudioContext || (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext
    if (!AC) return
    const ctx = new AC()
    const now = ctx.currentTime
    const tones = [
      { freq: 400, start: 0, dur: 0.15 },
      { freq: 400, start: 0.25, dur: 0.15 },
    ]
    tones.forEach(({ freq, start, dur }) => {
      const osc = ctx.createOscillator()
      const gain = ctx.createGain()
      osc.type = 'sine'
      osc.frequency.value = freq
      gain.gain.setValueAtTime(0, now + start)
      gain.gain.linearRampToValueAtTime(0.12, now + start + 0.02)
      gain.gain.linearRampToValueAtTime(0, now + start + dur)
      osc.connect(gain)
      gain.connect(ctx.destination)
      osc.start(now + start)
      osc.stop(now + start + dur)
    })
    setTimeout(() => ctx.close(), 1000)
  } catch { /* Audio nicht verfügbar */ }
}
