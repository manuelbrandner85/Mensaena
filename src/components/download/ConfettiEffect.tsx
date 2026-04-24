'use client'

import { useEffect, useRef } from 'react'
import Confetti from '@/components/shared/Confetti'

interface Props {
  active: boolean
}

export default function ConfettiEffect({ active }: Props) {
  const firedRef = useRef(false)

  useEffect(() => {
    if (active) firedRef.current = true
  }, [active])

  // Only show on first activation; don't re-trigger after close
  return <Confetti active={active && !firedRef.current} duration={2500} />
}
