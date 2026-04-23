'use client'

import { useEffect, useState } from 'react'
import Link from 'next/link'
import {
  Heart, Coffee, Users, Shield, ArrowLeft,
  CreditCard, Building2, Star, Award,
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { cn } from '@/lib/utils'

const TIERS = [
  {
    icon: Coffee,
    amount: 5,
    label: 'Kaffee',
    description: 'Ein Monat Chat-Server',
    color: 'text-amber-600',
    bg: 'bg-amber-50',
    border: 'border-amber-200',
  },
  {
    icon: Users,
    amount: 10,
    label: 'Nachbar:in',
    description: 'Push-Benachrichtigungen für 200 Nutzer',
    color: 'text-primary-600',
    bg: 'bg-primary-50',
    border: 'border-primary-200',
  },
  {
    icon: Star,
    amount: 25,
    label: 'Held:in',
    description: 'Einen Monat Kartenservice',
    color: 'text-violet-600',
    bg: 'bg-violet-50',
    border: 'border-violet-200',
  },
  {
    icon: Award,
    amount: 50,
    label: 'Botschafter:in',
    description: 'Krisenmodus für eine Stadt',
    color: 'text-rose-600',
    bg: 'bg-rose-50',
    border: 'border-rose-200',
  },
]

const COSTS = [
  { label: 'Server & Infrastruktur', value: '~30 €/Monat', icon: Shield },
  { label: 'Domain & SSL', value: '~15 €/Jahr', icon: CreditCard },
  { label: 'SMS-Verifikation', value: '~0,05 €/Nutzer', icon: Users },
  { label: 'Entwicklung', value: 'ehrenamtlich', icon: Heart },
]

export default function SpendenPage() {
  const [userCount, setUserCount] = useState<number | null>(null)

  useEffect(() => {
    const supabase = createClient()
    supabase
      .from('profiles')
      .select('*', { count: 'exact', head: true })
      .then(({ count }) => {
        if (count !== null) setUserCount(count)
      })
  }, [])

  const costPerPerson =
    userCount && userCount > 0 ? (30 / userCount).toFixed(2) : null

  return (
    <div className="min-h-screen bg-[#EEF9F9]">
      <div className="max-w-2xl mx-auto px-4 py-8 space-y-6">

        {/* Back link */}
        <Link
          href="/dashboard"
          className="inline-flex items-center gap-1.5 text-sm text-gray-500 hover:text-gray-700 transition-colors"
        >
          <ArrowLeft className="w-4 h-4" />
          Zurück
        </Link>

        {/* Header */}
        <div className="text-center space-y-2 py-4">
          <div className="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-rose-50 border border-rose-100 mb-2">
            <Heart className="w-7 h-7 text-rose-500" />
          </div>
          <h1 className="text-2xl font-bold text-gray-900">Mensaena unterstützen</h1>
          <p className="text-gray-500 text-sm leading-relaxed max-w-sm mx-auto">
            100&nbsp;% gemeinnützig. 0&nbsp;% Werbung.
            Deine Spende hält uns am Laufen.
          </p>
        </div>

        {/* Transparenz-Karte */}
        <div className="card p-5 space-y-4">
          <h2 className="font-semibold text-gray-900">Wo dein Geld hingeht</h2>
          <ul className="space-y-3">
            {COSTS.map(({ label, value, icon: Icon }) => (
              <li key={label} className="flex items-center justify-between text-sm">
                <span className="flex items-center gap-2 text-gray-600">
                  <Icon className="w-4 h-4 text-primary-500 flex-shrink-0" />
                  {label}
                </span>
                <span className="font-medium text-gray-800">{value}</span>
              </li>
            ))}
          </ul>

          {costPerPerson && userCount && (
            <p className="text-xs text-primary-700 bg-primary-50 rounded-xl px-4 py-3 leading-relaxed border border-primary-100">
              Bei <strong>{userCount.toLocaleString('de-DE')}</strong> Nachbar:innen kostet
              Mensaena nur <strong>{costPerPerson}&nbsp;€</strong> pro Person und Monat.
            </p>
          )}
        </div>

        {/* Spenden-Stufen */}
        <div className="space-y-3">
          <h2 className="font-semibold text-gray-900 px-1">Spenden-Stufen</h2>
          <div className="grid grid-cols-2 gap-3">
            {TIERS.map(({ icon: Icon, amount, label, description, color, bg, border }) => (
              <div
                key={label}
                className={cn(
                  'rounded-2xl border p-4 space-y-2 shadow-soft',
                  bg, border
                )}
              >
                <div className="flex items-center gap-2">
                  <Icon className={cn('w-5 h-5', color)} />
                  <span className={cn('font-bold text-base', color)}>{amount}&nbsp;€</span>
                </div>
                <p className="font-semibold text-gray-900 text-sm">{label}</p>
                <p className="text-xs text-gray-500 leading-relaxed">{description}</p>
              </div>
            ))}
          </div>
        </div>

        {/* Spenden-Optionen */}
        <div className="card p-5 space-y-5">
          <h2 className="font-semibold text-gray-900">So kannst du spenden</h2>

          {/* PayPal */}
          <div className="space-y-2">
            <div className="flex items-center gap-2 text-sm font-medium text-gray-700">
              <CreditCard className="w-4 h-4 text-[#003087]" />
              PayPal
            </div>
            {/* TODO: paypal.me/mensaena — realen Link hinterlegen */}
            <a
              href="https://paypal.me/mensaena"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-block text-sm text-primary-600 hover:underline font-medium"
            >
              paypal.me/mensaena
            </a>
          </div>

          <hr className="border-stone-100" />

          {/* Überweisung */}
          <div className="space-y-2">
            <div className="flex items-center gap-2 text-sm font-medium text-gray-700">
              <Building2 className="w-4 h-4 text-gray-500" />
              Banküberweisung
            </div>
            {/* TODO: echte Bankdaten hinterlegen */}
            <dl className="text-sm space-y-1">
              <div className="flex gap-2">
                <dt className="text-gray-400 w-24 flex-shrink-0">IBAN</dt>
                <dd className="font-mono text-gray-700 text-xs break-all">DE00 0000 0000 0000 0000 00</dd>
              </div>
              <div className="flex gap-2">
                <dt className="text-gray-400 w-24 flex-shrink-0">BIC</dt>
                <dd className="font-mono text-gray-700 text-xs">XXXXXXXX</dd>
              </div>
              <div className="flex gap-2">
                <dt className="text-gray-400 w-24 flex-shrink-0">Verwendungszweck</dt>
                <dd className="text-gray-700 text-xs">Spende Mensaena</dd>
              </div>
            </dl>
          </div>

          <p className="text-xs text-gray-400">
            Spendenbescheinigung auf Anfrage an{' '}
            <a href="mailto:info@mensaena.de" className="hover:underline text-gray-500">
              info@mensaena.de
            </a>
          </p>
        </div>

        {/* Supporter-Badge */}
        <div className="card p-5 flex items-start gap-4">
          <div className="flex-shrink-0 w-10 h-10 rounded-xl bg-amber-50 border border-amber-100 flex items-center justify-center">
            <Heart className="w-5 h-5 text-amber-500 fill-amber-400" />
          </div>
          <div>
            <p className="font-semibold text-gray-900 text-sm">Supporter-Badge</p>
            <p className="text-xs text-gray-500 mt-0.5 leading-relaxed">
              Spender:innen erhalten ein goldenes Herz-Badge in ihrem Profil –
              als sichtbares Dankeschön von der Community.
            </p>
          </div>
        </div>

      </div>
    </div>
  )
}
