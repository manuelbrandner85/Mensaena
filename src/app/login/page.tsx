'use client'

import { useEffect } from 'react'
import { useRouter } from 'next/navigation'

/** Legacy route – redirects to the unified /auth page */
export default function LoginRedirect() {
  const router = useRouter()
  useEffect(() => {
    router.replace('/auth?mode=login')
  }, [router])
  return null
}
