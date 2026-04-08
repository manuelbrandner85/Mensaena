'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import {
  ArrowLeft, Heart, Building2, Phone, BookOpen,
  ShieldCheck, Users, Brain, Home, Utensils, Baby,
} from 'lucide-react'
import { cn } from '@/lib/utils'
import { createClient } from '@/lib/supabase/client'
import QuickHelpNumbers from '../components/QuickHelpNumbers'
import CrisisSkeleton from '../components/CrisisSkeleton'

const RESOURCE_CATEGORIES = [
  {
    title: 'Psychologische Hilfe',
    icon: Brain,
    color: 'text-purple-700',
    bgColor: 'bg-purple-50',
    borderColor: 'border-purple-200',
    items: [
      { name: 'TelefonSeelsorge', desc: 'Kostenlos, anonym, 24/7', phone: '0800 111 0 111' },
      { name: 'Krisendienst', desc: 'Psychische Notfälle', phone: '112' },
      { name: 'Online-Beratung', desc: 'online.telefonseelsorge.de', url: 'https://online.telefonseelsorge.de' },
    ],
  },
  {
    title: 'Kinder & Jugend',
    icon: Baby,
    color: 'text-pink-700',
    bgColor: 'bg-pink-50',
    borderColor: 'border-pink-200',
    items: [
      { name: 'Kinder- & Jugendtelefon', desc: 'Mo-Sa 14-20 Uhr, kostenlos', phone: '116 111' },
      { name: 'Elterntelefon', desc: 'Mo-Fr 9-17 Uhr', phone: '0800 111 0 550' },
      { name: 'Jugendhilfe', desc: 'Jugendamt kontaktieren', url: '#' },
    ],
  },
  {
    title: 'Gewaltschutz',
    icon: ShieldCheck,
    color: 'text-rose-700',
    bgColor: 'bg-rose-50',
    borderColor: 'border-rose-200',
    items: [
      { name: 'Hilfetelefon Gewalt gegen Frauen', desc: 'Kostenlos, 24/7', phone: '116 016' },
      { name: 'Weisser Ring', desc: 'Opferhilfe', phone: '116 006' },
      { name: 'Frauenhaus-Suche', desc: 'frauenhaus-suche.de', url: 'https://www.frauenhaus-suche.de' },
    ],
  },
  {
    title: 'Wohnen & Obdach',
    icon: Home,
    color: 'text-amber-700',
    bgColor: 'bg-amber-50',
    borderColor: 'border-amber-200',
    items: [
      { name: 'Notschlafstellen', desc: 'Lokale Anlaufstellen', url: '#' },
      { name: 'Kältehilfe', desc: 'Im Winter aktiv', phone: '112' },
      { name: 'Sozialamt', desc: 'Wohnhilfe beantragen', url: '#' },
    ],
  },
  {
    title: 'Ernährung & Versorgung',
    icon: Utensils,
    color: 'text-emerald-700',
    bgColor: 'bg-emerald-50',
    borderColor: 'border-emerald-200',
    items: [
      { name: 'Tafeln', desc: 'tafel.de – Lebensmittelhilfe', url: 'https://www.tafel.de' },
      { name: 'Suppenküchen', desc: 'Lokale Angebote', url: '#' },
      { name: 'Mensaena Versorgung', desc: 'Regionale Hilfe', url: '/dashboard/supply' },
    ],
  },
  {
    title: 'Hilfsorganisationen',
    icon: Building2,
    color: 'text-blue-700',
    bgColor: 'bg-blue-50',
    borderColor: 'border-blue-200',
    items: [
      { name: 'Deutsches Rotes Kreuz', desc: 'drk.de', url: 'https://www.drk.de' },
      { name: 'THW', desc: 'Technisches Hilfswerk', url: 'https://www.thw.de' },
      { name: 'Caritas', desc: 'caritas.de', url: 'https://www.caritas.de' },
      { name: 'Diakonie', desc: 'diakonie.de', url: 'https://www.diakonie.de' },
    ],
  },
]

export default function CrisisResourcesPage() {
  const router = useRouter()
  const [authLoading, setAuthLoading] = useState(true)

  useEffect(() => {
    const supabase = createClient()
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (!session?.user) {
        router.replace('/auth?mode=login')
        return
      }
      setAuthLoading(false)
    })
  }, [router])

  if (authLoading) return <CrisisSkeleton count={3} />

  return (
    <div className="max-w-4xl mx-auto">
      {/* Header */}
      <div className="mb-6">
        <Link
          href="/dashboard/crisis"
          className="inline-flex items-center gap-1 text-sm text-gray-500 hover:text-gray-700 mb-3"
        >
          <ArrowLeft className="w-4 h-4" />
          Zurück zur Krisenhilfe
        </Link>

        <div className="flex items-center gap-3 mb-2">
          <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-emerald-500 to-cyan-600 flex items-center justify-center shadow-lg shadow-emerald-200">
            <Heart className="w-6 h-6 text-white" />
          </div>
          <div>
            <h1 className="text-xl font-black text-gray-900">Ressourcen & Hilfsangebote</h1>
            <p className="text-sm text-gray-500">Professionelle Anlaufstellen und Unterstützung</p>
          </div>
        </div>
      </div>

      {/* Emergency numbers */}
      <div className="mb-6">
        <QuickHelpNumbers compact={false} />
      </div>

      {/* Resource categories */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-6">
        {RESOURCE_CATEGORIES.map(cat => {
          const Icon = cat.icon
          return (
            <div key={cat.title} className={cn('rounded-2xl border p-4', cat.bgColor, cat.borderColor)}>
              <div className="flex items-center gap-2 mb-3">
                <Icon className={cn('w-5 h-5', cat.color)} />
                <h3 className={cn('text-sm font-bold', cat.color)}>{cat.title}</h3>
              </div>
              <div className="space-y-2">
                {cat.items.map(item => (
                  <div key={item.name} className="bg-white rounded-xl p-3 border border-white/50">
                    <p className="text-xs font-semibold text-gray-800">{item.name}</p>
                    <p className="text-xs text-gray-500 mt-0.5">{item.desc}</p>
                    <div className="flex gap-2 mt-2">
                      {item.phone && (
                        <a
                          href={`tel:${item.phone.replace(/[\s\-()]/g, '')}`}
                          className="inline-flex items-center gap-1 px-2 py-1 bg-red-50 border border-red-200 rounded-lg text-xs text-red-700 font-medium hover:bg-red-100"
                        >
                          <Phone className="w-3 h-3" />
                          {item.phone}
                        </a>
                      )}
                      {item.url && item.url !== '#' && (
                        <a
                          href={item.url}
                          target={item.url.startsWith('http') ? '_blank' : undefined}
                          rel={item.url.startsWith('http') ? 'noopener noreferrer' : undefined}
                          className="inline-flex items-center gap-1 px-2 py-1 bg-blue-50 border border-blue-200 rounded-lg text-xs text-blue-700 font-medium hover:bg-blue-100"
                        >
                          <BookOpen className="w-3 h-3" />
                          Mehr Info
                        </a>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )
        })}
      </div>

      {/* Mensaena community link */}
      <div className="bg-gradient-to-r from-emerald-50 to-teal-50 border border-emerald-200 rounded-2xl p-6 text-center">
        <Users className="w-8 h-8 text-emerald-600 mx-auto mb-3" />
        <h3 className="text-base font-bold text-emerald-800 mb-1">Mensaena Community</h3>
        <p className="text-sm text-emerald-600 mb-4">
          Unsere Gemeinschaft hilft sich gegenseitig - auch in Krisenzeiten.
        </p>
        <div className="flex flex-wrap justify-center gap-2">
          <Link
            href="/dashboard/crisis"
            className="px-4 py-2 bg-red-600 text-white rounded-xl text-sm font-semibold hover:bg-red-700 transition-colors"
          >
            Aktive Krisen
          </Link>
          <Link
            href="/dashboard/organizations"
            className="px-4 py-2 bg-white border border-emerald-200 text-emerald-700 rounded-xl text-sm font-semibold hover:bg-emerald-50 transition-colors"
          >
            Hilfsorganisationen
          </Link>
          <Link
            href="/dashboard/mental-support"
            className="px-4 py-2 bg-white border border-purple-200 text-purple-700 rounded-xl text-sm font-semibold hover:bg-purple-50 transition-colors"
          >
            Mentale Unterstützung
          </Link>
        </div>
      </div>
    </div>
  )
}
