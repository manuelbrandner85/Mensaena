'use client'

import { useState } from 'react'
import SOSButton from './SOSButton'
import SOSModal from './SOSModal'

/**
 * Global SOS button – rendered inline in the header bar.
 * Uses the 'header' variant (rectangular, subtle blink).
 */
export default function GlobalSOSButton() {
  const [isOpen, setIsOpen] = useState(false)

  return (
    <>
      <SOSButton onClick={() => setIsOpen(true)} variant="header" />
      <SOSModal isOpen={isOpen} onClose={() => setIsOpen(false)} />
    </>
  )
}
