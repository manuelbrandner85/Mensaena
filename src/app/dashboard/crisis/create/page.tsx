'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { ArrowLeft, Siren } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import CrisisCreateForm from '../components/CrisisCreateForm'
import CrisisSkeleton from '../components/CrisisSkeleton'
import { useCrisisStore } from '../stores/useCrisisStore'

export default function CrisisCreatePage() {
  const router = useRouter()
  const [userId, setUserId] = useState<string | null>(null)
  const [authLoading, setAuthLoading] = useState(true)
  const { createCrisis, uploadImage } = useCrisisStore()

  useEffect(() => {
    const supabase = createClient()
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (!session?.user) {
        router.replace('/auth?mode=login')
        return
      }
      setUserId(session.user.id)
      setAuthLoading(false)
    })
  }, [router])

  const handleSubmit = async (input: Parameters<typeof createCrisis>[0]) => {
    if (!userId) return
    try {
      const crisis = await createCrisis(input, userId)
      toast.success('Krise gemeldet! Helfer werden benachrichtigt.', { duration: 5000 })
      router.push(`/dashboard/crisis/${crisis.id}`)
    } catch (e: any) {
      toast.error(e?.message || 'Fehler beim Melden der Krise.')
      throw e
    }
  }

  if (authLoading) {
    return <CrisisSkeleton count={2} />
  }

  return (
    <div className="max-w-2xl mx-auto">
      {/* Header */}
      <div className="mb-6">
        <Link
          href="/dashboard/crisis"
          className="inline-flex items-center gap-1 text-sm text-gray-500 hover:text-gray-700 mb-3"
        >
          <ArrowLeft className="w-4 h-4" />
          Zurück zur Krisenhilfe
        </Link>

        <div className="flex items-center gap-3">
          <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-red-500 to-rose-600 flex items-center justify-center shadow-lg shadow-red-200">
            <Siren className="w-6 h-6 text-white" />
          </div>
          <div>
            <h1 className="text-xl font-black text-gray-900">Krise melden</h1>
            <p className="text-sm text-gray-500">Melde einen Notfall und mobilisiere Helfer in deiner Nähe</p>
          </div>
        </div>
      </div>

      {/* Warning banner */}
      <div className="bg-amber-50 border border-amber-200 rounded-2xl p-4 mb-6">
        <p className="text-xs text-amber-800 font-medium">
          <strong>Wichtig:</strong> Bei akuter Lebensgefahr rufe zuerst <a href="tel:112" className="underline font-bold">112</a> an!
          Nutze dieses Formular um Nachbarn zu mobilisieren und Hilfe zu koordinieren.
        </p>
        <p className="text-xs text-amber-600 mt-1">
          Missbrauch (Fehlalarme) führt zu einer 7-tägigen Sperre und Trust-Score-Minderung.
        </p>
      </div>

      {/* Create form */}
      <CrisisCreateForm
        onSubmit={handleSubmit}
        onUploadImage={uploadImage}
      />
    </div>
  )
}
