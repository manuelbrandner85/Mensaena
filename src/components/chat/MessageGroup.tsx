'use client'
// FEATURE: Code-Splitting — extrahiert aus ChatView.tsx
import { memo } from 'react'
import Image from 'next/image'
import {
  Phone, PhoneOff, Check, CheckCheck,
  Smile, Reply, Send, Trash2, Edit2, Link2, Pin, PinOff, Crown,
} from 'lucide-react'
import toast from 'react-hot-toast'
import { cn, formatRelativeTime } from '@/lib/utils'
import { formatChatMessage, getMessagePermalink } from '@/lib/chat-features'
import { getTierInfo } from '@/lib/donorTier'

// ─── Minimal types (structurally compatible with ChatView types) ───────────────
interface Profile {
  id: string
  name: string | null
  email: string | null
  avatar_url: string | null
  nickname: string | null
  role?: string | null
  donor_tier?: number | null
}

interface ConvMember {
  user_id: string
  last_read_at?: string | null
  profiles: Profile | null
}

interface Reaction {
  emoji: string
  user_id: string
  message_id: string
}

export interface MsgItem {
  id: string
  conversation_id: string
  sender_id: string
  content: string
  created_at: string
  deleted_at?: string | null
  edited_at?: string | null
  is_pinned?: boolean
  reply_to_id?: string | null
  profiles?: Profile | null
  reactions?: Reaction[]
  reply_to?: { content: string; profiles?: { name?: string | null } | null } | null
}

export type { ConvMember }

// ─── Helpers ──────────────────────────────────────────────────────────────────
const QUICK_EMOJIS = ['👍', '❤️', '😂', '😮', '😢', '🙏', '🔥', '✅']

function isAdminUser(profile: Profile | null | undefined): boolean {
  if (!profile) return false
  return profile.role === 'admin' || profile.role === 'moderator'
}

export function parseSystemCallMessage(content: string): {
  type: 'ended' | 'missed' | 'declined' | 'cancelled'
  duration?: string
} | null {
  if (!content.startsWith('[SYSTEM_CALL]')) return null
  if (content.includes('Verpasst') || content.includes('verpasst')) return { type: 'missed' }
  if (content.includes('abgelehnt')) return { type: 'declined' }
  if (content.includes('abgebrochen')) return { type: 'cancelled' }
  const dur = content.match(/Dauer:\s*(\d+:\d+)/)
  return { type: 'ended', duration: dur?.[1] }
}

// ─── MessageGroup ─────────────────────────────────────────────────────────────
function MessageGroup({ messages, userId, isAdmin, pinnedIds, onReply, onForward, onReaction, onDelete, onPin, onEdit,
  showEmojiFor, setShowEmojiFor, msgMenuFor, setMsgMenuFor,
  editingMsgId, editContent, setEditContent, onEditSubmit, onEditCancel, allMembers,
  onCallBack, isBanned, dmCallLoading, activeDMCall,
}: {
  messages: MsgItem[]; userId: string; isAdmin: boolean; pinnedIds: Set<string>
  onReply: (m: MsgItem) => void
  onForward?: (m: MsgItem) => void
  onReaction: (msgId: string, emoji: string) => void
  onDelete: (msgId: string, senderId: string) => void
  onPin: (m: MsgItem) => void
  onEdit: (m: MsgItem) => void
  allMembers: ConvMember[]
  showEmojiFor: string | null; setShowEmojiFor: (id: string | null) => void
  msgMenuFor: string | null; setMsgMenuFor: (id: string | null) => void
  editingMsgId: string | null; editContent: string; setEditContent: (v: string) => void
  onEditSubmit: (id: string) => void; onEditCancel: () => void
  onCallBack?: () => void; isBanned?: boolean; dmCallLoading?: boolean; activeDMCall?: unknown
}) {
  return (
    <>
      {messages.map((msg, i) => {
        const isMe = msg.sender_id === userId
        const isDeleted = !!msg.deleted_at
        const prevMsg = messages[i - 1]
        const nextMsg = messages[i + 1]
        const sameAuthorPrev = prevMsg?.sender_id === msg.sender_id
        const sameAuthorNext = nextMsg?.sender_id === msg.sender_id
        const timeDiff = prevMsg ? new Date(msg.created_at).getTime() - new Date(prevMsg.created_at).getTime() : Infinity
        const showHeader = !sameAuthorPrev || timeDiff > 5 * 60 * 1000
        const isLast = !sameAuthorNext
        const msgIsAdmin = isAdminUser(msg.profiles as Profile)
        const isPinned = pinnedIds.has(msg.id)
        const isEditing = editingMsgId === msg.id

        const reactionGroups: Record<string, number> = {}
        const reactionUsers: Record<string, string[]> = {}
        const myReactions: Record<string, boolean> = {}
        for (const r of msg.reactions ?? []) {
          reactionGroups[r.emoji] = (reactionGroups[r.emoji] ?? 0) + 1
          if (!reactionUsers[r.emoji]) reactionUsers[r.emoji] = []
          // User-ID zu Name aus dem Konversations-Kontext auflösen
          const memberName = allMembers.find(m => m.user_id === r.user_id)?.profiles?.name || 'Jemand'
          reactionUsers[r.emoji].push(memberName)
          if (r.user_id === userId) myReactions[r.emoji] = true
        }

        // FIX-9+34: System-Call als zentrierte Karte rendern
        const callMeta = parseSystemCallMessage(msg.content ?? '')
        if (callMeta) {
          const isOutgoing = msg.sender_id === userId
          return (
            <div key={msg.id} className="flex justify-center my-3 animate-fade-in">
              <div className="bg-stone-100 rounded-2xl px-4 py-2.5 flex items-center gap-3 text-sm text-stone-600 shadow-soft max-w-xs">
                {callMeta.type === 'missed' && (
                  <Phone className="w-4 h-4 text-red-500 flex-shrink-0" />
                )}
                {callMeta.type === 'declined' && (
                  <PhoneOff className="w-4 h-4 text-amber-500 flex-shrink-0" />
                )}
                {callMeta.type === 'ended' && (
                  <Phone className="w-4 h-4 text-green-500 flex-shrink-0" />
                )}
                {callMeta.type === 'cancelled' && (
                  <PhoneOff className="w-4 h-4 text-stone-400 flex-shrink-0" />
                )}
                <span className="flex-1">
                  {callMeta.type === 'missed' ? 'Verpasster Anruf' :
                   callMeta.type === 'declined' ? 'Anruf abgelehnt' :
                   callMeta.type === 'ended' ? `Anruf · ${callMeta.duration ?? ''}` :
                   'Anruf abgebrochen'}
                </span>
                {/* FIX-9: Zurückrufen-Button nur bei verpasst + eingehend */}
                {callMeta.type === 'missed' && !isOutgoing && onCallBack && (
                  <button
                    onClick={onCallBack}
                    disabled={(isBanned ?? false) || (dmCallLoading ?? false) || !!activeDMCall}
                    className="text-primary-500 font-semibold hover:text-primary-600 text-sm whitespace-nowrap disabled:opacity-40"
                  >
                    Zurückrufen
                  </button>
                )}
              </div>
            </div>
          )
        }

        return (
          <div key={msg.id}
            className={cn('group flex gap-2.5 mb-0.5', isMe ? 'justify-end' : 'justify-start', !showHeader && !isMe && 'pl-[42px]')}
            style={{ animation: `${isMe ? 'messageInRight' : 'messageInLeft'} 0.28s cubic-bezier(0.34,1.2,0.64,1) both` }}
          >
            {/* Avatar */}
            {!isMe && showHeader && (
              <div className="w-8 h-8 rounded-full bg-gradient-to-br from-primary-200 to-primary-300 flex items-center justify-center text-xs font-bold text-primary-800 flex-shrink-0 mt-auto overflow-hidden relative ring-2 ring-white shadow-sm">
                {msg.profiles?.avatar_url
                  ? <Image src={msg.profiles.avatar_url} alt="" width={32} height={32} className="w-full h-full object-cover" />
                  : (msg.profiles?.name ?? '?')[0].toUpperCase()}
                {msgIsAdmin && (
                  <span className="absolute -bottom-0.5 -right-0.5 w-3.5 h-3.5 bg-amber-400 border-2 border-white rounded-full flex items-center justify-center">
                    <Crown className="w-2 h-2 text-white" />
                  </span>
                )}
              </div>
            )}
            {!isMe && !showHeader && <div className="w-8 flex-shrink-0" />}

            <div className="max-w-[72%] space-y-0.5">
              {/* Name + Admin badge + Donor tier + Pinned */}
              {!isMe && showHeader && (() => {
                const senderTier = getTierInfo(msg.profiles?.donor_tier)
                return (
                  <div className="flex items-center gap-1.5 ml-1">
                    <p className="text-xs font-semibold text-gray-700">
                      {msg.profiles?.name ?? msg.profiles?.nickname ?? 'Nutzer'}
                    </p>
                    {msgIsAdmin && (
                      <span className="text-[9px] font-bold bg-amber-100 text-amber-700 px-1.5 py-0.5 rounded-full flex items-center gap-0.5">
                        <Crown className="w-2 h-2" /> Admin
                      </span>
                    )}
                    {senderTier.tier > 0 && (
                      <span className={cn('text-[9px] font-semibold px-1.5 py-0.5 rounded-full flex items-center gap-0.5', senderTier.pillClass)}
                        title={senderTier.name}>
                        {senderTier.emoji} {senderTier.name}
                      </span>
                    )}
                    {isPinned && <span className="text-[9px] text-amber-600 flex items-center gap-0.5"><Pin className="w-2.5 h-2.5" />Angepinnt</span>}
                  </div>
                )
              })()}

              {/* Reply context */}
              {msg.reply_to && !isDeleted && (
                <div className={cn('px-3 py-1.5 rounded-xl border-l-2 text-xs mb-0.5 max-w-full',
                  isMe ? 'bg-primary-700/40 border-primary-200 text-primary-100' : 'bg-gray-100 border-gray-200 text-gray-500')}>
                  {/* eslint-disable-next-line @typescript-eslint/no-explicit-any */}
                  <p className="font-semibold text-[11px]">{(msg.reply_to as any).profiles?.name ?? 'Nutzer'}</p>
                  <p className="truncate">{msg.reply_to.content}</p>
                </div>
              )}

              {/* Bubble */}
              <div className={cn('relative', isPinned && !isDeleted && 'ring-1 ring-amber-300 rounded-2xl')}>
                {isEditing ? (
                  <div className="flex flex-col gap-2 bg-white border border-primary-300 rounded-2xl p-3 shadow-md min-w-48">
                    <input
                      value={editContent}
                      onChange={e => setEditContent(e.target.value)}
                      onKeyDown={e => { if (e.key === 'Enter') onEditSubmit(msg.id); if (e.key === 'Escape') onEditCancel() }}
                      className="text-sm text-gray-800 bg-transparent outline-none border-b border-stone-200 pb-1"
                      autoFocus
                    />
                    <div className="flex gap-2 justify-end">
                      <button onClick={onEditCancel} className="text-xs text-gray-400 hover:text-gray-600">Abbrechen</button>
                      <button onClick={() => onEditSubmit(msg.id)} className="text-xs text-primary-600 font-semibold hover:text-primary-800">Speichern</button>
                    </div>
                  </div>
                ) : (
                  <div className={cn('px-4 py-2.5 text-sm',
                    isDeleted ? 'bg-gray-100 text-gray-400 italic rounded-2xl shadow-sm'
                      : isMe ? cn('bg-gradient-to-br from-primary-500 to-primary-600 text-white shadow-md shadow-primary-500/20', isLast ? 'rounded-2xl rounded-br-sm' : 'rounded-2xl')
                      : cn('bg-white border border-gray-100 text-gray-800 shadow-sm', isLast ? 'rounded-2xl rounded-bl-sm' : 'rounded-2xl'))}>
                    {isDeleted
                      ? <p className="text-xs">🗑 Nachricht gelöscht</p>
                      : (() => {
                          const voiceMatch = msg.content.match(/^\[Sprachnachricht\s*(\d+)s\]\((.+)\)$/)
                          if (voiceMatch) return (
                            <audio src={voiceMatch[2]} controls className="max-w-[240px] h-10" />
                          )
                          const imgMatch = msg.content.match(/^!?\[Bild\]\((.+)\)$/)
                          if (imgMatch) return (
                            <a href={imgMatch[1]} target="_blank" rel="noopener noreferrer">
                              <img
                                src={imgMatch[1]}
                                alt="Bild"
                                className="max-w-[240px] max-h-64 rounded-xl object-cover cursor-pointer hover:opacity-90 transition-opacity"
                                onError={(e) => {
                                  const t = e.currentTarget
                                  t.style.display = 'none'
                                  t.parentElement?.insertAdjacentHTML('afterend', '<p class="text-xs text-gray-400 italic">Bild nicht verfügbar</p>')
                                }}
                              />
                            </a>
                          )
                          return <p className="leading-relaxed break-words whitespace-pre-wrap" dangerouslySetInnerHTML={{ __html: formatChatMessage(msg.content) }} />
                        })()
                    }
                    {!isDeleted && (
                      <div className={cn('flex items-center gap-1 mt-1', isMe ? 'justify-end' : 'justify-start')}>
                        <p className={cn('text-xs', isMe ? 'text-primary-200' : 'text-gray-400')}>
                          {formatRelativeTime(msg.created_at)}
                          {msg.edited_at && <span className="ml-1 italic opacity-70">bearbeitet</span>}
                        </p>
                        {isMe && (() => {
                          const otherMember = allMembers.find(m => m.user_id !== userId)
                          const otherReadAt = otherMember?.last_read_at ? new Date(otherMember.last_read_at).getTime() : 0
                          const msgTime = new Date(msg.created_at).getTime()
                          const isRead = otherReadAt >= msgTime
                          return isRead
                            ? <CheckCheck className="w-3 h-3 text-blue-400" aria-label="Gelesen" />
                            : <Check className="w-3 h-3 text-primary-200" aria-label="Gesendet" />
                        })()}
                      </div>
                    )}
                  </div>
                )}

                {/* Hover Actions */}
                {!isDeleted && !isEditing && (
                  <div className={cn(
                    'absolute -top-1 flex items-center gap-0.5 opacity-0 group-hover:opacity-100 transition-all duration-150 z-10',
                    isMe ? 'right-full mr-1' : 'left-full ml-1'
                  )}>
                    <button onClick={e => { e.stopPropagation(); onReply(msg) }}
                      className="w-7 h-7 flex items-center justify-center rounded-lg bg-white shadow-md border border-gray-200 text-gray-500 hover:text-primary-600 hover:border-primary-300 transition-all"
                      title="Antworten">
                      <Reply className="w-3 h-3" />
                    </button>
                    <button onClick={e => { e.stopPropagation(); onForward?.(msg) }}
                      className="w-7 h-7 flex items-center justify-center rounded-lg bg-white shadow-md border border-gray-200 text-gray-500 hover:text-primary-500 hover:border-primary-300 transition-all"
                      title="Weiterleiten">
                      <Send className="w-3 h-3 rotate-45" />
                    </button>
                    <button onClick={e => { e.stopPropagation(); setShowEmojiFor(showEmojiFor === msg.id ? null : msg.id) }}
                      className="w-7 h-7 flex items-center justify-center rounded-lg bg-white shadow-md border border-gray-200 text-gray-500 hover:text-yellow-500 hover:border-yellow-300 transition-all"
                      title="Reaktion">
                      <Smile className="w-3 h-3" />
                    </button>
                    {isMe && (
                      <button onClick={e => { e.stopPropagation(); onEdit(msg) }}
                        className="w-7 h-7 flex items-center justify-center rounded-lg bg-white shadow-md border border-gray-200 text-gray-500 hover:text-blue-500 hover:border-blue-300 transition-all"
                        title="Bearbeiten">
                        <Edit2 className="w-3 h-3" />
                      </button>
                    )}
                    {(isMe || isAdmin) && (
                      <button onClick={e => { e.stopPropagation(); onDelete(msg.id, msg.sender_id) }}
                        className="w-7 h-7 flex items-center justify-center rounded-lg bg-white shadow-md border border-gray-200 text-gray-500 hover:text-red-500 hover:border-red-300 transition-all"
                        title="Löschen">
                        <Trash2 className="w-3 h-3" />
                      </button>
                    )}
                    <button onClick={e => {
                        e.stopPropagation()
                        const link = `${window.location.origin}${getMessagePermalink(msg.conversation_id, msg.id)}`
                        navigator.clipboard.writeText(link)
                        toast.success('Link kopiert')
                      }}
                      className="w-7 h-7 flex items-center justify-center rounded-lg bg-white shadow-md border border-gray-200 text-gray-500 hover:text-primary-500 hover:border-primary-300 transition-all"
                      title="Link kopieren">
                      <Link2 className="w-3 h-3" />
                    </button>
                    {isAdmin && (
                      <button onClick={e => { e.stopPropagation(); onPin(msg) }}
                        className={cn('w-7 h-7 flex items-center justify-center rounded-lg bg-white shadow-md border transition-all',
                          isPinned ? 'border-amber-300 text-amber-500 hover:text-amber-700' : 'border-gray-200 text-gray-500 hover:text-amber-500 hover:border-amber-300')}
                        title={isPinned ? 'Loslösen' : 'Anpinnen'}>
                        {isPinned ? <PinOff className="w-3 h-3" /> : <Pin className="w-3 h-3" />}
                      </button>
                    )}
                  </div>
                )}

                {/* Emoji Picker Popup */}
                {showEmojiFor === msg.id && (
                  <div
                    className={cn('absolute z-30 flex gap-1 p-2 bg-white rounded-2xl shadow-2xl border border-gray-200 bottom-full mb-2',
                      isMe ? 'right-0' : 'left-0')}
                    onClick={e => e.stopPropagation()}
                  >
                    {QUICK_EMOJIS.map(emoji => (
                      <button key={emoji} onClick={() => onReaction(msg.id, emoji)}
                        className={cn('w-8 h-8 rounded-xl text-base flex items-center justify-center hover:bg-gray-100 transition-all hover:scale-110',
                          myReactions[emoji] ? 'bg-primary-100 ring-2 ring-primary-400' : '')}>
                        {emoji}
                      </button>
                    ))}
                  </div>
                )}
              </div>

              {/* Reaction Bubbles */}
              {Object.keys(reactionGroups).length > 0 && !isDeleted && (
                <div className={cn('flex flex-wrap gap-1 mt-0.5', isMe ? 'justify-end' : 'justify-start')}>
                  {Object.entries(reactionGroups).map(([emoji, count]) => (
                    <button key={emoji} onClick={() => onReaction(msg.id, emoji)}
                      title={reactionUsers[emoji]?.join(', ') || ''}
                      className={cn('flex items-center gap-1 px-2 py-0.5 rounded-full text-xs border transition-all hover:scale-105',
                        myReactions[emoji]
                          ? 'bg-primary-100 border-primary-300 text-primary-700 shadow-sm'
                          : 'bg-white border-gray-200 text-gray-600 hover:bg-gray-50')}>
                      <span>{emoji}</span>
                      {count > 1 && <span className="font-semibold">{count}</span>}
                    </button>
                  ))}
                </div>
              )}
            </div>
          </div>
        )
      })}
    </>
  )
}

// BUG-FIX: React.memo — MessageGroup nur neu rendern wenn sich Props geändert haben
export const MemoizedMessageGroup = memo(MessageGroup)
