'use client'

import { useState } from 'react'
import { CheckCircle, Loader2, Star } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { createNotification } from '@/lib/notifications'
import { useRatingStore } from '@/store/useRatingStore'
import toast from 'react-hot-toast'

interface CompleteInteractionButtonProps {
  interactionId: string
  postId: string
  postTitle: string
  helperId: string
  helperName: string | null
  helperAvatar: string | null
  postOwnerId: string
  postOwnerName: string | null
  postOwnerAvatar: string | null
  currentUserId: string
  onCompleted?: () => void
}

export default function CompleteInteractionButton({
  interactionId,
  postId,
  postTitle,
  helperId,
  helperName,
  helperAvatar,
  postOwnerId,
  postOwnerName,
  postOwnerAvatar,
  currentUserId,
  onCompleted,
}: CompleteInteractionButtonProps) {
  const [loading, setLoading] = useState(false)
  const { openRatingModal } = useRatingStore()

  const handleComplete = async () => {
    setLoading(true)
    const supabase = createClient()

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const { error } = await (supabase.from('interactions') as any)
      .update({
        status: 'completed',
        completed_at: new Date().toISOString(),
      })
      .eq('id', interactionId)

    if (error) {
      toast.error('Interaktion konnte nicht abgeschlossen werden')
      setLoading(false)
      return
    }

    // Create notifications for both parties
    const isHelper = currentUserId === helperId
    const partnerId = isHelper ? postOwnerId : helperId
    const partnerName = isHelper ? postOwnerName : helperName

    await createNotification({
      userId: partnerId,
      type: 'interaction',
      category: 'interaction',
      title: 'Interaktion abgeschlossen',
      content: `Die Zusammenarbeit bei "${postTitle}" wurde abgeschlossen. Bewerte jetzt deinen Nachbarn!`,
      link: `/dashboard/posts/${postId}`,
      actorId: currentUserId,
      metadata: { post_id: postId, interaction_id: interactionId },
    })

    toast.success('Interaktion abgeschlossen!')
    onCompleted?.()

    // Open rating modal for the partner
    openRatingModal({
      partnerId: partnerId,
      partnerName: partnerName,
      partnerAvatar: isHelper ? postOwnerAvatar : helperAvatar,
      interactionId: interactionId,
      postTitle: postTitle,
    })

    setLoading(false)
  }

  return (
    <button
      onClick={handleComplete}
      disabled={loading}
      className="flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium bg-green-600 text-white hover:bg-green-700 transition-all disabled:opacity-50 active:scale-95"
    >
      {loading ? (
        <Loader2 className="w-4 h-4 animate-spin" />
      ) : (
        <CheckCircle className="w-4 h-4" />
      )}
      Abschliessen & Bewerten
    </button>
  )
}
