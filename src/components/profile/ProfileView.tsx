'use client'

import { useState, useRef, useEffect, useCallback, type KeyboardEvent } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import {
  User, MapPin, Camera, Edit3, Check, X, Settings, MoreHorizontal,
  FileText, Heart, MessageCircle, Calendar, Award, Shield, Compass,
  Flag, Ban, Loader2, Plus, QrCode, Download, ChevronLeft,
} from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { openOrCreateDM } from '@/lib/chat-utils'
import { compressImage } from '@/lib/image-utils'
import toast from 'react-hot-toast'
import { cn, formatDate, truncateText } from '@/lib/utils'
import { getTypeConfig } from '@/lib/post-types'
import { handleSupabaseError } from '@/lib/errors'
import { useStore } from '@/store/useStore'

// ── Exported Types ──────────────────────────────────────────────────────────
export interface Profile {
  id: string
  name?: string
  nickname?: string | null
  email?: string
  location?: string | null
  skills?: string[] | null
  avatar_url?: string | null
  bio?: string | null
  trust_score?: number
  impact_score?: number
  karma_points?: number
  points?: number
  level?: number | string
  created_at?: string
  updated_at?: string
  verified_email?: boolean
  verified_phone?: boolean
  verified_community?: boolean
  privacy_public?: boolean
  privacy_phone?: boolean
  privacy_email?: boolean
}

export interface ProfilePost {
  id: string
  title: string
  type: string
  status?: string
  urgency?: number | string
  created_at: string
  reaction_count?: number
}

export interface ProfileStats {
  total_posts: number
  help_given: number
  messages_count: number
  member_days: number
  mentees_count?: number
  daily_activity?: { date: string; count: number }[]
}

interface Achievement {
  id: string
  icon: typeof FileText
  label: string
  desc: string
  progress: number
  earned: boolean
  current: number
  target: number
}

interface ProfileViewProps {
  profile: Profile
  user?: { id: string; email?: string } | null
  posts: ProfilePost[]
  stats: ProfileStats
  isOwnProfile: boolean
  targetUserId?: string
}

// ── Constants ────────────────────────────────────────────────────────────────
const LEVEL_MAP: Record<number | string, { emoji: string; name: string }> = {
  0: { emoji: '\uD83C\uDF31', name: 'Neuling' },
  1: { emoji: '\uD83C\uDF3F', name: 'Nachbar' },
  2: { emoji: '\u2B50', name: 'Helfer' },
  3: { emoji: '\uD83C\uDF1F', name: 'Engagiert' },
  4: { emoji: '\uD83D\uDCAB', name: 'Mentor' },
  5: { emoji: '\uD83C\uDFC6', name: 'Legende' },
}

const SKILL_SUGGESTIONS = [
  'Handwerk', 'Garten', 'Kochen', 'Kinderbetreuung', 'Elektrik', 'IT',
  'Nachhilfe', 'Transport', 'Pflege', 'Sprachen', 'Musik', 'Sport',
]

const MONTHS_DE = [
  'Januar', 'Februar', 'Maerz', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
]

// ── Helpers ──────────────────────────────────────────────────────────────────
function computeAchievements(stats: ProfileStats): Achievement[] {
  return [
    {
      id: 'first_post', icon: FileText, label: 'Erster Beitrag',
      desc: 'Erstelle deinen ersten Beitrag',
      current: stats.total_posts, target: 1,
      progress: Math.min(stats.total_posts / 1, 1),
      earned: stats.total_posts >= 1,
    },
    {
      id: 'active_helper', icon: Heart, label: 'Aktiver Helfer',
      desc: `Hilf 5 Nachbarn \u2013 ${Math.min(stats.help_given, 5)}/5 geschafft`,
      current: stats.help_given, target: 5,
      progress: Math.min(stats.help_given / 5, 1),
      earned: stats.help_given >= 5,
    },
    {
      id: 'super_helper', icon: Award, label: 'Super-Helfer',
      desc: `Hilf 25 Nachbarn \u2013 ${Math.min(stats.help_given, 25)}/25 geschafft`,
      current: stats.help_given, target: 25,
      progress: Math.min(stats.help_given / 25, 1),
      earned: stats.help_given >= 25,
    },
    {
      id: 'communicator', icon: MessageCircle, label: 'Kommunikator',
      desc: `50 Nachrichten \u2013 ${Math.min(stats.messages_count, 50)}/50 geschafft`,
      current: stats.messages_count, target: 50,
      progress: Math.min(stats.messages_count / 50, 1),
      earned: stats.messages_count >= 50,
    },
    {
      id: 'veteran', icon: Shield, label: 'Veteran',
      desc: `180 Tage dabei \u2013 ${Math.min(stats.member_days, 180)}/180`,
      current: stats.member_days, target: 180,
      progress: Math.min(stats.member_days / 180, 1),
      earned: stats.member_days >= 180,
    },
    {
      id: 'mentor', icon: Compass, label: 'Wegweiser',
      desc: `5 Mentees \u2013 ${Math.min(stats.mentees_count ?? 0, 5)}/5`,
      current: stats.mentees_count ?? 0, target: 5,
      progress: Math.min((stats.mentees_count ?? 0) / 5, 1),
      earned: (stats.mentees_count ?? 0) >= 5,
    },
  ]
}

// ── Score Circle SVG ─────────────────────────────────────────────────────────
function ScoreCircle({ score, color, label, size = 80 }: {
  score: number; color: string; label: string; size?: number
}) {
  const r = (size - 8) / 2
  const c = 2 * Math.PI * r
  const pct = Math.min(Math.max(score / 100, 0), 1)
  return (
    <div className="flex flex-col items-center gap-1">
      <svg width={size} height={size}>
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="#e5e7eb" strokeWidth={4} />
        <circle
          cx={size / 2} cy={size / 2} r={r} fill="none"
          stroke={color} strokeWidth={4}
          strokeDasharray={`${c * pct} ${c * (1 - pct)}`}
          strokeLinecap="round"
          transform={`rotate(-90 ${size / 2} ${size / 2})`}
        />
        <text x={size / 2} y={size / 2 + 5} textAnchor="middle" fontSize={16} fontWeight={700} fill="#374151">
          {score}
        </text>
      </svg>
      <span className="text-xs text-gray-500 font-medium">{label}</span>
    </div>
  )
}

// ── Inline Edit Component ────────────────────────────────────────────────────
function InlineEdit({ value, onSave, type = 'text', maxLength, placeholder, className }: {
  value: string
  onSave: (v: string) => Promise<void>
  type?: 'text' | 'textarea'
  maxLength?: number
  placeholder?: string
  className?: string
}) {
  const [editing, setEditing] = useState(false)
  const [editValue, setEditValue] = useState(value)
  const [saving, setSaving] = useState(false)
  const inputRef = useRef<HTMLInputElement | HTMLTextAreaElement>(null)

  useEffect(() => {
    if (editing && inputRef.current) inputRef.current.focus()
  }, [editing])

  const handleSave = async () => {
    setSaving(true)
    await onSave(editValue.trim())
    setSaving(false)
    setEditing(false)
    toast.success('Gespeichert')
  }

  const handleCancel = () => {
    setEditValue(value)
    setEditing(false)
  }

  const handleKeyDown = (e: KeyboardEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    if (e.key === 'Escape') handleCancel()
    if (e.key === 'Enter' && type === 'text') { e.preventDefault(); handleSave() }
  }

  if (!editing) {
    return (
      <span className={cn('group/edit inline-flex items-center gap-1.5 cursor-pointer', className)}>
        <span onClick={() => { setEditValue(value); setEditing(true) }}>
          {value || <span className="text-gray-400 italic">{placeholder}</span>}
        </span>
        <button
          onClick={() => { setEditValue(value); setEditing(true) }}
          className="opacity-0 group-hover/edit:opacity-100 transition-opacity p-0.5 rounded hover:bg-warm-100"
          title="Bearbeiten"
        >
          <Edit3 className="w-3.5 h-3.5 text-gray-400" />
        </button>
      </span>
    )
  }

  return (
    <span className="inline-flex items-center gap-1.5">
      {type === 'textarea' ? (
        <div className="w-full">
          <textarea
            ref={inputRef as React.RefObject<HTMLTextAreaElement>}
            value={editValue}
            onChange={e => setEditValue(maxLength ? e.target.value.slice(0, maxLength) : e.target.value)}
            onKeyDown={handleKeyDown}
            rows={3}
            className="input resize-none text-sm w-full"
            placeholder={placeholder}
          />
          {maxLength && (
            <p className="text-right text-[10px] text-gray-400 mt-0.5">{editValue.length}/{maxLength}</p>
          )}
        </div>
      ) : (
        <input
          ref={inputRef as React.RefObject<HTMLInputElement>}
          value={editValue}
          onChange={e => setEditValue(maxLength ? e.target.value.slice(0, maxLength) : e.target.value)}
          onKeyDown={handleKeyDown}
          className="input text-sm py-1 px-2"
          placeholder={placeholder}
        />
      )}
      <button onClick={handleSave} disabled={saving}
        className="p-1 rounded-lg bg-primary-100 text-primary-700 hover:bg-primary-200 transition-colors">
        {saving ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <Check className="w-3.5 h-3.5" />}
      </button>
      <button onClick={handleCancel} className="p-1 rounded-lg bg-gray-100 text-gray-500 hover:bg-gray-200 transition-colors">
        <X className="w-3.5 h-3.5" />
      </button>
    </span>
  )
}

// ── Main Component ───────────────────────────────────────────────────────────
export default function ProfileView({
  profile,
  user,
  posts,
  stats,
  isOwnProfile,
  targetUserId,
}: ProfileViewProps) {
  const router = useRouter()
  const store = useStore()

  const [activePostTab, setActivePostTab] = useState<'active' | 'completed'>('active')
  const [avatarUploading, setAvatarUploading] = useState(false)
  const [showQRCode, setShowQRCode] = useState(false)
  const [showMoreMenu, setShowMoreMenu] = useState(false)
  const [dmLoading, setDmLoading] = useState(false)
  const [bioExpanded, setBioExpanded] = useState(false)
  const [skillEditing, setSkillEditing] = useState(false)
  const [skillInput, setSkillInput] = useState('')
  const [currentSkills, setCurrentSkills] = useState<string[]>(profile.skills ?? [])
  const [showSuggestions, setShowSuggestions] = useState(false)
  const [currentAvatarUrl, setCurrentAvatarUrl] = useState(profile.avatar_url ?? null)
  const [currentName, setCurrentName] = useState(profile.name ?? '')
  const [currentBio, setCurrentBio] = useState(profile.bio ?? '')
  const [currentLocation, setCurrentLocation] = useState(profile.location ?? '')
  const fileInputRef = useRef<HTMLInputElement>(null)

  const achievements = computeAchievements(stats)
  const displayName = currentName || user?.email?.split('@')[0] || 'Nutzer'
  const initials = displayName.split(' ').map((n: string) => n[0]).join('').toUpperCase().slice(0, 2)
  const level = LEVEL_MAP[profile.level ?? 0] ?? LEVEL_MAP[0]
  const memberSince = profile.created_at
    ? `${MONTHS_DE[new Date(profile.created_at).getMonth()]} ${new Date(profile.created_at).getFullYear()}`
    : 'heute'

  const activePosts = posts.filter(p => p.status === 'active')
  const completedPosts = posts.filter(p => p.status !== 'active')
  const displayPosts = activePostTab === 'active' ? activePosts : completedPosts

  // Close menus on outside click
  useEffect(() => {
    if (!showMoreMenu) return
    const handler = () => setShowMoreMenu(false)
    window.addEventListener('click', handler)
    return () => window.removeEventListener('click', handler)
  }, [showMoreMenu])

  // ── Handlers ───────────────────────────────────────────────────────────────
  const updateProfile = useCallback(async (field: string, value: unknown) => {
    const supabase = createClient()
    const { error } = await supabase.from('profiles').update({ [field]: value }).eq('id', profile.id)
    if (handleSupabaseError(error)) return false
    return true
  }, [profile.id])

  const handleAvatarUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    if (file.size > 5 * 1024 * 1024) { toast.error('Bild zu gross (max. 5MB)'); return }

    setAvatarUploading(true)
    try {
      const compressed = await compressImage(file, 400, 0.85)
      const supabase = createClient()
      const filePath = `${profile.id}.webp`

      const { error: upErr } = await supabase.storage.from('avatars').upload(filePath, compressed, { upsert: true })
      if (upErr) { toast.error('Upload fehlgeschlagen'); setAvatarUploading(false); return }

      const { data: urlData } = supabase.storage.from('avatars').getPublicUrl(filePath)
      const publicUrl = urlData.publicUrl + '?t=' + Date.now()

      const { error: updateErr } = await supabase.from('profiles').update({ avatar_url: publicUrl }).eq('id', profile.id)
      if (!handleSupabaseError(updateErr)) {
        setCurrentAvatarUrl(publicUrl)
        store.set({ userAvatar: publicUrl })
        toast.success('Profilbild aktualisiert')
      }
    } catch {
      toast.error('Bildverarbeitung fehlgeschlagen')
    }
    setAvatarUploading(false)
  }

  const handleSaveName = async (v: string) => {
    if (await updateProfile('name', v)) {
      setCurrentName(v)
      store.set({ userName: v })
      toast.success('Name aktualisiert')
    }
  }

  const handleSaveBio = async (v: string) => {
    if (await updateProfile('bio', v)) {
      setCurrentBio(v)
      toast.success('Bio aktualisiert')
    }
  }

  const handleSaveLocation = async (v: string) => {
    if (await updateProfile('location', v)) {
      setCurrentLocation(v)
      toast.success('Standort aktualisiert')
    }
  }

  const handleSaveSkills = async (skills: string[]) => {
    if (await updateProfile('skills', skills)) {
      setCurrentSkills(skills)
      toast.success('Faehigkeiten aktualisiert')
    }
    setSkillEditing(false)
  }

  const handleAddSkill = (skill: string) => {
    const trimmed = skill.trim()
    if (!trimmed || currentSkills.includes(trimmed)) return
    setCurrentSkills(prev => [...prev, trimmed])
    setSkillInput('')
    setShowSuggestions(false)
  }

  const handleRemoveSkill = (skill: string) => {
    setCurrentSkills(prev => prev.filter(s => s !== skill))
  }

  const handleSkillKeyDown = (e: KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') { e.preventDefault(); handleAddSkill(skillInput) }
    if (e.key === 'Escape') { setSkillEditing(false); setCurrentSkills(profile.skills ?? []) }
  }

  const handleDM = async () => {
    if (!store.userId || !targetUserId) { toast.error('Bitte zuerst anmelden'); return }
    setDmLoading(true)
    try {
      const convId = await openOrCreateDM(store.userId, targetUserId)
      if (convId) router.push(`/dashboard/chat?conv=${convId}`)
      else toast.error('Konversation konnte nicht gestartet werden')
    } finally { setDmLoading(false) }
  }

  const handleBlock = async () => {
    if (!store.userId || !targetUserId) return
    const supabase = createClient()
    const { error } = await supabase.from('user_blocks').insert({
      blocker_id: store.userId, blocked_id: targetUserId,
    })
    if (!handleSupabaseError(error)) toast.success('Nutzer blockiert')
    setShowMoreMenu(false)
  }

  const handleReport = async () => {
    if (!store.userId || !targetUserId) return
    const supabase = createClient()
    const { error } = await supabase.from('reports').insert({
      reporter_id: store.userId, content_type: 'user', content_id: targetUserId,
      reason: 'Gemeldet vom Profil',
    })
    if (!handleSupabaseError(error)) toast.success('Nutzer gemeldet')
    setShowMoreMenu(false)
  }

  // ── Build Activity Heatmap Data ────────────────────────────────────────────
  const heatmapData = (() => {
    const days: { date: string; count: number; label: string }[] = []
    const now = new Date()
    const dailyMap: Record<string, number> = {}
    for (const d of (stats.daily_activity ?? [])) {
      dailyMap[d.date] = d.count
    }
    for (let i = 29; i >= 0; i--) {
      const dt = new Date(now.getTime() - i * 24 * 60 * 60 * 1000)
      const key = dt.toISOString().slice(0, 10)
      const day = dt.getDate()
      const month = MONTHS_DE[dt.getMonth()]
      days.push({
        date: key,
        count: dailyMap[key] ?? 0,
        label: `${day}. ${month}`,
      })
    }
    return days
  })()

  const profileUrl = typeof window !== 'undefined'
    ? `${window.location.origin}/dashboard/profile/${profile.id}`
    : ''

  // ── Render ─────────────────────────────────────────────────────────────────
  return (
    <div className="max-w-3xl mx-auto space-y-5 pb-12">

      {/* ── Back Button ──────────────────────────────────────────── */}
      {!isOwnProfile && (
        <button
          onClick={() => router.back()}
          className="flex items-center gap-1 text-sm text-gray-500 hover:text-gray-700 transition-colors mb-2"
        >
          <ChevronLeft className="w-4 h-4" /> Zurueck
        </button>
      )}

      {/* ── Profile Header ──────────────────────────────────────── */}
      <div className="bg-white rounded-2xl shadow-sm p-8 relative">
        {/* Top-right actions */}
        <div className="absolute top-4 right-4">
          {isOwnProfile ? (
            <Link href="/dashboard/settings" className="flex items-center gap-1.5 text-sm text-gray-500 hover:text-gray-700 transition-colors">
              <Settings className="w-4 h-4" /> Einstellungen
            </Link>
          ) : (
            <div className="relative">
              <button
                onClick={e => { e.stopPropagation(); setShowMoreMenu(!showMoreMenu) }}
                className="p-2 rounded-lg hover:bg-warm-100 transition-colors"
              >
                <MoreHorizontal className="w-5 h-5 text-gray-500" />
              </button>
              {showMoreMenu && (
                <div className="absolute right-0 top-10 bg-white rounded-xl shadow-xl border border-gray-200 py-1 min-w-[200px] z-30" onClick={e => e.stopPropagation()}>
                  <button onClick={handleDM} disabled={dmLoading}
                    className="w-full text-left px-4 py-2.5 text-sm hover:bg-warm-50 transition-colors flex items-center gap-2">
                    <MessageCircle className="w-4 h-4" /> Nachricht senden
                  </button>
                  <button onClick={handleBlock}
                    className="w-full text-left px-4 py-2.5 text-sm hover:bg-warm-50 transition-colors flex items-center gap-2">
                    <Ban className="w-4 h-4" /> Blockieren
                  </button>
                  <button onClick={handleReport}
                    className="w-full text-left px-4 py-2.5 text-sm text-red-600 hover:bg-red-50 transition-colors flex items-center gap-2">
                    <Flag className="w-4 h-4" /> Melden
                  </button>
                </div>
              )}
            </div>
          )}
        </div>

        {/* Avatar with online presence ring */}
        <div className="flex flex-col items-center">
          <div className="relative mb-4">
            {/* Green online ring */}
            <div className="h-[128px] w-[128px] rounded-full p-1 bg-gradient-to-br from-green-400 to-green-500">
              <div className={cn(
                'h-full w-full rounded-full flex items-center justify-center overflow-hidden bg-white',
                currentAvatarUrl ? '' : 'bg-primary-200',
              )}>
                {currentAvatarUrl ? (
                  <img src={currentAvatarUrl} alt={displayName} className="w-full h-full object-cover rounded-full" />
                ) : (
                  <span className="text-primary-700 text-3xl font-bold">{initials}</span>
                )}
              </div>
            </div>
            {isOwnProfile && (
              <>
                <button
                  onClick={() => fileInputRef.current?.click()}
                  disabled={avatarUploading}
                  className="absolute bottom-1 right-1 w-9 h-9 bg-primary-600 text-white rounded-full flex items-center justify-center shadow-lg hover:bg-primary-700 transition-all z-10"
                  title="Profilbild aendern"
                >
                  {avatarUploading
                    ? <Loader2 className="w-4 h-4 animate-spin" />
                    : <Camera className="w-4 h-4" />
                  }
                </button>
                <input
                  ref={fileInputRef}
                  type="file"
                  accept="image/*"
                  className="hidden"
                  onChange={handleAvatarUpload}
                />
              </>
            )}
            {/* Online dot */}
            <div className="absolute bottom-2 left-2 w-4 h-4 bg-green-500 rounded-full border-2 border-white" />
          </div>

          {/* Name */}
          <div className="text-center mb-2">
            {isOwnProfile ? (
              <h1 className="text-2xl font-bold text-gray-900">
                <InlineEdit
                  value={currentName}
                  onSave={handleSaveName}
                  placeholder="Dein Name"
                />
              </h1>
            ) : (
              <h1 className="text-2xl font-bold text-gray-900">{displayName}</h1>
            )}
          </div>

          {/* Verification badges */}
          <div className="flex items-center gap-1.5 mb-2">
            {profile.verified_email && (
              <span title="E-Mail verifiziert" className="inline-flex items-center gap-0.5 text-xs bg-blue-50 text-blue-700 px-2 py-0.5 rounded-full border border-blue-200">
                &#x2709;&#xFE0F; E-Mail
              </span>
            )}
            {profile.verified_phone && (
              <span title="Telefon verifiziert" className="inline-flex items-center gap-0.5 text-xs bg-green-50 text-green-700 px-2 py-0.5 rounded-full border border-green-200">
                &#x1F4F1; Telefon
              </span>
            )}
            {profile.verified_community && (
              <span title="Community verifiziert" className="inline-flex items-center gap-0.5 text-xs bg-purple-50 text-purple-700 px-2 py-0.5 rounded-full border border-purple-200">
                &#x1F91D; Community
              </span>
            )}
          </div>

          {/* Level badge */}
          <span className="inline-flex items-center gap-1 text-sm font-medium px-3 py-1 rounded-full bg-amber-50 text-amber-700 border border-amber-200 mb-3">
            <span>{level.emoji}</span> {level.name}
          </span>

          {/* Location */}
          <div className="flex items-center gap-1 text-sm text-gray-500 mb-3">
            <MapPin className="w-3.5 h-3.5 flex-shrink-0" />
            {isOwnProfile ? (
              <InlineEdit
                value={currentLocation}
                onSave={handleSaveLocation}
                placeholder="Dein Standort"
              />
            ) : (
              <span>{profile.location || 'Kein Standort'}</span>
            )}
          </div>

          {/* Bio */}
          <div className="text-center max-w-md mb-4">
            {isOwnProfile ? (
              <div className="text-gray-600 italic text-sm">
                <InlineEdit
                  value={currentBio}
                  onSave={handleSaveBio}
                  type="textarea"
                  maxLength={300}
                  placeholder="Erzaehle deinen Nachbarn etwas ueber dich..."
                />
              </div>
            ) : currentBio ? (
              <div className="text-gray-600 italic text-sm">
                {!bioExpanded && currentBio.length > 100
                  ? <>{truncateText(currentBio, 100)} <button onClick={() => setBioExpanded(true)} className="text-primary-600 not-italic font-medium">Mehr anzeigen</button></>
                  : currentBio
                }
              </div>
            ) : null}
          </div>

          {/* Trust-Score + Impact-Score circular SVG gauges */}
          <div className="flex items-center gap-6 mb-4">
            <ScoreCircle score={profile.trust_score ?? 0} color="#16a34a" label="Vertrauen" />
            <ScoreCircle score={profile.impact_score ?? 0} color="#f59e0b" label="Wirkung" />
            <div className="flex flex-col items-center gap-1">
              <span className="text-sm font-bold text-amber-600">
                &#x1F31F; {profile.karma_points ?? 0} Karma
              </span>
              <span className="text-xs text-gray-500">{profile.points ?? 0} Punkte</span>
            </div>
          </div>

          {/* Member since */}
          <div className="flex items-center gap-1 text-sm text-gray-400">
            <Calendar className="w-3.5 h-3.5" />
            Dabei seit {memberSince}
          </div>
        </div>
      </div>

      {/* ── Actions (non-owner) ────────────────────────────────────── */}
      {!isOwnProfile && targetUserId && (
        <div className="flex gap-3">
          <button
            onClick={handleDM}
            disabled={dmLoading}
            className="flex-1 flex items-center justify-center gap-2 py-3 rounded-xl text-sm font-medium bg-primary-600 text-white hover:bg-primary-700 transition-all disabled:opacity-50"
          >
            {dmLoading ? <Loader2 className="w-4 h-4 animate-spin" /> : <MessageCircle className="w-4 h-4" />}
            Nachricht senden
          </button>
          <button
            onClick={() => setShowQRCode(true)}
            className="flex items-center justify-center gap-2 px-4 py-3 rounded-xl text-sm font-medium border border-gray-200 text-gray-700 hover:bg-warm-50 transition-all"
          >
            <QrCode className="w-4 h-4" /> QR-Code
          </button>
        </div>
      )}

      {/* ── Skills ─────────────────────────────────────────────────── */}
      <div className="bg-white rounded-2xl shadow-sm p-6">
        <div className="flex items-center justify-between mb-3">
          <h3 className="font-bold text-gray-900">Faehigkeiten</h3>
          {isOwnProfile && !skillEditing && (
            <button onClick={() => setSkillEditing(true)} className="p-1.5 rounded-lg hover:bg-warm-100 transition-colors">
              <Edit3 className="w-4 h-4 text-gray-400" />
            </button>
          )}
        </div>

        {skillEditing && isOwnProfile ? (
          <div className="space-y-3">
            <div className="flex flex-wrap gap-2">
              {currentSkills.map(skill => (
                <span key={skill} className="inline-flex items-center gap-1 bg-primary-100 text-primary-700 rounded-full px-3 py-1 text-sm">
                  {skill}
                  <button onClick={() => handleRemoveSkill(skill)} className="ml-0.5 hover:text-red-600">
                    <X className="w-3 h-3" />
                  </button>
                </span>
              ))}
            </div>
            <div className="relative">
              <input
                value={skillInput}
                onChange={e => { setSkillInput(e.target.value); setShowSuggestions(true) }}
                onKeyDown={handleSkillKeyDown}
                onFocus={() => setShowSuggestions(true)}
                placeholder="Faehigkeit eingeben + Enter"
                className="input text-sm w-full"
              />
              {showSuggestions && skillInput.length === 0 && (
                <div className="absolute top-full left-0 right-0 mt-1 bg-white rounded-xl shadow-xl border border-gray-200 p-2 z-20 flex flex-wrap gap-1.5">
                  {SKILL_SUGGESTIONS.filter(s => !currentSkills.includes(s)).map(s => (
                    <button key={s} onClick={() => handleAddSkill(s)}
                      className="text-xs bg-warm-50 hover:bg-warm-100 text-gray-600 px-2.5 py-1 rounded-full border border-warm-200 transition-colors">
                      <Plus className="w-2.5 h-2.5 inline mr-0.5" />{s}
                    </button>
                  ))}
                </div>
              )}
              {showSuggestions && skillInput.length > 0 && (
                <div className="absolute top-full left-0 right-0 mt-1 bg-white rounded-xl shadow-xl border border-gray-200 p-2 z-20 flex flex-wrap gap-1.5">
                  {SKILL_SUGGESTIONS.filter(s => s.toLowerCase().includes(skillInput.toLowerCase()) && !currentSkills.includes(s)).map(s => (
                    <button key={s} onClick={() => handleAddSkill(s)}
                      className="text-xs bg-warm-50 hover:bg-warm-100 text-gray-600 px-2.5 py-1 rounded-full border border-warm-200 transition-colors">
                      {s}
                    </button>
                  ))}
                </div>
              )}
            </div>
            <div className="flex gap-2">
              <button onClick={() => handleSaveSkills(currentSkills)}
                className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium bg-primary-600 text-white hover:bg-primary-700 transition-all">
                <Check className="w-3.5 h-3.5" /> Speichern
              </button>
              <button onClick={() => { setSkillEditing(false); setCurrentSkills(profile.skills ?? []); setShowSuggestions(false) }}
                className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium bg-gray-100 text-gray-600 hover:bg-gray-200 transition-all">
                <X className="w-3.5 h-3.5" /> Abbrechen
              </button>
            </div>
          </div>
        ) : (
          <div className="flex flex-wrap gap-2">
            {currentSkills.length > 0 ? currentSkills.map(skill => (
              <span key={skill} className="bg-primary-100 text-primary-700 rounded-full px-3 py-1 text-sm font-medium">
                {skill}
              </span>
            )) : (
              <p className="text-sm text-gray-400 italic">
                {isOwnProfile ? 'Noch keine Faehigkeiten. Klicke auf den Stift um welche hinzuzufuegen.' : 'Keine Faehigkeiten angegeben.'}
              </p>
            )}
          </div>
        )}
      </div>

      {/* ── Statistics ──────────────────────────────────────────────── */}
      <div className="bg-white rounded-2xl shadow-sm p-6">
        <h3 className="font-bold text-gray-900 mb-4">Statistiken</h3>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          <div className="bg-blue-50 rounded-xl p-4 text-center">
            <FileText className="w-5 h-5 text-blue-600 mx-auto mb-1.5" />
            <div className="text-2xl font-bold text-gray-900">{stats.total_posts}</div>
            <div className="text-sm text-gray-500">Beitraege</div>
          </div>
          <div className="bg-green-50 rounded-xl p-4 text-center">
            <Heart className="w-5 h-5 text-green-600 mx-auto mb-1.5" />
            <div className="text-2xl font-bold text-gray-900">{stats.help_given}</div>
            <div className="text-sm text-gray-500">Geholfen</div>
          </div>
          <div className="bg-purple-50 rounded-xl p-4 text-center">
            <MessageCircle className="w-5 h-5 text-purple-600 mx-auto mb-1.5" />
            <div className="text-2xl font-bold text-gray-900">{stats.messages_count}</div>
            <div className="text-sm text-gray-500">Nachrichten</div>
          </div>
          <div className="bg-amber-50 rounded-xl p-4 text-center">
            <Calendar className="w-5 h-5 text-amber-600 mx-auto mb-1.5" />
            <div className="text-2xl font-bold text-gray-900">{stats.member_days}</div>
            <div className="text-sm text-gray-500">Tage dabei</div>
          </div>
        </div>
      </div>

      {/* ── Achievements ────────────────────────────────────────────── */}
      <div className="bg-white rounded-2xl shadow-sm p-6">
        <h3 className="font-bold text-gray-900 mb-4">Erfolge</h3>
        <div className="space-y-3">
          {achievements.map(ach => {
            const Icon = ach.icon
            return (
              <div key={ach.id} className={cn(
                'border rounded-xl p-4 transition-all',
                ach.earned ? 'border-amber-200 bg-amber-50/50' : 'border-gray-200 opacity-60',
              )}>
                <div className="flex items-start gap-3">
                  <div className={cn(
                    'w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0',
                    ach.earned ? 'bg-amber-100 text-amber-600' : 'bg-gray-100 text-gray-400',
                  )}>
                    <Icon className="w-5 h-5" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="font-semibold text-sm text-gray-900">{ach.label}</p>
                    <p className="text-xs text-gray-500 mb-2">{ach.desc}</p>
                    <div className="w-full h-2 bg-gray-200 rounded-full overflow-hidden">
                      <div
                        className={cn('h-full rounded-full transition-all duration-500', ach.earned ? 'bg-amber-500' : 'bg-primary-500')}
                        style={{ width: `${Math.round(ach.progress * 100)}%` }}
                      />
                    </div>
                    <p className="text-[10px] text-gray-400 mt-1">{ach.current}/{ach.target}</p>
                  </div>
                  {ach.earned && (
                    <span className="text-xs bg-amber-100 text-amber-700 px-2 py-0.5 rounded-full font-medium flex-shrink-0">
                      &#x2705;
                    </span>
                  )}
                </div>
              </div>
            )
          })}
        </div>
      </div>

      {/* ── Activity Heatmap ────────────────────────────────────────── */}
      <div className="bg-white rounded-2xl shadow-sm p-6">
        <h3 className="font-bold text-gray-900 mb-4">Aktivitaet (letzte 30 Tage)</h3>
        <div className="grid grid-cols-10 gap-1">
          {heatmapData.map((d) => {
            const intensity = d.count === 0 ? 0 : d.count <= 2 ? 1 : d.count <= 5 ? 2 : 3
            const colors = ['bg-gray-100', 'bg-primary-200', 'bg-primary-400', 'bg-primary-600']
            return (
              <div
                key={d.date}
                title={`${d.label} \u2013 ${d.count} Aktivitaet${d.count !== 1 ? 'en' : ''}`}
                className={cn('aspect-square rounded-sm cursor-default transition-colors hover:ring-2 hover:ring-primary-300', colors[intensity])}
              />
            )
          })}
        </div>
        {/* Legend */}
        <div className="flex items-center gap-1.5 mt-3 text-xs text-gray-500">
          <span>Weniger</span>
          <div className="w-3 h-3 rounded-sm bg-gray-100" />
          <div className="w-3 h-3 rounded-sm bg-primary-200" />
          <div className="w-3 h-3 rounded-sm bg-primary-400" />
          <div className="w-3 h-3 rounded-sm bg-primary-600" />
          <span>Mehr</span>
        </div>
      </div>

      {/* ── Posts ────────────────────────────────────────────────────── */}
      <div className="bg-white rounded-2xl shadow-sm p-6">
        <h3 className="font-bold text-gray-900 mb-4">Beitraege</h3>

        {/* Tabs */}
        <div className="flex gap-1 mb-4 bg-warm-50 rounded-lg p-1">
          <button
            onClick={() => setActivePostTab('active')}
            className={cn(
              'flex-1 py-2 rounded-lg text-sm font-medium transition-all',
              activePostTab === 'active' ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-500 hover:text-gray-700',
            )}
          >
            Aktive ({activePosts.length})
          </button>
          <button
            onClick={() => setActivePostTab('completed')}
            className={cn(
              'flex-1 py-2 rounded-lg text-sm font-medium transition-all',
              activePostTab === 'completed' ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-500 hover:text-gray-700',
            )}
          >
            Abgeschlossene ({completedPosts.length})
          </button>
        </div>

        {/* Post list */}
        {displayPosts.length > 0 ? (
          <div className="space-y-2">
            {displayPosts.map(post => {
              const cfg = getTypeConfig(post.type)
              const statusLabel = post.status === 'active' ? 'Aktiv'
                : post.status === 'resolved' || post.status === 'fulfilled' ? 'Erledigt'
                : 'Abgelaufen'
              const statusClass = post.status === 'active' ? 'bg-green-100 text-green-700'
                : post.status === 'resolved' || post.status === 'fulfilled' ? 'bg-blue-100 text-blue-700'
                : 'bg-gray-100 text-gray-500'
              return (
                <Link
                  key={post.id}
                  href={`/dashboard/posts/${post.id}`}
                  className="flex items-center gap-3 p-3 rounded-xl hover:bg-warm-50 transition-colors"
                >
                  <span className="text-sm flex-shrink-0">{cfg.emoji}</span>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-gray-900 truncate">{post.title}</p>
                    <p className="text-xs text-gray-400">{formatDate(post.created_at)}</p>
                  </div>
                  <span className={cn('text-xs px-2 py-0.5 rounded-full font-medium flex-shrink-0', statusClass)}>
                    {statusLabel}
                  </span>
                  {(post.reaction_count ?? 0) > 0 && (
                    <span className="text-xs text-gray-400 flex-shrink-0">
                      &#x2764;&#xFE0F; {post.reaction_count}
                    </span>
                  )}
                </Link>
              )
            })}
          </div>
        ) : (
          <div className="text-center py-8 bg-warm-50 rounded-xl border border-warm-200">
            <FileText className="w-10 h-10 text-gray-300 mx-auto mb-2" />
            {isOwnProfile ? (
              <>
                <p className="text-sm text-gray-500">Du hast noch keinen Beitrag erstellt</p>
                <Link href="/dashboard/create"
                  className="inline-flex items-center gap-1.5 mt-3 text-sm font-medium text-primary-600 hover:text-primary-700 transition-colors">
                  <Plus className="w-4 h-4" /> Ersten Beitrag erstellen
                </Link>
              </>
            ) : (
              <p className="text-sm text-gray-500">
                {displayName} hat gerade keine {activePostTab === 'active' ? 'aktiven' : 'abgeschlossenen'} Beitraege
              </p>
            )}
          </div>
        )}
      </div>

      {/* ── QR Code Modal ──────────────────────────────────────────── */}
      {showQRCode && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm" onClick={() => setShowQRCode(false)}>
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm p-6 text-center" onClick={e => e.stopPropagation()}>
            <h3 className="font-bold text-gray-900 text-lg mb-4">Profil QR-Code</h3>
            <div className="flex justify-center mb-4">
              <img
                src={`https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${encodeURIComponent(profileUrl)}&format=png`}
                alt="QR Code"
                className="w-48 h-48 rounded-lg"
                id="qr-code-img"
              />
            </div>
            <p className="text-sm text-gray-500 mb-4">Scanne diesen Code um das Profil zu oeffnen</p>
            <div className="flex gap-3">
              <button
                onClick={() => {
                  const img = document.getElementById('qr-code-img') as HTMLImageElement
                  if (!img) return
                  const link = document.createElement('a')
                  link.href = img.src
                  link.download = `mensaena-profil-${profile.id}.png`
                  link.click()
                }}
                className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-xl text-sm font-medium border border-gray-200 hover:bg-warm-50 transition-colors"
              >
                <Download className="w-4 h-4" /> Als Bild speichern
              </button>
              <button
                onClick={() => setShowQRCode(false)}
                className="flex-1 py-2.5 rounded-xl text-sm font-medium bg-primary-600 text-white hover:bg-primary-700 transition-colors"
              >
                Schliessen
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── QR Code for own profile ──────────────────────────────────── */}
      {isOwnProfile && (
        <div className="flex justify-center">
          <button
            onClick={() => setShowQRCode(true)}
            className="flex items-center gap-2 text-sm text-gray-500 hover:text-gray-700 transition-colors"
          >
            <QrCode className="w-4 h-4" /> Mein QR-Code anzeigen
          </button>
        </div>
      )}
    </div>
  )
}
