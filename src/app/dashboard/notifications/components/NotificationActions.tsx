'use client'

import { useState } from 'react'
import { CheckCheck, Trash2, Settings } from 'lucide-react'
import { useRouter } from 'next/navigation'
import Modal from '@/components/ui/Modal'
import toast from 'react-hot-toast'
import type { NotificationFilter } from '@/store/useNotificationStore'

interface Props {
  activeFilter: NotificationFilter
  unreadCount: number
  onMarkAllRead: (category?: string) => Promise<number>
  onDeleteAll: (category?: string) => Promise<number>
}

export default function NotificationActions({ activeFilter, unreadCount, onMarkAllRead, onDeleteAll }: Props) {
  const router = useRouter()
  const [confirmDelete, setConfirmDelete] = useState(false)
  const [markingRead, setMarkingRead] = useState(false)

  const handleMarkAllRead = async () => {
    setMarkingRead(true)
    try {
      const category = activeFilter !== 'all' ? activeFilter : undefined
      const count = await onMarkAllRead(category)
      if (count > 0) {
        toast.success(`${count} Benachrichtigung${count > 1 ? 'en' : ''} als gelesen markiert`)
      }
    } finally {
      setMarkingRead(false)
    }
  }

  const handleDeleteAll = async () => {
    const category = activeFilter !== 'all' ? activeFilter : undefined
    try {
      const count = await onDeleteAll(category)
      setConfirmDelete(false)
      if (count > 0) {
        toast.success(`${count} Benachrichtigung${count > 1 ? 'en' : ''} gelöscht`)
      }
    } catch {
      setConfirmDelete(false)
      toast.error('Löschen fehlgeschlagen – bitte erneut versuchen')
    }
  }

  return (
    <>
      <div className="flex items-center gap-1">
        <button
          onClick={handleMarkAllRead}
          disabled={unreadCount === 0 || markingRead}
          title="Alle als gelesen markieren"
          className="p-2 rounded-xl text-ink-500 hover:bg-stone-100 hover:text-primary-600 disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
          aria-label="Alle als gelesen markieren"
        >
          <CheckCheck className="w-4 h-4" />
        </button>
        <button
          onClick={() => setConfirmDelete(true)}
          title="Alle löschen"
          className="p-2 rounded-xl text-ink-500 hover:bg-red-50 hover:text-red-600 transition-colors"
          aria-label="Alle löschen"
        >
          <Trash2 className="w-4 h-4" />
        </button>
        <button
          onClick={() => router.push('/dashboard/settings')}
          title="Einstellungen"
          className="p-2 rounded-xl text-ink-500 hover:bg-stone-100 hover:text-ink-700 transition-colors"
          aria-label="Benachrichtigungs-Einstellungen"
        >
          <Settings className="w-4 h-4" />
        </button>
      </div>

      <Modal
        open={confirmDelete}
        onClose={() => setConfirmDelete(false)}
        title={activeFilter !== 'all' ? 'Kategorie löschen' : 'Alle löschen'}
        size="sm"
        footer={
          <div className="flex gap-2 justify-end">
            <button
              onClick={() => setConfirmDelete(false)}
              className="px-4 py-2 text-sm font-medium text-ink-700 bg-stone-100 hover:bg-stone-200 rounded-xl transition-colors"
            >
              Abbrechen
            </button>
            <button
              onClick={handleDeleteAll}
              className="px-4 py-2 text-sm font-medium text-white bg-red-600 hover:bg-red-700 rounded-xl transition-colors"
            >
              Löschen
            </button>
          </div>
        }
      >
        <p className="text-sm text-ink-600">
          {activeFilter !== 'all'
            ? `Möchtest du alle Benachrichtigungen in dieser Kategorie löschen?`
            : `Möchtest du wirklich alle Benachrichtigungen löschen?`
          }{' '}
          Diese Aktion kann nicht rückgängig gemacht werden.
        </p>
      </Modal>
    </>
  )
}
