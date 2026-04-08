'use client'

import { useState } from 'react'
import { Send, Building2, CheckCircle } from 'lucide-react'
import { cn } from '@/lib/utils'
import {
  ORGANIZATION_CATEGORY_CONFIG,
  COUNTRY_FLAGS, COUNTRY_LABELS,
  type OrganizationCategory, type CreateSuggestionInput,
} from '../types'

interface Props {
  userId: string | null
  onSubmit: (input: CreateSuggestionInput, userId: string) => Promise<void>
  submitting: boolean
}

export default function SuggestionForm({ userId, onSubmit, submitting }: Props) {
  const [success, setSuccess] = useState(false)
  const [form, setForm] = useState<CreateSuggestionInput>({
    name: '',
    description: '',
    category: 'allgemein',
    address: '',
    city: '',
    country: 'DE',
    phone: '',
    email: '',
    website: '',
  })

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!userId || !form.name.trim()) return
    try {
      await onSubmit(form, userId)
      setSuccess(true)
      setForm({
        name: '', description: '', category: 'allgemein',
        address: '', city: '', country: 'DE',
        phone: '', email: '', website: '',
      })
    } catch (err) {
      // Error handled by store
    }
  }

  if (success) {
    return (
      <div className="text-center py-12 bg-white rounded-2xl border border-gray-100">
        <CheckCircle className="w-12 h-12 text-emerald-500 mx-auto mb-3" />
        <h2 className="text-lg font-bold text-gray-900 mb-1">Vielen Dank!</h2>
        <p className="text-gray-600 text-sm mb-4">
          Dein Vorschlag wurde eingereicht und wird von unserem Team geprueft.
        </p>
        <button
          onClick={() => setSuccess(false)}
          className="px-4 py-2 bg-emerald-50 text-emerald-700 rounded-xl text-sm font-medium hover:bg-emerald-100 transition-colors"
        >
          Weiteren Vorschlag einreichen
        </button>
      </div>
    )
  }

  if (!userId) {
    return (
      <div className="text-center py-12 bg-white rounded-2xl border border-gray-100">
        <Building2 className="w-10 h-10 text-gray-300 mx-auto mb-3" />
        <p className="text-gray-500 font-medium">Bitte melde dich an, um einen Vorschlag einzureichen.</p>
      </div>
    )
  }

  return (
    <form onSubmit={handleSubmit} className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5 space-y-4">
      <div>
        <h2 className="text-lg font-bold text-gray-900 mb-1">Organisation vorschlagen</h2>
        <p className="text-sm text-gray-500">
          Kennst du eine Hilfsorganisation, die noch fehlt? Schlage sie hier vor!
        </p>
      </div>

      {/* Name */}
      <div>
        <label htmlFor="org-name" className="block text-sm font-medium text-gray-700 mb-1">
          Name der Organisation *
        </label>
        <input
          id="org-name"
          type="text"
          required
          minLength={3}
          value={form.name}
          onChange={e => setForm(f => ({ ...f, name: e.target.value }))}
          placeholder="z.B. Caritas Berlin"
          className="w-full text-sm p-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-emerald-300"
        />
      </div>

      {/* Description */}
      <div>
        <label htmlFor="org-desc" className="block text-sm font-medium text-gray-700 mb-1">
          Beschreibung
        </label>
        <textarea
          id="org-desc"
          value={form.description}
          onChange={e => setForm(f => ({ ...f, description: e.target.value }))}
          placeholder="Was bietet die Organisation an?"
          className="w-full text-sm p-3 border border-gray-200 rounded-xl resize-none focus:outline-none focus:ring-2 focus:ring-emerald-300"
          rows={3}
        />
      </div>

      {/* Category */}
      <div>
        <label htmlFor="org-cat" className="block text-sm font-medium text-gray-700 mb-1">
          Kategorie *
        </label>
        <select
          id="org-cat"
          value={form.category}
          onChange={e => setForm(f => ({ ...f, category: e.target.value as OrganizationCategory }))}
          className="w-full text-sm p-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-emerald-300 bg-white"
        >
          {ORGANIZATION_CATEGORY_CONFIG.map(cat => (
            <option key={cat.value} value={cat.value}>{cat.label}</option>
          ))}
        </select>
      </div>

      {/* Country + City */}
      <div className="grid grid-cols-2 gap-3">
        <div>
          <label htmlFor="org-country" className="block text-sm font-medium text-gray-700 mb-1">
            Land
          </label>
          <select
            id="org-country"
            value={form.country}
            onChange={e => setForm(f => ({ ...f, country: e.target.value }))}
            className="w-full text-sm p-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-emerald-300 bg-white"
          >
            <option value="DE">{COUNTRY_FLAGS.DE} Deutschland</option>
            <option value="AT">{COUNTRY_FLAGS.AT} Oesterreich</option>
            <option value="CH">{COUNTRY_FLAGS.CH} Schweiz</option>
          </select>
        </div>
        <div>
          <label htmlFor="org-city" className="block text-sm font-medium text-gray-700 mb-1">
            Stadt
          </label>
          <input
            id="org-city"
            type="text"
            value={form.city}
            onChange={e => setForm(f => ({ ...f, city: e.target.value }))}
            placeholder="z.B. Berlin"
            className="w-full text-sm p-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-emerald-300"
          />
        </div>
      </div>

      {/* Address */}
      <div>
        <label htmlFor="org-addr" className="block text-sm font-medium text-gray-700 mb-1">
          Adresse
        </label>
        <input
          id="org-addr"
          type="text"
          value={form.address}
          onChange={e => setForm(f => ({ ...f, address: e.target.value }))}
          placeholder="Strasse und Hausnummer"
          className="w-full text-sm p-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-emerald-300"
        />
      </div>

      {/* Contact */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <div>
          <label htmlFor="org-phone" className="block text-sm font-medium text-gray-700 mb-1">
            Telefon
          </label>
          <input
            id="org-phone"
            type="tel"
            value={form.phone}
            onChange={e => setForm(f => ({ ...f, phone: e.target.value }))}
            placeholder="+49 ..."
            className="w-full text-sm p-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-emerald-300"
          />
        </div>
        <div>
          <label htmlFor="org-email" className="block text-sm font-medium text-gray-700 mb-1">
            E-Mail
          </label>
          <input
            id="org-email"
            type="email"
            value={form.email}
            onChange={e => setForm(f => ({ ...f, email: e.target.value }))}
            placeholder="info@..."
            className="w-full text-sm p-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-emerald-300"
          />
        </div>
      </div>

      {/* Website */}
      <div>
        <label htmlFor="org-web" className="block text-sm font-medium text-gray-700 mb-1">
          Website
        </label>
        <input
          id="org-web"
          type="url"
          value={form.website}
          onChange={e => setForm(f => ({ ...f, website: e.target.value }))}
          placeholder="https://..."
          className="w-full text-sm p-3 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-emerald-300"
        />
      </div>

      {/* Submit */}
      <button
        type="submit"
        disabled={submitting || !form.name.trim()}
        className="flex items-center gap-2 px-6 py-3 bg-emerald-600 text-white font-medium rounded-xl hover:bg-emerald-700 disabled:opacity-50 transition-colors text-sm"
      >
        <Send className="w-4 h-4" />
        {submitting ? 'Wird eingereicht...' : 'Vorschlag einreichen'}
      </button>
    </form>
  )
}
