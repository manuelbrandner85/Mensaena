'use client'
export const runtime = 'edge'

import { useState, useEffect, Suspense } from 'react'
import { useSearchParams, useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import { FilePlus, MapPin, Phone, MessageCircle, Image as ImageIcon, X } from 'lucide-react'
import { cn } from '@/lib/utils'

const TYPES = [
  { value: 'help_request', label: '🔴 Hilfe suchen',    desc: 'Du brauchst Unterstützung' },
  { value: 'help_offer',   label: '🟢 Hilfe anbieten',  desc: 'Du kannst helfen'          },
  { value: 'rescue',       label: '🧡 Retter-Angebot',  desc: 'Ressourcen retten'         },
  { value: 'animal',       label: '🐾 Tierhilfe',        desc: 'Tier sucht/bietet Hilfe'  },
  { value: 'housing',      label: '🏡 Wohnangebot',      desc: 'Wohnung oder Notunterkunft'},
  { value: 'supply',       label: '🌾 Versorgung',       desc: 'Produkt anbieten/suchen'  },
  { value: 'skill',        label: '⭐ Skill teilen',      desc: 'Fähigkeit anbieten'        },
  { value: 'mobility',     label: '🚗 Mobilität',        desc: 'Fahrt anbieten/suchen'     },
  { value: 'sharing',      label: '🔄 Teilen/Tauschen',  desc: 'Gegenstände teilen'        },
  { value: 'community',    label: '🗳️ Community',        desc: 'Abstimmung oder Idee'     },
  { value: 'crisis',       label: '🚨 Notfall',          desc: 'Dringende Hilfe nötig'    },
  { value: 'knowledge',    label: '📚 Wissen teilen',    desc: 'Guide oder Tutorial'       },
  { value: 'mental',       label: '💙 Mentale Hilfe',    desc: 'Gespräch oder Begleitung'  },
]

const CATEGORIES = [
  { value: 'food',      label: '🍎 Essen'            },
  { value: 'everyday',  label: '🏠 Alltag'           },
  { value: 'moving',    label: '📦 Umzug'            },
  { value: 'animals',   label: '🐾 Tiere'            },
  { value: 'housing',   label: '🏡 Wohnen'           },
  { value: 'skills',    label: '🛠️ Fähigkeiten'     },
  { value: 'knowledge', label: '📚 Bildung'          },
  { value: 'mental',    label: '💙 Mentales'         },
  { value: 'mobility',  label: '🚗 Mobilität'        },
  { value: 'sharing',   label: '🔄 Teilen/Tauschen'  },
  { value: 'community', label: '👥 Community'        },
  { value: 'emergency', label: '🚨 Notfall'          },
  { value: 'general',   label: '🌿 Sonstiges'        },
]

function CreatePostForm() {
  const searchParams = useSearchParams()
  const router = useRouter()
  const initialType = searchParams.get('type') ?? 'help_request'

  const [step, setStep] = useState(1)
  const [userId, setUserId] = useState<string>()
  const [loading, setLoading] = useState(false)
  const [form, setForm] = useState({
    type: initialType,
    category: 'general',
    title: '',
    description: '',
    location_text: '',
    contact_phone: '',
    contact_whatsapp: '',
    urgency: 'normal',
  })

  useEffect(() => {
    createClient().auth.getUser().then(({ data: { user } }) => {
      if (user) setUserId(user.id)
    })
  }, [])

  const set = (k: string, v: string) => setForm(f => ({ ...f, [k]: v }))

  const handleSubmit = async () => {
    if (!userId) return
    if (!form.title.trim()) { toast.error('Bitte Titel eingeben'); return }
    if (!form.contact_phone && !form.contact_whatsapp) {
      toast.error('Mindestens Telefon oder WhatsApp ist Pflicht')
      return
    }
    setLoading(true)
    const supabase = createClient()
    const { data, error } = await supabase.from('posts').insert({
      user_id: userId,
      type: form.type,
      category: form.category,
      title: form.title.trim(),
      description: form.description.trim(),
      location_text: form.location_text.trim(),
      contact_phone: form.contact_phone.trim(),
      contact_whatsapp: form.contact_whatsapp.trim(),
      urgency: form.urgency,
      status: 'active',
    }).select().single()
    setLoading(false)
    if (error) { toast.error('Fehler: ' + error.message); return }
    toast.success('Beitrag erfolgreich veröffentlicht! 🌿')
    router.push('/dashboard/posts')
  }

  const selectedType = TYPES.find(t => t.value === form.type)

  return (
    <div className="max-w-2xl mx-auto">
      {/* Header */}
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
          <FilePlus className="w-6 h-6 text-primary-600" />
          Neuen Beitrag erstellen
        </h1>
        <p className="text-gray-500 text-sm mt-1">Dein Beitrag wird sofort in Feed, Karte und passenden Modulen sichtbar</p>
      </div>

      {/* Fortschrittsanzeige */}
      <div className="flex items-center gap-2 mb-8">
        {[1,2,3].map(s => (
          <div key={s} className="flex items-center gap-2 flex-1">
            <div className={cn('w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold transition-all',
              step >= s ? 'bg-primary-600 text-white' : 'bg-warm-100 text-gray-400')}>
              {s}
            </div>
            <span className={cn('text-xs font-medium', step >= s ? 'text-primary-700' : 'text-gray-400')}>
              {s === 1 ? 'Art & Kategorie' : s === 2 ? 'Inhalt' : 'Kontakt'}
            </span>
            {s < 3 && <div className={cn('flex-1 h-0.5 transition-all', step > s ? 'bg-primary-400' : 'bg-warm-200')} />}
          </div>
        ))}
      </div>

      <div className="bg-white rounded-2xl border border-warm-200 p-6 shadow-sm">

        {/* Schritt 1: Art & Kategorie */}
        {step === 1 && (
          <div className="space-y-5">
            <div>
              <label className="label text-base font-semibold">Welche Art von Beitrag? *</label>
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-2 mt-2">
                {TYPES.map(t => (
                  <button key={t.value} type="button" onClick={() => set('type', t.value)}
                    className={cn('p-3 rounded-xl border text-left transition-all',
                      form.type === t.value
                        ? 'bg-primary-50 border-primary-400 ring-1 ring-primary-300'
                        : 'bg-white border-warm-200 hover:border-primary-200')}>
                    <div className="text-sm font-semibold text-gray-800">{t.label}</div>
                    <div className="text-xs text-gray-500 mt-0.5">{t.desc}</div>
                  </button>
                ))}
              </div>
            </div>

            <div>
              <label className="label text-base font-semibold">Kategorie *</label>
              <div className="grid grid-cols-3 gap-2 mt-2">
                {CATEGORIES.map(c => (
                  <button key={c.value} type="button" onClick={() => set('category', c.value)}
                    className={cn('px-3 py-2 rounded-xl border text-sm font-medium text-center transition-all',
                      form.category === c.value
                        ? 'bg-primary-600 text-white border-primary-600'
                        : 'bg-white text-gray-700 border-warm-200 hover:border-primary-200')}>
                    {c.label}
                  </button>
                ))}
              </div>
            </div>

            <div>
              <label className="label text-base font-semibold">Dringlichkeit</label>
              <div className="flex gap-2 mt-2">
                {[['normal','🟦 Normal'],['medium','🟧 Mittel'],['high','🔴 Dringend']].map(([v,l]) => (
                  <button key={v} type="button" onClick={() => set('urgency', v)}
                    className={cn('flex-1 py-2.5 rounded-xl text-sm font-semibold border transition-all',
                      form.urgency === v
                        ? v === 'high' ? 'bg-red-600 text-white border-red-600'
                          : v === 'medium' ? 'bg-orange-500 text-white border-orange-500'
                          : 'bg-primary-600 text-white border-primary-600'
                        : 'bg-white text-gray-600 border-warm-200 hover:border-primary-200')}>
                    {l}
                  </button>
                ))}
              </div>
            </div>

            <button onClick={() => setStep(2)} className="btn-primary w-full py-3">
              Weiter →
            </button>
          </div>
        )}

        {/* Schritt 2: Inhalt */}
        {step === 2 && (
          <div className="space-y-5">
            <div className="flex items-center gap-2 p-3 bg-primary-50 rounded-xl border border-primary-200">
              <span className="text-sm font-semibold text-primary-700">{selectedType?.label}</span>
              <button onClick={() => setStep(1)} className="ml-auto text-xs text-primary-500 hover:underline">Ändern</button>
            </div>

            <div>
              <label className="label">Titel *</label>
              <input value={form.title} onChange={e => set('title', e.target.value)}
                placeholder="Kurze, klare Beschreibung deines Beitrags"
                maxLength={80} className="input" required />
              <p className="text-xs text-gray-400 mt-1">{form.title.length}/80 Zeichen</p>
            </div>

            <div>
              <label className="label">Beschreibung</label>
              <textarea value={form.description} onChange={e => set('description', e.target.value)}
                placeholder="Was genau benötigst du oder was bietest du an? Sei so konkret wie möglich."
                rows={5} className="input resize-none" />
            </div>

            <div>
              <label className="label flex items-center gap-1.5">
                <MapPin className="w-4 h-4 text-gray-400" /> Standort / Ort
              </label>
              <input value={form.location_text} onChange={e => set('location_text', e.target.value)}
                placeholder="z.B. Wien 1070, Graz-Mitte, München Schwabing" className="input" />
            </div>

            <div className="flex gap-3">
              <button onClick={() => setStep(1)} className="btn-secondary flex-1">← Zurück</button>
              <button onClick={() => setStep(3)} disabled={!form.title.trim()} className="btn-primary flex-1">
                Weiter →
              </button>
            </div>
          </div>
        )}

        {/* Schritt 3: Kontakt */}
        {step === 3 && (
          <div className="space-y-5">
            <div className="p-3 bg-amber-50 border border-amber-200 rounded-xl text-sm text-amber-700">
              ⚠️ Ohne Kontaktmöglichkeit kann niemand auf deinen Beitrag reagieren.
              Mindestens <strong>Telefon oder WhatsApp</strong> ist Pflicht.
            </div>

            <div>
              <label className="label flex items-center gap-1.5">
                <Phone className="w-4 h-4 text-gray-400" /> Telefonnummer
              </label>
              <input value={form.contact_phone} onChange={e => set('contact_phone', e.target.value)}
                placeholder="+43 660 123 4567" className="input" />
            </div>

            <div>
              <label className="label flex items-center gap-1.5">
                <MessageCircle className="w-4 h-4 text-green-600" /> WhatsApp-Nummer
              </label>
              <input value={form.contact_whatsapp} onChange={e => set('contact_whatsapp', e.target.value)}
                placeholder="+43 660 123 4567" className="input" />
            </div>

            {/* Zusammenfassung */}
            <div className="p-4 bg-gray-50 rounded-xl border border-warm-200 space-y-2">
              <p className="text-sm font-semibold text-gray-700">📋 Zusammenfassung</p>
              <div className="text-xs text-gray-600 space-y-1">
                <p><span className="font-medium">Art:</span> {selectedType?.label}</p>
                <p><span className="font-medium">Titel:</span> {form.title}</p>
                {form.location_text && <p><span className="font-medium">Ort:</span> {form.location_text}</p>}
                <p><span className="font-medium">Dringlichkeit:</span> {form.urgency}</p>
              </div>
            </div>

            <div className="flex gap-3">
              <button onClick={() => setStep(2)} className="btn-secondary flex-1">← Zurück</button>
              <button onClick={handleSubmit} disabled={loading || (!form.contact_phone && !form.contact_whatsapp)}
                className="btn-primary flex-1 py-3">
                {loading
                  ? <span className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                  : '🌿 Jetzt veröffentlichen'}
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}

export default function CreatePage() {
  return (
    <Suspense fallback={<div className="flex justify-center py-16"><div className="w-8 h-8 border-4 border-primary-300 border-t-primary-600 rounded-full animate-spin" /></div>}>
      <CreatePostForm />
    </Suspense>
  )
}
