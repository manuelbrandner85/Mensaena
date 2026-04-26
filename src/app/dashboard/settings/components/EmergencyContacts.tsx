'use client'

import { useState } from 'react'
import { Plus, X, Phone, User, Heart } from 'lucide-react'
import { useTranslations } from 'next-intl'
import type { EmergencyContact } from '../types'

interface Props {
  contacts: EmergencyContact[]
  onChange: (contacts: EmergencyContact[]) => void
  readOnly?: boolean
}

const RELATION_OPTIONS = [
  'Partner/in', 'Elternteil', 'Kind', 'Geschwister', 'Freund/in', 'Nachbar/in', 'Sonstige',
]

export default function EmergencyContacts({ contacts, onChange, readOnly = false }: Props) {
  const t = useTranslations('emergencyContacts')
  const [newContact, setNewContact] = useState<EmergencyContact>({ name: '', phone: '', relationship: '' })
  const [adding, setAdding] = useState(false)

  const handleAdd = () => {
    if (!newContact.name.trim() || !newContact.phone.trim()) return
    onChange([...contacts, { ...newContact, name: newContact.name.trim(), phone: newContact.phone.trim() }])
    setNewContact({ name: '', phone: '', relationship: '' })
    setAdding(false)
  }

  const handleRemove = (index: number) => {
    onChange(contacts.filter((_, i) => i !== index))
  }

  return (
    <div className="space-y-3">
      {contacts.length === 0 && !adding && (
        <div className="text-center py-4">
          <Heart className="w-8 h-8 text-stone-400 mx-auto mb-2" />
          <p className="text-sm text-ink-500">{t('noContacts')}</p>
          <p className="text-xs text-ink-400 mt-1">{t('noContactsDesc')}</p>
        </div>
      )}

      {contacts.map((contact, i) => (
        <div key={i} className="flex items-center gap-3 p-3 rounded-xl bg-stone-50 border border-stone-200">
          <div className="w-8 h-8 rounded-full bg-red-100 flex items-center justify-center flex-shrink-0">
            <Phone className="w-4 h-4 text-red-600" />
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-sm font-medium text-ink-900 truncate">{contact.name}</p>
            <p className="text-xs text-ink-500">{contact.phone}{contact.relationship ? ` · ${contact.relationship}` : ''}</p>
          </div>
          {!readOnly && (
            <button onClick={() => handleRemove(i)} className="p-1 rounded-lg hover:bg-red-50 text-ink-400 hover:text-red-600 transition-colors min-w-[44px] min-h-[44px] flex items-center justify-center">
              <X className="w-4 h-4" />
            </button>
          )}
        </div>
      ))}

      {adding ? (
        <div className="border border-primary-200 rounded-xl p-4 space-y-3 bg-primary-50/30">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="label">{t('labelName')}</label>
              <div className="relative">
                <User className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-ink-400" />
                <input
                  value={newContact.name}
                  onChange={e => setNewContact(p => ({ ...p, name: e.target.value }))}
                  placeholder={t('placeholderName')}
                  className="input pl-10"
                />
              </div>
            </div>
            <div>
              <label className="label">{t('labelPhone')}</label>
              <div className="relative">
                <Phone className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-ink-400" />
                <input
                  value={newContact.phone}
                  onChange={e => setNewContact(p => ({ ...p, phone: e.target.value }))}
                  placeholder={t('placeholderPhone')}
                  className="input pl-10"
                  type="tel"
                />
              </div>
            </div>
          </div>
          <div>
            <label className="label">{t('labelRelation')}</label>
            <select
              value={newContact.relationship}
              onChange={e => setNewContact(p => ({ ...p, relationship: e.target.value }))}
              className="input"
            >
              <option value="">{t('relationPlaceholder')}</option>
              {RELATION_OPTIONS.map(r => <option key={r} value={r}>{r}</option>)}
            </select>
          </div>
          <div className="flex gap-2">
            <button onClick={handleAdd} className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium bg-primary-600 text-white hover:bg-primary-700 transition-all min-h-[36px]">
              {t('addButton')}
            </button>
            <button onClick={() => setAdding(false)} className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium bg-stone-100 text-ink-600 hover:bg-stone-200 transition-all min-h-[36px]">
              {t('cancelButton')}
            </button>
          </div>
        </div>
      ) : !readOnly && contacts.length < 3 && (
        <button
          onClick={() => setAdding(true)}
          className="w-full flex items-center justify-center gap-1.5 py-2.5 rounded-xl text-sm font-medium border-2 border-dashed border-stone-200 text-ink-500 hover:border-primary-300 hover:text-primary-600 transition-colors min-h-[44px]"
        >
          <Plus className="w-4 h-4" /> {t('addContact')}
        </button>
      )}

      {contacts.length >= 3 && !readOnly && (
        <p className="text-xs text-ink-400 text-center">{t('maxContacts')}</p>
      )}
    </div>
  )
}
