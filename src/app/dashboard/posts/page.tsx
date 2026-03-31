'use client'

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import Link from 'next/link'
import { FilePlus } from 'lucide-react'
import { formatRelativeTime, getPostTypeColor, getPostTypeLabel, getUrgencyColor, getUrgencyLabel } from '@/lib/utils'

export default function PostsPage() {
  const [posts, setPosts] = useState<Record<string, unknown>[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const supabase = createClient()
    supabase
      .from('posts')
      .select('*, profiles(name, avatar_url)')
      .eq('status', 'active')
      .order('created_at', { ascending: false })
      .limit(50)
      .then(({ data }) => {
        setPosts(data || [])
        setLoading(false)
      })
  }, [])

  return (
    <div className="max-w-5xl">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Beiträge</h1>
          <p className="text-sm text-gray-600 mt-0.5">
            {loading ? 'Lädt...' : `${posts.length} aktive Beiträge in der Community`}
          </p>
        </div>
        <Link href="/dashboard/create" className="btn-primary">
          <FilePlus className="w-4 h-4" />
          Neuer Beitrag
        </Link>
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-48">
          <div className="w-8 h-8 border-4 border-primary-400 border-t-transparent rounded-full animate-spin" />
        </div>
      ) : posts.length > 0 ? (
        <div className="space-y-3">
          {posts.map((post) => (
            <div key={post.id as string} className="card p-5 hover:shadow-hover hover:-translate-y-0.5 transition-all duration-200">
              <div className="flex items-start gap-4">
                <div className="w-3 h-3 rounded-full mt-1.5 flex-shrink-0" style={{ backgroundColor: getPostTypeColor(post.type as string) }} />
                <div className="flex-1 min-w-0">
                  <div className="flex flex-wrap items-center gap-2 mb-1.5">
                    <span className="text-xs font-semibold text-gray-600">{getPostTypeLabel(post.type as string)}</span>
                    <span className={`badge ${getUrgencyColor(post.urgency as string)}`}>{getUrgencyLabel(post.urgency as string)}</span>
                    <span className="badge-gray capitalize">{post.category as string}</span>
                  </div>
                  <h3 className="font-semibold text-gray-900 mb-1">{post.title as string}</h3>
                  <p className="text-sm text-gray-600 line-clamp-2 leading-relaxed">{post.description as string}</p>
                  <div className="flex flex-wrap items-center gap-4 mt-3 text-xs text-gray-500">
                    <span>{formatRelativeTime(post.created_at as string)}</span>
                    {Boolean(post.latitude) && <span>📍 Standort</span>}
                    {Boolean(post.contact_phone) && <span>📞 Telefon</span>}
                    {Boolean(post.contact_whatsapp) && <span>💬 WhatsApp</span>}
                  </div>
                </div>
                <div className="flex flex-col gap-2 flex-shrink-0">
                  {Boolean(post.contact_phone) && (
                    <a href={`tel:${String(post.contact_phone)}`} className="px-3 py-1.5 bg-primary-100 text-primary-700 text-xs font-medium rounded-lg hover:bg-primary-200 transition-colors">
                      Anrufen
                    </a>
                  )}
                  {Boolean(post.contact_whatsapp) && (
                    <a href={`https://wa.me/${String(post.contact_whatsapp)}`} target="_blank" rel="noopener noreferrer"
                      className="px-3 py-1.5 bg-green-100 text-green-700 text-xs font-medium rounded-lg hover:bg-green-200 transition-colors">
                      WhatsApp
                    </a>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="card p-16 text-center">
          <div className="text-5xl mb-4">🌱</div>
          <h3 className="text-xl font-semibold text-gray-800 mb-2">Noch keine Beiträge</h3>
          <p className="text-sm text-gray-500 mb-6">Erstelle den ersten Beitrag in deiner Region!</p>
          <Link href="/dashboard/create" className="btn-primary justify-center">
            <FilePlus className="w-4 h-4" />
            Ersten Beitrag erstellen
          </Link>
        </div>
      )}
    </div>
  )
}
