'use client'

import { useState, useRef, useEffect } from 'react'
import { User, MapPin, Star, Heart, Wrench, Edit3, Check, X, Camera, TrendingUp, MessageCircle, ThumbsUp, Activity, Award, BarChart2 } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { formatDate, getPostTypeLabel, getPostTypeColor } from '@/lib/utils'
import type { UserProfile, Post } from '@/types'
import type { User as SupabaseUser } from '@supabase/supabase-js'
import toast from 'react-hot-toast'

interface ProfileStats {
  totalPosts: number
  activePosts: number
  totalInteractions: number
  helpGiven: number
  helpReceived: number
  totalMessages: number
  postsByType: { type: string; count: number }[]
  activityLast30Days: { date: string; count: number }[]
  memberDays: number
}

export default function ProfileView({
  profile,
  user,
  myPosts,
}: {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  profile: UserProfile | Record<string, any> | null
  user: SupabaseUser
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  myPosts: Post[] | Record<string, any>[]
}) {
  const [editing, setEditing] = useState(false)
  const [stats, setStats] = useState<ProfileStats | null>(null)
  const [name, setName] = useState(profile?.name || user.user_metadata?.full_name || '')
  const [bio, setBio] = useState(profile?.bio || '')
  const [location, setLocation] = useState(profile?.location || '')
  const [skills, setSkills] = useState(profile?.skills?.join(', ') || '')
  const [saving, setSaving] = useState(false)
  const [avatarUrl, setAvatarUrl] = useState<string | null>(profile?.avatar_url || null)
  const [uploadingAvatar, setUploadingAvatar] = useState(false)
  const fileInputRef = useRef<HTMLInputElement>(null)

  // Load statistics
  useEffect(() => {
    async function loadStats() {
      const supabase = createClient()
      const uid = user.id
      const now = new Date()
      const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000).toISOString()

      const [postsRes, interactionsHelperRes, interactionsOwnerRes, messagesRes, recentPostsRes] = await Promise.all([
        supabase.from('posts').select('type, status, created_at').eq('user_id', uid),
        supabase.from('interactions').select('id').eq('helper_id', uid),
        supabase.from('interactions').select('id').in('post_id',
          (await supabase.from('posts').select('id').eq('user_id', uid)).data?.map((p: {id: string}) => p.id) ?? []
        ),
        supabase.from('messages').select('id', { count: 'exact' }).eq('sender_id', uid).is('deleted_at', null),
        supabase.from('posts').select('created_at').eq('user_id', uid).gte('created_at', thirtyDaysAgo),
      ])

      const posts = postsRes.data ?? []
      const byType: Record<string, number> = {}
      posts.forEach((p: { type: string }) => { byType[p.type] = (byType[p.type] || 0) + 1 })

      // Build last 30 days activity (count posts per day)
      const dayMap: Record<string, number> = {}
      for (let i = 29; i >= 0; i--) {
        const d = new Date(now.getTime() - i * 24 * 60 * 60 * 1000)
        dayMap[d.toISOString().slice(0, 10)] = 0
      }
      ;(recentPostsRes.data ?? []).forEach((p: { created_at: string }) => {
        const day = new Date(p.created_at).toISOString().slice(0, 10)
        if (dayMap[day] !== undefined) dayMap[day]++
      })

      const memberDays = profile?.created_at
        ? Math.floor((Date.now() - new Date(profile.created_at).getTime()) / (24 * 60 * 60 * 1000))
        : 0

      setStats({
        totalPosts: posts.length,
        activePosts: posts.filter((p: { status: string }) => p.status === 'active').length,
        totalInteractions: (interactionsHelperRes.data?.length ?? 0) + (interactionsOwnerRes.data?.length ?? 0),
        helpGiven: interactionsHelperRes.data?.length ?? 0,
        helpReceived: interactionsOwnerRes.data?.length ?? 0,
        totalMessages: messagesRes.count ?? 0,
        postsByType: Object.entries(byType).map(([type, count]) => ({ type, count })).sort((a, b) => b.count - a.count),
        activityLast30Days: Object.entries(dayMap).map(([date, count]) => ({ date, count })),
        memberDays,
      })
    }
    loadStats()
  }, [user.id, profile?.created_at])

  const handleAvatarUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

    if (file.size > 5 * 1024 * 1024) {
      toast.error('Bild zu groß (max. 5MB)')
      return
    }

    setUploadingAvatar(true)
    const supabase = createClient()
    const ext = file.name.split('.').pop()
    const filePath = `${user.id}/avatar.${ext}`

    const { error: uploadError } = await supabase.storage
      .from('avatars')
      .upload(filePath, file, { upsert: true })

    if (uploadError) {
      toast.error('Upload fehlgeschlagen: ' + uploadError.message)
      setUploadingAvatar(false)
      return
    }

    const { data: urlData } = supabase.storage.from('avatars').getPublicUrl(filePath)
    const publicUrl = urlData.publicUrl + '?t=' + Date.now()

    const { error: updateError } = await supabase
      .from('profiles')
      .upsert({ id: user.id, avatar_url: publicUrl, email: user.email })

    if (!updateError) {
      setAvatarUrl(publicUrl)
      toast.success('Profilbild gespeichert! 🎉')
    } else {
      toast.error('Profil-Update fehlgeschlagen')
    }
    setUploadingAvatar(false)
  }

  const displayName = name || user.email?.split('@')[0] || 'Nutzer'
  const initials = displayName.split(' ').map((n: string) => n[0]).join('').toUpperCase().slice(0, 2)

  const handleSave = async () => {
    setSaving(true)
    const supabase = createClient()

    const { error } = await supabase
      .from('profiles')
      .upsert({
        id: user.id,
        name,
        bio,
        location,
        skills: skills.split(",").map((s: string) => s.trim()).filter(Boolean),
        email: user.email,
        updated_at: new Date().toISOString(),
      })

    if (!error) {
      toast.success('Profil gespeichert!')
      setEditing(false)
    } else {
      toast.error('Fehler beim Speichern')
    }
    setSaving(false)
  }

  return (
    <div className="max-w-4xl">
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-900">Mein Profil</h1>
        {!editing ? (
          <button onClick={() => setEditing(true)} className="btn-secondary gap-2">
            <Edit3 className="w-4 h-4" /> Bearbeiten
          </button>
        ) : (
          <div className="flex gap-2">
            <button onClick={handleSave} disabled={saving} className="btn-primary gap-2">
              <Check className="w-4 h-4" />
              {saving ? 'Speichern…' : 'Speichern'}
            </button>
            <button onClick={() => setEditing(false)} className="btn-secondary gap-2">
              <X className="w-4 h-4" /> Abbrechen
            </button>
          </div>
        )}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Profile Card */}
        <div className="lg:col-span-1">
          <div className="card p-6 text-center">
            {/* Avatar */}
            <div className="relative w-20 h-20 mx-auto mb-4">
              <div className="w-20 h-20 rounded-full bg-gradient-to-br from-primary-400 to-primary-600 flex items-center justify-center text-white text-2xl font-bold shadow-md overflow-hidden">
                {avatarUrl ? (
                  <img src={avatarUrl} alt={displayName} className="w-full h-full rounded-full object-cover" />
                ) : (
                  initials
                )}
              </div>
              {/* Upload Button */}
              <button
                onClick={() => fileInputRef.current?.click()}
                disabled={uploadingAvatar}
                className="absolute -bottom-1 -right-1 w-7 h-7 bg-primary-600 text-white rounded-full flex items-center justify-center shadow-md hover:bg-primary-700 transition-colors"
                title="Profilbild ändern"
              >
                {uploadingAvatar ? (
                  <div className="w-3 h-3 border border-white border-t-transparent rounded-full animate-spin" />
                ) : (
                  <Camera className="w-3.5 h-3.5" />
                )}
              </button>
              <input
                ref={fileInputRef}
                type="file"
                accept="image/jpeg,image/png,image/webp,image/gif"
                className="hidden"
                onChange={handleAvatarUpload}
              />
            </div>
            <h2 className="text-xl font-bold text-gray-900 mb-1">{displayName}</h2>
            {profile?.nickname && (
              <p className="text-sm text-gray-500 mb-2">@{profile.nickname}</p>
            )}
            {location && (
              <div className="flex items-center justify-center gap-1 text-sm text-gray-500 mb-4">
                <MapPin className="w-3.5 h-3.5" />
                {location}
              </div>
            )}

            {/* Score Cards */}
            <div className="grid grid-cols-2 gap-3 mt-4">
              <div className="p-3 bg-primary-50 rounded-xl">
                <div className="text-xl font-bold text-primary-700">{profile?.trust_score ?? 0}</div>
                <div className="text-xs text-gray-600 mt-0.5 flex items-center justify-center gap-1">
                  <Star className="w-3 h-3" /> Vertrauen
                </div>
              </div>
              <div className="p-3 bg-warm-100 rounded-xl">
                <div className="text-xl font-bold text-amber-700">{profile?.impact_score ?? 0}</div>
                <div className="text-xs text-gray-600 mt-0.5 flex items-center justify-center gap-1">
                  <Heart className="w-3 h-3" /> Impact
                </div>
              </div>
            </div>

            <p className="text-xs text-gray-400 mt-4">
              Mitglied seit {profile?.created_at ? formatDate(profile.created_at) : 'heute'}
            </p>
          </div>
        </div>

        {/* Profile Details */}
        <div className="lg:col-span-2 space-y-4">
          {/* Edit Form */}
          {editing ? (
            <div className="card p-6 space-y-4">
              <h3 className="font-semibold text-gray-900">Profil bearbeiten</h3>
              <div>
                <label className="label">Name</label>
                <input value={name} onChange={(e) => setName(e.target.value)} className="input" placeholder="Dein Name" />
              </div>
              <div>
                <label className="label">Über mich</label>
                <textarea value={bio} onChange={(e) => setBio(e.target.value)} className="input resize-none" rows={3} placeholder="Schreib etwas über dich…" />
              </div>
              <div>
                <label className="label">Standort</label>
                <input value={location} onChange={(e) => setLocation(e.target.value)} className="input" placeholder="Deine Stadt oder Region" />
              </div>
              <div>
                <label className="label">Fähigkeiten (kommagetrennt)</label>
                <input value={skills} onChange={(e) => setSkills(e.target.value)} className="input" placeholder="z.B. Handwerk, Kochen, Fahren…" />
              </div>
            </div>
          ) : (
            <>
              {/* Bio */}
              <div className="card p-5">
                <div className="flex items-center gap-2 mb-3">
                  <User className="w-4 h-4 text-primary-600" />
                  <h3 className="font-semibold text-gray-900 text-sm">Über mich</h3>
                </div>
                <p className="text-sm text-gray-600 leading-relaxed">
                  {profile?.bio || 'Noch keine Beschreibung. Bearbeite dein Profil, um anderen mehr über dich zu erzählen.'}
                </p>
              </div>

              {/* Skills */}
              <div className="card p-5">
                <div className="flex items-center gap-2 mb-3">
                  <Wrench className="w-4 h-4 text-primary-600" />
                  <h3 className="font-semibold text-gray-900 text-sm">Fähigkeiten</h3>
                </div>
                {profile?.skills && profile.skills.length > 0 ? (
                  <div className="flex flex-wrap gap-2">
                    {profile.skills.map((skill: string, i: number) => (
                      <span key={i} className="badge-green">{skill}</span>
                    ))}
                  </div>
                ) : (
                  <p className="text-sm text-gray-500">Noch keine Fähigkeiten eingetragen.</p>
                )}
              </div>
            </>
          )}

          {/* My Posts */}
          <div className="card p-5">
            <h3 className="font-semibold text-gray-900 text-sm mb-4">Meine Beiträge ({myPosts.length})</h3>
            {myPosts.length > 0 ? (
              <div className="space-y-2">
                {myPosts.map((post) => (
                  <div key={post.id} className="flex items-center gap-3 p-3 bg-warm-50 rounded-xl">
                    <div className="w-2.5 h-2.5 rounded-full flex-shrink-0" style={{ backgroundColor: getPostTypeColor(post.type) }} />
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium text-gray-900 truncate">{post.title}</p>
                      <p className="text-xs text-gray-500">{getPostTypeLabel(post.type)} · {formatDate(post.created_at)}</p>
                    </div>
                    <span className={`badge ${post.status === 'active' ? 'badge-green' : 'badge-gray'}`}>
                      {post.status === 'active' ? 'Aktiv' : 'Archiviert'}
                    </span>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-sm text-gray-500">Noch keine Beiträge erstellt.</p>
            )}
          </div>

          {/* Statistics */}
          {stats && (
            <div className="card p-5">
              <div className="flex items-center gap-2 mb-4">
                <BarChart2 className="w-4 h-4 text-primary-600" />
                <h3 className="font-semibold text-gray-900 text-sm">Aktivitäts-Statistiken</h3>
              </div>

              {/* Key metrics */}
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-5">
                <div className="bg-primary-50 rounded-xl p-3 text-center">
                  <div className="text-2xl font-bold text-primary-700">{stats.totalPosts}</div>
                  <div className="text-xs text-gray-500 mt-0.5">Beiträge</div>
                </div>
                <div className="bg-green-50 rounded-xl p-3 text-center">
                  <div className="text-2xl font-bold text-green-700">{stats.helpGiven}</div>
                  <div className="text-xs text-gray-500 mt-0.5">Geholfen</div>
                </div>
                <div className="bg-violet-50 rounded-xl p-3 text-center">
                  <div className="text-2xl font-bold text-violet-700">{stats.totalMessages}</div>
                  <div className="text-xs text-gray-500 mt-0.5">Nachrichten</div>
                </div>
                <div className="bg-amber-50 rounded-xl p-3 text-center">
                  <div className="text-2xl font-bold text-amber-700">{stats.memberDays}</div>
                  <div className="text-xs text-gray-500 mt-0.5">Tage dabei</div>
                </div>
              </div>

              {/* Activity chart (last 30 days) */}
              <div>
                <p className="text-xs font-semibold text-gray-500 mb-2 flex items-center gap-1">
                  <Activity className="w-3.5 h-3.5" /> Aktivität – letzte 30 Tage
                </p>
                <div className="flex items-end gap-px h-12">
                  {stats.activityLast30Days.map(({ date, count }) => {
                    const maxCount = Math.max(...stats.activityLast30Days.map((d) => d.count), 1)
                    const height = count === 0 ? 10 : Math.max(15, Math.round((count / maxCount) * 100))
                    return (
                      <div
                        key={date}
                        title={`${date}: ${count} Beitrag${count !== 1 ? 'e' : ''}`}
                        style={{ height: `${height}%` }}
                        className={`flex-1 rounded-sm transition-all ${count > 0 ? 'bg-primary-400 hover:bg-primary-600' : 'bg-gray-100'}`}
                      />
                    )
                  })}
                </div>
                <div className="flex justify-between text-xs text-gray-400 mt-1">
                  <span>vor 30 Tagen</span>
                  <span>heute</span>
                </div>
              </div>

              {/* Posts by type */}
              {stats.postsByType.length > 0 && (
                <div className="mt-4">
                  <p className="text-xs font-semibold text-gray-500 mb-2 flex items-center gap-1">
                    <TrendingUp className="w-3.5 h-3.5" /> Beiträge nach Typ
                  </p>
                  <div className="space-y-1.5">
                    {stats.postsByType.slice(0, 5).map(({ type, count }) => (
                      <div key={type} className="flex items-center gap-2">
                        <div
                          className="h-2 rounded-full bg-primary-400"
                          style={{ width: `${Math.max(8, (count / stats.totalPosts) * 100)}%` }}
                        />
                        <span className="text-xs text-gray-600">{getPostTypeLabel(type)}</span>
                        <span className="text-xs font-semibold text-gray-800 ml-auto">{count}</span>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
