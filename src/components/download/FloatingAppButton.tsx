'use client'

import { useEffect, useRef, useState } from 'react'

export default function FloatingAppButton() {
  const [visible, setVisible] = useState(false)
  const [isNative, setIsNative] = useState(true)
  const sectionRef = useRef<IntersectionObserver | null>(null)

  useEffect(() => {
    // Hide inside the Capacitor APK
    setIsNative(document.documentElement.classList.contains('is-native'))
  }, [])

  useEffect(() => {
    if (isNative) return

    // Show button after a brief delay so it doesn't flash on load
    const showTimer = setTimeout(() => setVisible(true), 1200)

    const section = document.getElementById('app-download')
    if (section) {
      sectionRef.current = new IntersectionObserver(
        ([entry]) => setVisible(!entry.isIntersecting),
        { threshold: 0.15 },
      )
      sectionRef.current.observe(section)
    }

    return () => {
      clearTimeout(showTimer)
      sectionRef.current?.disconnect()
    }
  }, [isNative])

  const scrollToSection = () => {
    document.getElementById('app-download')?.scrollIntoView({ behavior: 'smooth' })
  }

  if (isNative || !visible) return null

  return (
    <div
      className="md:hidden fixed bottom-6 right-6 z-40 cta-app-download"
      aria-label="App herunterladen"
    >
      {/* Pulsing attention ring */}
      <span
        className="absolute inset-0 rounded-full bg-primary-400 animate-pulse-ring"
        aria-hidden="true"
      />
      <span
        className="absolute inset-0 rounded-full bg-primary-300 animate-pulse-ring [animation-delay:0.5s]"
        aria-hidden="true"
      />

      <button
        onClick={scrollToSection}
        aria-label="Zur App-Download-Sektion scrollen"
        className="relative w-14 h-14 rounded-full bg-primary-600 hover:bg-primary-700 active:scale-95 text-white shadow-glow-teal flex items-center justify-center transition-all duration-300"
      >
        {/* Android-style download icon */}
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
          className="w-6 h-6"
          aria-hidden="true"
        >
          <path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20z" className="opacity-0" />
          <polyline points="8 17 12 21 16 17" />
          <line x1="12" y1="12" x2="12" y2="21" />
          <path d="M20.88 18.09A5 5 0 0 0 18 9h-1.26A8 8 0 1 0 3 16.29" className="opacity-0" />
          <path d="M7 10l5 5 5-5" />
          <path d="M12 4v11" />
        </svg>
      </button>
    </div>
  )
}
