'use client'

import { useState } from 'react'
import { User, MapPin, Star, Heart, Wrench, Edit3, Check, X } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { formatDate, getPostTypeLabel, getPostTypeColor } from '@/lib/utils'
import type { UserProfile, Post } from '@/types'
import type { User as SupabaseUser } from '@supabase/supabase-js'
import toast from 'react-hot-toast'

export default function ProfileView({
  profile,
  user,
  myPosts,
}: {
  profile: UserProfile | null
  user: SupabaseUser
  myPosts: Post[]
}) {
  const [editing, setEditing] = useState(false)
  const [name, setName] = useState(profile?.name || user.user_metadata?.full_name || '')
  const [bio, setBio] = useState(profile?.bio || '')
  const [location, setLocation] = useState(profile?.location || '')
  const [skills, setSkills] = useState(profile?.skills?.join(', ') || '')
  const [saving, setSaving] = useState(false)

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
        skills: skills.split(',').map((s) => s.trim()).filter(Boolean),
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
            <div className="w-20 h-20 rounded-full bg-gradient-to-br from-primary-400 to-primary-600 flex items-center justify-center text-white text-2xl font-bold mx-auto mb-4 shadow-md">
              {profile?.avatar_url ? (
                <img src={profile.avatar_url} alt={displayName} className="w-full h-full rounded-full object-cover" />
              ) : (
                initials
              )}
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
                    {profile.skills.map((skill, i) => (
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
        </div>
      </div>
    </div>
  )
}
