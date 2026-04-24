'use client'

import { useEffect, useRef, useState } from 'react'
import { Mic, MicOff, Square } from 'lucide-react'
import { cn } from '@/lib/utils'

// Web Speech API types (not in lib.dom by default)
interface SpeechRecognitionAlternative {
  transcript: string
  confidence: number
}
interface SpeechRecognitionResult {
  isFinal: boolean
  length: number
  [index: number]: SpeechRecognitionAlternative
}
interface SpeechRecognitionResultList {
  length: number
  [index: number]: SpeechRecognitionResult
}
interface SpeechRecognitionEvent extends Event {
  resultIndex: number
  results: SpeechRecognitionResultList
}
interface SpeechRecognition extends EventTarget {
  lang: string
  continuous: boolean
  interimResults: boolean
  onstart: (() => void) | null
  onend: (() => void) | null
  onerror: ((e: Event) => void) | null
  onresult: ((e: SpeechRecognitionEvent) => void) | null
  onspeechend: (() => void) | null
  start: () => void
  stop: () => void
  abort: () => void
}
interface SpeechRecognitionConstructor {
  new (): SpeechRecognition
}
declare global {
  interface Window {
    SpeechRecognition?: SpeechRecognitionConstructor
    webkitSpeechRecognition?: SpeechRecognitionConstructor
  }
}

const SILENCE_TIMEOUT_MS = 30_000

interface VoiceInputButtonProps {
  onResult: (transcript: string) => void
  /** Appended to existing field value (true) or replaces it (false, default) */
  append?: boolean
  label?: string
  className?: string
}

export default function VoiceInputButton({ onResult, label, className }: VoiceInputButtonProps) {
  const [supported, setSupported] = useState<boolean | null>(null)
  const [recording, setRecording]  = useState(false)
  const [interim, setInterim]       = useState('')
  const recognitionRef = useRef<SpeechRecognition | null>(null)
  const silenceTimer   = useRef<ReturnType<typeof setTimeout> | null>(null)

  useEffect(() => {
    setSupported(!!(window.SpeechRecognition || window.webkitSpeechRecognition))
  }, [])

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      recognitionRef.current?.abort()
      if (silenceTimer.current) clearTimeout(silenceTimer.current)
    }
  }, [])

  if (!supported) return null

  const resetSilenceTimer = (rec: SpeechRecognition) => {
    if (silenceTimer.current) clearTimeout(silenceTimer.current)
    silenceTimer.current = setTimeout(() => rec.stop(), SILENCE_TIMEOUT_MS)
  }

  const start = () => {
    const Ctor = window.SpeechRecognition ?? window.webkitSpeechRecognition
    if (!Ctor) return
    const rec = new Ctor()
    rec.lang = 'de-DE'
    rec.continuous = true
    rec.interimResults = true

    rec.onstart = () => {
      setRecording(true)
      setInterim('')
      resetSilenceTimer(rec)
    }

    rec.onresult = (e: SpeechRecognitionEvent) => {
      resetSilenceTimer(rec)
      let finalChunk = ''
      let interimChunk = ''
      for (let i = e.resultIndex; i < e.results.length; i++) {
        const t = e.results[i][0].transcript
        if (e.results[i].isFinal) finalChunk += t
        else interimChunk += t
      }
      if (finalChunk) {
        onResult(finalChunk.trim())
        setInterim('')
      } else {
        setInterim(interimChunk)
      }
    }

    rec.onspeechend = () => rec.stop()

    rec.onend = () => {
      setRecording(false)
      setInterim('')
      if (silenceTimer.current) clearTimeout(silenceTimer.current)
    }

    rec.onerror = () => {
      setRecording(false)
      setInterim('')
      if (silenceTimer.current) clearTimeout(silenceTimer.current)
    }

    recognitionRef.current = rec
    rec.start()
  }

  const stop = () => {
    recognitionRef.current?.stop()
  }

  return (
    <div className="relative inline-flex items-center">
      <button
        type="button"
        onClick={recording ? stop : start}
        title={recording ? 'Aufnahme stoppen' : label ? `${label} per Sprache eingeben` : 'Spracheingabe'}
        aria-label={recording ? 'Aufnahme stoppen' : 'Spracheingabe starten'}
        aria-pressed={recording}
        className={cn(
          'flex items-center justify-center w-8 h-8 rounded-lg transition-all',
          recording
            ? 'bg-red-500 text-white shadow-md animate-pulse ring-2 ring-red-300'
            : 'bg-stone-100 text-stone-500 hover:bg-stone-200 hover:text-stone-700',
          className,
        )}
      >
        {recording ? <Square className="w-3.5 h-3.5" /> : <Mic className="w-3.5 h-3.5" />}
      </button>

      {/* Live interim transcript bubble */}
      {interim && (
        <span className="absolute left-full ml-2 top-1/2 -translate-y-1/2 whitespace-nowrap max-w-[200px] truncate text-[11px] bg-ink-800 text-white px-2 py-1 rounded-lg pointer-events-none z-10 shadow">
          {interim}
        </span>
      )}
    </div>
  )
}
