'use client'

import { useState, useCallback } from 'react'
import SOSButton from './SOSButton'
import SOSModal from './SOSModal'

/**
 * Global SOS button – rendered inline in the header bar.
 * Uses the 'header' variant (rectangular, subtle blink).
 * stopPropagation prevents parent header handlers from interfering.
 */
export default function GlobalSOSButton() {
  const [isOpen, setIsOpen] = useState(false)

  const handleOpen = useCallback(() => setIsOpen(true), [])
  const handleClose = useCallback(() => setIsOpen(false), [])

  return (
    <div onClick={(e) => e.stopPropagation()}>
      <SOSButton onClick={handleOpen} variant="header" />
      <SOSModal isOpen={isOpen} onClose={handleClose} />
    </div>
  )
}
