'use client'

import { use } from 'react'
import { useInteractionDetail } from '../hooks/useInteractionDetail'
import InteractionDetailView from '../components/InteractionDetail'

export default function InteractionDetailPage({
  params,
}: {
  params: Promise<{ interactionId: string }>
}) {
  const { interactionId } = use(params)

  const {
    interaction, updates, detailLoading, updatesLoading, myRole,
    canAccept, canDecline, canStart, canComplete, canCancel, canDispute, canRate,
    respondToInteraction, startProgress, completeInteraction,
    cancelInteraction, disputeInteraction, addUpdate,
  } = useInteractionDetail(interactionId)

  return (
    <InteractionDetailView
      interaction={interaction}
      updates={updates}
      detailLoading={detailLoading}
      updatesLoading={updatesLoading}
      myRole={myRole}
      canAccept={canAccept}
      canDecline={canDecline}
      canStart={canStart}
      canComplete={canComplete}
      canCancel={canCancel}
      canDispute={canDispute}
      canRate={canRate}
      onAccept={respondToInteraction}
      onStart={startProgress}
      onComplete={completeInteraction}
      onCancel={cancelInteraction}
      onDispute={disputeInteraction}
      onAddUpdate={addUpdate}
    />
  )
}
