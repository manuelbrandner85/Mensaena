'use client'

import { useEffect } from 'react'
import { useRouter } from 'next/navigation'

/** Legacy route – redirects to the unified /auth page */
export default function RegisterRedirect() {
  const router = useRouter()
  useEffect(() => {
    router.replace('/auth?mode=register')
  }, [router])
  return null
}
