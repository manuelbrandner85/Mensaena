'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { ArrowLeft, CalendarPlus } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { showToast } from '@/components/ui/Toast'
import { useEvents } from '../hooks/useEvents'
import EventCreateForm from '../components/EventCreateForm'

export default function EventCreatePage() {
  const router = useRouter()
  const supabase = createClient()
  const [userId, setUserId] = useState<string | undefined>()
  const [authLoading, setAuthLoading] = useState(true)

  useEffect(() => {
    const check = async () => {
      const { data: { session } } = await supabase.auth.getSession()
      if (!session) {
        router.replace('/auth?mode=login')
        return
      }
      setUserId(session.user.id)
      setAuthLoading(false)
    }
    check()
  }, [supabase, router])

  const events = useEvents(userId)

  const handleSubmit = async (data: Parameters<typeof events.createEvent>[0]) => {
    try {
      const created = await events.createEvent(data)
      showToast.success('Veranstaltung erstellt!')
      router.push(`/dashboard/events/${created.id}`)
    } catch (err) {
      showToast.error('Fehler beim Erstellen der Veranstaltung')
      throw err
    }
  }

  const handleUpload = async (file: File) => {
    try {
      return await events.uploadImage(file)
    } catch (err) {
      showToast.error(err instanceof Error ? err.message : 'Upload fehlgeschlagen')
      throw err
    }
  }

  if (authLoading) {
    return (
      <div className="max-w-2xl mx-auto px-4 py-6">
        <div className="animate-pulse space-y-4">
          <div className="h-8 w-48 bg-mn-raised rounded" />
          <div className="h-10 w-full bg-mn-raised rounded-lg" />
          <div className="h-32 w-full bg-mn-raised rounded-lg" />
          <div className="h-10 w-full bg-mn-raised rounded-lg" />
        </div>
      </div>
    )
  }

  return (
    <div className="max-w-2xl mx-auto px-4 py-6">
      {/* Header */}
      <div className="flex items-center gap-3 mb-6">
        <button
          onClick={() => router.back()}
          className="p-2 rounded-lg border border-white/5 hover:bg-mn-surface transition"
        >
          <ArrowLeft className="w-4 h-4 text-mn-ink-soft" />
        </button>
        <div className="flex items-center gap-2">
          <div className="p-2 rounded-xl bg-mn-bronze/10">
            <CalendarPlus className="w-5 h-5 text-mn-bronze" />
          </div>
          <div>
            <h1 className="text-lg font-bold text-mn-ink">Veranstaltung erstellen</h1>
            <p className="text-sm text-mn-mute">Lade deine Nachbarn ein</p>
          </div>
        </div>
      </div>

      {/* Form */}
      <div className="bg-mn-elevated rounded-xl border border-white/5 p-4 sm:p-6">
        <EventCreateForm onSubmit={handleSubmit} onUploadImage={handleUpload} />
      </div>
    </div>
  )
}
