'use client'

import { useState, useRef, useCallback, useEffect } from 'react'
import { Mic, Square, Loader2, X, Send } from 'lucide-react'
import toast from 'react-hot-toast'
import { createClient } from '@/lib/supabase/client'
import { cn } from '@/lib/utils'

interface Props {
  userId: string
  conversationId: string
  disabled?: boolean
  onSent?: () => void
}

// Voice recorder: one-tap mic → upload → message. No app-level permission
// gate; the browser's native getUserMedia prompt is the only permission
// step (shown once per origin, then remembered).
export default function VoiceRecorder({ userId, conversationId, disabled, onSent }: Props) {
  const [state, setState] = useState<'idle' | 'recording' | 'preview' | 'uploading'>('idle')
  const [duration, setDuration] = useState(0)
  const [blob, setBlob] = useState<Blob | null>(null)
  const [previewUrl, setPreviewUrl] = useState<string | null>(null)
  const mediaRecorderRef = useRef<MediaRecorder | null>(null)
  const chunksRef = useRef<Blob[]>([])
  const streamRef = useRef<MediaStream | null>(null)
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null)

  const cleanupStream = useCallback(() => {
    streamRef.current?.getTracks().forEach(t => t.stop())
    streamRef.current = null
    if (timerRef.current) {
      clearInterval(timerRef.current)
      timerRef.current = null
    }
  }, [])

  useEffect(() => () => {
    cleanupStream()
    if (previewUrl) URL.revokeObjectURL(previewUrl)
  }, [cleanupStream, previewUrl])

  const startRecording = useCallback(async () => {
    if (disabled || state !== 'idle') return
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      streamRef.current = stream
      chunksRef.current = []
      const mime = MediaRecorder.isTypeSupported('audio/webm;codecs=opus')
        ? 'audio/webm;codecs=opus'
        : MediaRecorder.isTypeSupported('audio/webm')
          ? 'audio/webm'
          : MediaRecorder.isTypeSupported('audio/mp4')
            ? 'audio/mp4'
            : ''
      const recorder = mime ? new MediaRecorder(stream, { mimeType: mime }) : new MediaRecorder(stream)
      mediaRecorderRef.current = recorder

      recorder.ondataavailable = (e) => {
        if (e.data.size > 0) chunksRef.current.push(e.data)
      }
      recorder.onstop = () => {
        const b = new Blob(chunksRef.current, { type: recorder.mimeType || 'audio/webm' })
        setBlob(b)
        setPreviewUrl(URL.createObjectURL(b))
        setState('preview')
        cleanupStream()
      }

      recorder.start()
      setState('recording')
      setDuration(0)
      timerRef.current = setInterval(() => {
        setDuration(d => {
          if (d >= 180) { // auto-stop at 3 minutes
            recorder.stop()
            return d
          }
          return d + 1
        })
      }, 1000)
    } catch (err) {
      console.warn('[VoiceRecorder] mic access failed:', err)
      toast.error('Mikrofon nicht verfügbar')
      setState('idle')
      cleanupStream()
    }
  }, [disabled, state, cleanupStream])

  const stopRecording = useCallback(() => {
    if (state !== 'recording') return
    mediaRecorderRef.current?.stop()
  }, [state])

  const cancelPreview = useCallback(() => {
    if (previewUrl) URL.revokeObjectURL(previewUrl)
    setBlob(null)
    setPreviewUrl(null)
    setDuration(0)
    setState('idle')
  }, [previewUrl])

  const sendVoice = useCallback(async () => {
    if (!blob || state !== 'preview') return
    setState('uploading')
    const supabase = createClient()
    try {
      const ext = (blob.type.includes('mp4') ? 'm4a' : 'webm')
      const uniqueName = `${Date.now()}_${Math.random().toString(36).slice(2, 8)}.${ext}`
      const filePath = `voice/${userId}/${uniqueName}`

      const buckets = ['chat-images', 'avatars'] as const
      let publicUrl: string | null = null
      for (const bucket of buckets) {
        const { error } = await supabase.storage
          .from(bucket)
          .upload(filePath, blob, { upsert: false, contentType: blob.type || 'audio/webm' })
        if (!error) {
          publicUrl = supabase.storage.from(bucket).getPublicUrl(filePath).data.publicUrl
          break
        }
      }
      if (!publicUrl) {
        toast.error('Sprachnachricht konnte nicht gespeichert werden')
        setState('preview')
        return
      }

      const content = `[Sprachnachricht ${duration}s](${publicUrl})`
      const { error: msgErr } = await supabase.from('messages').insert({
        conversation_id: conversationId,
        sender_id: userId,
        content,
      })
      if (msgErr) {
        toast.error('Senden fehlgeschlagen')
        setState('preview')
        return
      }

      toast.success('Sprachnachricht gesendet')
      cancelPreview()
      onSent?.()
    } catch (err) {
      console.warn('[VoiceRecorder] send failed:', err)
      toast.error('Fehler beim Senden')
      setState('preview')
    }
  }, [blob, state, duration, userId, conversationId, cancelPreview, onSent])

  const mm = String(Math.floor(duration / 60)).padStart(2, '0')
  const ss = String(duration % 60).padStart(2, '0')

  if (state === 'idle') {
    return (
      <button
        type="button"
        onClick={startRecording}
        disabled={disabled}
        className="p-1.5 text-ink-400 hover:text-primary-600 rounded-full transition-all flex-shrink-0 disabled:opacity-40"
        aria-label="Sprachnachricht aufnehmen"
      >
        <Mic className="w-4 h-4" />
      </button>
    )
  }

  if (state === 'recording') {
    return (
      <button
        type="button"
        onClick={stopRecording}
        className="flex items-center gap-1.5 px-2.5 py-1 bg-red-500 text-white text-xs font-medium rounded-full flex-shrink-0 animate-pulse"
        aria-label="Aufnahme stoppen"
      >
        <Square className="w-3 h-3 fill-white" />
        <span className="tabular-nums">{mm}:{ss}</span>
      </button>
    )
  }

  // preview / uploading
  return (
    <div className="flex items-center gap-1.5 flex-shrink-0">
      <button
        type="button"
        onClick={cancelPreview}
        disabled={state === 'uploading'}
        className="p-1.5 text-ink-400 hover:text-red-500 disabled:opacity-40"
        aria-label="Verwerfen"
      >
        <X className="w-3.5 h-3.5" />
      </button>
      {previewUrl && (
        <audio src={previewUrl} controls className="h-7 max-w-[160px]" />
      )}
      <button
        type="button"
        onClick={sendVoice}
        disabled={state === 'uploading'}
        className={cn(
          'flex items-center gap-1 px-2.5 py-1 bg-primary-600 text-white text-xs font-medium rounded-full disabled:opacity-50',
        )}
      >
        {state === 'uploading'
          ? <Loader2 className="w-3 h-3 animate-spin" />
          : <Send className="w-3 h-3" />}
        Senden
      </button>
    </div>
  )
}
