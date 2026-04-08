'use client'

import { useEffect, useMemo } from 'react'
import { useInteractionStore } from '../stores/useInteractionStore'

export function useInteractionDetail(interactionId: string) {
  const {
    currentInteraction: interaction,
    interactionUpdates: updates,
    detailLoading,
    updatesLoading,
    loadInteractionById,
    loadInteractionUpdates,
    respondToInteraction,
    startProgress,
    completeInteraction,
    cancelInteraction,
    disputeInteraction,
    addUpdate,
  } = useInteractionStore()

  useEffect(() => {
    if (interactionId) {
      loadInteractionById(interactionId)
      loadInteractionUpdates(interactionId)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [interactionId])

  const permissions = useMemo(() => {
    if (!interaction) return {
      canAccept: false, canDecline: false, canStart: false,
      canComplete: false, canCancel: false, canDispute: false, canRate: false,
    }

    const st = interaction.status
    const myRole = interaction.myRole

    // canAccept: status is requested and I'm NOT the creator
    // The creator is the one who initiated. If I'm helper and the helper created it → I'm creator
    // Use the first update with type='created' to determine who initiated
    const createdUpdate = updates.find(u => u.update_type === 'created')
    const iAmCreator = createdUpdate ? createdUpdate.author_id === (myRole === 'helper' ? interaction.helper_id : interaction.helped_id) : false
    const canAccept = st === 'requested' && !iAmCreator
    const canDecline = canAccept
    const canStart = st === 'accepted' && myRole === 'helper'
    const canComplete = st === 'in_progress'
    const canCancel = ['requested', 'accepted', 'in_progress'].includes(st)
    const canDispute = ['accepted', 'in_progress', 'completed'].includes(st) && st !== 'disputed'
    const canRate = st === 'completed' && (
      (myRole === 'helper' && !interaction.helper_rated) ||
      (myRole === 'helped' && !interaction.helped_rated)
    )

    return { canAccept, canDecline, canStart, canComplete, canCancel, canDispute, canRate }
  }, [interaction, updates])

  return {
    interaction,
    updates,
    detailLoading,
    updatesLoading,
    myRole: interaction?.myRole ?? 'helped',
    ...permissions,
    respondToInteraction,
    startProgress,
    completeInteraction,
    cancelInteraction,
    disputeInteraction,
    addUpdate,
  }
}
