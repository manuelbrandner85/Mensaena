'use client'

export const runtime = 'edge'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { ArrowLeft, Plus, Leaf, Truck } from 'lucide-react'
import Link from 'next/link'
import { createClient } from '@/lib/supabase/client'
import { FARM_CATEGORIES, FARM_PRODUCTS } from '@/types/farm'

export default function AddFarmPage() {
  const router = useRouter()
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState(false)

  const [form, setForm] = useState({
    name: '', category: 'Bauernhof', description: '',
    address: '', postal_code: '', city: '', state: '', country: 'AT',
    phone: '', email: '', website: '',
    products: [] as string[], services: '', delivery_options: '',
    is_bio: false, is_seasonal: false,
  })

  const set = (k: string, v: unknown) => setForm((p) => ({ ...p, [k]: v }))
  const toggleProduct = (p: string) => {
    setForm((prev) => ({
      ...prev,
      products: prev.products.includes(p)
        ? prev.products.filter((x) => x !== p)
        : [...prev.products, p],
    }))
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!form.name || !form.city) return setError('Name und Ort sind Pflichtfelder.')
    setLoading(true)
    setError('')

    const slug = form.name
      .toLowerCase()
      .replace(/[äöüß]/g, (c) => ({ ä: 'ae', ö: 'oe', ü: 'ue', ß: 'ss' }[c] || c))
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-|-$/g, '')
      + '-' + Date.now().toString(36)

    const supabase = createClient()
    const { error: err } = await supabase.from('farm_listings').insert({
      name: form.name,
      slug,
      category: form.category,
      description: form.description || null,
      address: form.address || null,
      postal_code: form.postal_code || null,
      city: form.city,
      state: form.state || null,
      country: form.country,
      phone: form.phone || null,
      email: form.email || null,
      website: form.website || null,
      products: form.products,
      services: form.services ? form.services.split(',').map((s) => s.trim()).filter(Boolean) : [],
      delivery_options: form.delivery_options
        ? form.delivery_options.split(',').map((s) => s.trim()).filter(Boolean)
        : [],
      is_bio: form.is_bio,
      is_seasonal: form.is_seasonal,
      is_verified: false,
      is_public: true,
      source_name: 'Nutzer-Eintrag',
    })

    setLoading(false)
    if (err) return setError('Fehler beim Speichern: ' + err.message)
    setSuccess(true)
    setTimeout(() => router.push('/dashboard/supply'), 2500)
  }

  if (success) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-green-50">
        <div className="text-center p-8">
          <span className="text-6xl mb-4 block">✅</span>
          <h2 className="text-2xl font-bold text-gray-900 mb-2">Betrieb eingetragen!</h2>
          <p className="text-gray-600 mb-1">Dein Eintrag wird nach Prüfung freigeschaltet.</p>
          <p className="text-sm text-gray-400">Du wirst weitergeleitet…</p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <div className="bg-gradient-to-r from-green-600 to-emerald-600 text-white px-4 sm:px-6 py-6">
        <div className="max-w-2xl mx-auto">
          <Link href="/dashboard/supply" className="flex items-center gap-2 text-green-100 hover:text-white text-sm mb-4">
            <ArrowLeft className="w-4 h-4" /> Zurück zur Übersicht
          </Link>
          <h1 className="text-2xl font-bold flex items-center gap-3">
            <Plus className="w-6 h-6" /> Betrieb kostenlos eintragen
          </h1>
          <p className="text-green-100 text-sm mt-1">
            Trage deinen Hof, Hofladen oder Direktvermarktungsbetrieb ein und werde sichtbar.
          </p>
        </div>
      </div>

      <div className="max-w-2xl mx-auto px-4 sm:px-6 py-8">
        <form onSubmit={handleSubmit} className="space-y-6">
          {/* Grunddaten */}
          <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6 space-y-4">
            <h2 className="font-bold text-gray-900 text-lg">Grunddaten</h2>

            <div>
              <label className="text-sm font-medium text-gray-700 mb-1.5 block">Betriebsname *</label>
              <input
                type="text"
                value={form.name}
                onChange={(e) => set('name', e.target.value)}
                placeholder="z.B. Biohof Mustermann"
                className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-green-300"
                required
              />
            </div>

            <div>
              <label className="text-sm font-medium text-gray-700 mb-1.5 block">Betriebstyp *</label>
              <select
                value={form.category}
                onChange={(e) => set('category', e.target.value)}
                className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-green-300"
              >
                {FARM_CATEGORIES.map((c) => (
                  <option key={c} value={c}>{c}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="text-sm font-medium text-gray-700 mb-1.5 block">Beschreibung</label>
              <textarea
                value={form.description}
                onChange={(e) => set('description', e.target.value)}
                rows={3}
                placeholder="Kurze Beschreibung deines Betriebs, was du anbietest, was dich besonders macht…"
                className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-green-300 resize-none"
              />
            </div>

            <div className="flex gap-4">
              <label className="flex items-center gap-2 cursor-pointer">
                <input type="checkbox" checked={form.is_bio} onChange={(e) => set('is_bio', e.target.checked)} className="w-4 h-4 accent-lime-600" />
                <span className="text-sm text-gray-700 flex items-center gap-1"><Leaf className="w-3.5 h-3.5 text-lime-600" /> Bio-zertifiziert</span>
              </label>
              <label className="flex items-center gap-2 cursor-pointer">
                <input type="checkbox" checked={form.is_seasonal} onChange={(e) => set('is_seasonal', e.target.checked)} className="w-4 h-4 accent-orange-500" />
                <span className="text-sm text-gray-700">🍂 Saisonal</span>
              </label>
            </div>
          </div>

          {/* Adresse */}
          <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6 space-y-4">
            <h2 className="font-bold text-gray-900 text-lg">Adresse</h2>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div className="sm:col-span-2">
                <label className="text-sm font-medium text-gray-700 mb-1.5 block">Straße & Hausnummer</label>
                <input type="text" value={form.address} onChange={(e) => set('address', e.target.value)}
                  placeholder="Musterstraße 1" className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-green-300" />
              </div>
              <div>
                <label className="text-sm font-medium text-gray-700 mb-1.5 block">Postleitzahl</label>
                <input type="text" value={form.postal_code} onChange={(e) => set('postal_code', e.target.value)}
                  placeholder="1010" className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-green-300" />
              </div>
              <div>
                <label className="text-sm font-medium text-gray-700 mb-1.5 block">Ort *</label>
                <input type="text" value={form.city} onChange={(e) => set('city', e.target.value)}
                  placeholder="Wien" required className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-green-300" />
              </div>
              <div>
                <label className="text-sm font-medium text-gray-700 mb-1.5 block">Bundesland / Kanton</label>
                <input type="text" value={form.state} onChange={(e) => set('state', e.target.value)}
                  placeholder="Niederösterreich" className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-green-300" />
              </div>
              <div>
                <label className="text-sm font-medium text-gray-700 mb-1.5 block">Land</label>
                <select value={form.country} onChange={(e) => set('country', e.target.value)}
                  className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-green-300">
                  <option value="AT">🇦🇹 Österreich</option>
                  <option value="DE">🇩🇪 Deutschland</option>
                  <option value="CH">🇨🇭 Schweiz</option>
                </select>
              </div>
            </div>
          </div>

          {/* Kontakt */}
          <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6 space-y-4">
            <h2 className="font-bold text-gray-900 text-lg">Kontakt</h2>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label className="text-sm font-medium text-gray-700 mb-1.5 block">Telefon</label>
                <input type="tel" value={form.phone} onChange={(e) => set('phone', e.target.value)}
                  placeholder="+43 1 234567" className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-green-300" />
              </div>
              <div>
                <label className="text-sm font-medium text-gray-700 mb-1.5 block">E-Mail</label>
                <input type="email" value={form.email} onChange={(e) => set('email', e.target.value)}
                  placeholder="hof@beispiel.at" className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-green-300" />
              </div>
              <div className="sm:col-span-2">
                <label className="text-sm font-medium text-gray-700 mb-1.5 block">Website</label>
                <input type="url" value={form.website} onChange={(e) => set('website', e.target.value)}
                  placeholder="https://www.meinbauernhof.at" className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-green-300" />
              </div>
            </div>
          </div>

          {/* Produkte */}
          <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
            <h2 className="font-bold text-gray-900 text-lg mb-4">Produkte</h2>
            <div className="flex flex-wrap gap-2">
              {FARM_PRODUCTS.map((p) => (
                <button
                  type="button"
                  key={p}
                  onClick={() => toggleProduct(p)}
                  className={`px-3 py-1.5 rounded-full text-sm border font-medium transition-all ${
                    form.products.includes(p)
                      ? 'bg-amber-500 text-white border-amber-500'
                      : 'bg-gray-50 text-gray-600 border-gray-200 hover:border-amber-300'
                  }`}
                >
                  {p}
                </button>
              ))}
            </div>
          </div>

          {/* Services & Lieferung */}
          <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6 space-y-4">
            <h2 className="font-bold text-gray-900 text-lg flex items-center gap-2">
              <Truck className="w-5 h-5 text-purple-500" /> Dienstleistungen & Lieferung
            </h2>
            <div>
              <label className="text-sm font-medium text-gray-700 mb-1.5 block">Angebote (kommagetrennt)</label>
              <input type="text" value={form.services} onChange={(e) => set('services', e.target.value)}
                placeholder="Hofladen, Führungen, Käserei, Selbsternte" className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-green-300" />
            </div>
            <div>
              <label className="text-sm font-medium text-gray-700 mb-1.5 block">Liefer-/Abholoptionen (kommagetrennt)</label>
              <input type="text" value={form.delivery_options} onChange={(e) => set('delivery_options', e.target.value)}
                placeholder="Abholung Hof, Lieferung Wien, Versand Österreich" className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-green-300" />
            </div>
          </div>

          {error && (
            <div className="bg-red-50 border border-red-200 text-red-700 rounded-xl p-4 text-sm">
              {error}
            </div>
          )}

          <div className="flex gap-4">
            <Link href="/dashboard/supply"
              className="flex-1 py-3 border border-gray-200 rounded-xl text-sm font-semibold text-gray-700 hover:bg-gray-50 transition-colors text-center">
              Abbrechen
            </Link>
            <button
              type="submit"
              disabled={loading}
              className="flex-1 py-3 bg-green-600 text-white rounded-xl text-sm font-semibold hover:bg-green-700 disabled:opacity-60 transition-colors flex items-center justify-center gap-2"
            >
              {loading ? (
                <><div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" /> Wird gespeichert…</>
              ) : (
                <><Plus className="w-4 h-4" /> Betrieb eintragen</>
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
