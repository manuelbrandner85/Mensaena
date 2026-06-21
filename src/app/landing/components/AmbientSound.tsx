'use client'

import { useCallback, useEffect, useRef, useState } from 'react'

/**
 * AmbientSound — dezente, prozedural erzeugte Abend-Atmosphäre für die Landing.
 *
 * Kein Audio-Asset, kein Copyright: ein sanfter „Abendwind"-Layer (gefiltertes
 * Rauschen) plus ein warmer, leiser Pad-Drone (zwei leicht verstimmte Oszillatoren)
 * — erzeugt live über die Web Audio API. Standardmäßig STUMM. Erst ein bewusster
 * Klick startet den AudioContext (Browser-Autoplay-Policy) und blendet sanft ein.
 * Auswahl wird in localStorage gemerkt, aber NIE automatisch ohne Geste gestartet.
 */

const LS_KEY = 'mensaena.ambient.on'

export default function AmbientSound() {
  const [on, setOn] = useState(false)
  const [ready, setReady] = useState(false)
  const ctxRef = useRef<AudioContext | null>(null)
  const masterRef = useRef<GainNode | null>(null)
  const nodesRef = useRef<Array<AudioNode>>([])

  useEffect(() => {
    setReady(true)
  }, [])

  const buildGraph = useCallback((ctx: AudioContext) => {
    const master = ctx.createGain()
    master.gain.value = 0
    master.connect(ctx.destination)

    // 1) Abendwind — gefiltertes Rauschen, langsam moduliert
    const bufferSize = 2 * ctx.sampleRate
    const noiseBuf = ctx.createBuffer(1, bufferSize, ctx.sampleRate)
    const data = noiseBuf.getChannelData(0)
    let last = 0
    for (let i = 0; i < bufferSize; i++) {
      // brownish noise (weicher als white noise)
      const white = Math.random() * 2 - 1
      last = (last + 0.02 * white) / 1.02
      data[i] = last * 3.2
    }
    const noise = ctx.createBufferSource()
    noise.buffer = noiseBuf
    noise.loop = true
    const windFilter = ctx.createBiquadFilter()
    windFilter.type = 'lowpass'
    windFilter.frequency.value = 520
    windFilter.Q.value = 0.7
    const windGain = ctx.createGain()
    windGain.gain.value = 0.5
    // langsames „Atmen" des Windes
    const lfo = ctx.createOscillator()
    lfo.frequency.value = 0.06
    const lfoGain = ctx.createGain()
    lfoGain.gain.value = 220
    lfo.connect(lfoGain)
    lfoGain.connect(windFilter.frequency)
    noise.connect(windFilter)
    windFilter.connect(windGain)
    windGain.connect(master)

    // 2) Warmer Pad-Drone — zwei leicht verstimmte Sägezähne, tiefpassgefiltert
    const padFilter = ctx.createBiquadFilter()
    padFilter.type = 'lowpass'
    padFilter.frequency.value = 700
    padFilter.Q.value = 0.5
    const padGain = ctx.createGain()
    padGain.gain.value = 0.06
    padFilter.connect(padGain)
    padGain.connect(master)
    const freqs = [110, 110.4, 164.81] // A2, leichtes Detune, E3 (Quinte)
    const oscs = freqs.map((f) => {
      const o = ctx.createOscillator()
      o.type = 'sawtooth'
      o.frequency.value = f
      o.connect(padFilter)
      o.start()
      return o
    })

    noise.start()
    lfo.start()

    nodesRef.current = [noise, lfo, lfoGain, windFilter, windGain, padFilter, padGain, ...oscs]
    masterRef.current = master
    // sanft einblenden
    const now = ctx.currentTime
    master.gain.cancelScheduledValues(now)
    master.gain.setValueAtTime(0, now)
    master.gain.linearRampToValueAtTime(0.18, now + 2.5)
  }, [])

  const stop = useCallback(() => {
    const ctx = ctxRef.current
    const master = masterRef.current
    if (!ctx || !master) return
    const now = ctx.currentTime
    master.gain.cancelScheduledValues(now)
    master.gain.setValueAtTime(master.gain.value, now)
    master.gain.linearRampToValueAtTime(0, now + 0.8)
    window.setTimeout(() => {
      nodesRef.current.forEach((n) => {
        try {
          ;(n as AudioScheduledSourceNode).stop?.()
        } catch {}
        try {
          n.disconnect()
        } catch {}
      })
      nodesRef.current = []
      ctx.close().catch(() => {})
      ctxRef.current = null
      masterRef.current = null
    }, 900)
  }, [])

  const toggle = useCallback(() => {
    if (on) {
      setOn(false)
      try {
        window.localStorage.setItem(LS_KEY, '0')
      } catch {}
      stop()
      return
    }
    try {
      const AC = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext
      const ctx = new AC()
      ctxRef.current = ctx
      void ctx.resume()
      buildGraph(ctx)
      setOn(true)
      try {
        window.localStorage.setItem(LS_KEY, '1')
      } catch {}
    } catch {
      /* Web Audio nicht verfügbar → Toggle bleibt aus */
    }
  }, [on, buildGraph, stop])

  // Beim Verlassen aufräumen
  useEffect(() => () => stop(), [stop])

  if (!ready) return null

  return (
    <button
      type="button"
      onClick={toggle}
      className={`cin-ambient ${on ? 'is-on' : ''}`}
      aria-pressed={on}
      aria-label={on ? 'Atmosphäre ausschalten' : 'Atmosphäre einschalten'}
      title={on ? 'Atmosphäre aus' : 'Atmosphäre an'}
    >
      <span className="bars" aria-hidden="true">
        <i />
        <i />
        <i />
        <i />
      </span>
      <span className="lbl">{on ? 'Ton an' : 'Atmosphäre'}</span>
    </button>
  )
}
