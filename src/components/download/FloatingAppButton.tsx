'use client'

import { useEffect, useRef, useState } from 'react'
import Link from 'next/link'

export default function FloatingAppButton() {
  const [visible, setVisible] = useState(false)
  const [isNative, setIsNative] = useState(true)
  const [hasSection, setHasSection] = useState(false)
  const sectionRef = useRef<IntersectionObserver | null>(null)

  useEffect(() => {
    setIsNative(document.documentElement.classList.contains('is-native'))
  }, [])

  useEffect(() => {
    if (isNative) return

    const showTimer = setTimeout(() => setVisible(true), 1200)

    const section = document.getElementById('app-download')
    if (section) {
      setHasSection(true)
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

  if (isNative || !visible) return null

  const buttonContent = (
    <>
      <span className="absolute inset-0 rounded-full bg-primary-400 animate-pulse-ring" aria-hidden="true" />
      <span className="absolute inset-0 rounded-full bg-primary-300 animate-pulse-ring [animation-delay:0.5s]" aria-hidden="true" />
      <span
        className="relative w-14 h-14 rounded-full text-white flex items-center justify-center"
        style={{
          background: 'linear-gradient(135deg, #1EAAA6 0%, #147170 100%)',
          border: '1px solid rgba(255,255,255,0.14)',
          boxShadow: '0 0 0 0.5px rgba(0,0,0,0.05), 0 8px 24px rgba(30,170,166,0.35), 0 0 32px rgba(30,170,166,0.30), inset 0 1px 0 rgba(255,255,255,0.25)',
        }}
      >
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
          <path d="M7 10l5 5 5-5" />
          <path d="M12 4v11" />
          <polyline points="8 17 12 21 16 17" />
        </svg>
      </span>
    </>
  )

  return (
    <div
      className="md:hidden fixed bottom-6 right-6 z-40 cta-app-download"
      aria-label="App herunterladen"
    >
      {hasSection ? (
        <button
          onClick={() => document.getElementById('app-download')?.scrollIntoView({ behavior: 'smooth' })}
          aria-label="Zur App-Download-Sektion scrollen"
          className="relative w-14 h-14 rounded-full active:scale-95 transition-all duration-300 flex items-center justify-center"
        >
          {buttonContent}
        </button>
      ) : (
        <Link
          href="/app"
          aria-label="App herunterladen"
          className="relative w-14 h-14 rounded-full active:scale-95 transition-all duration-300 flex items-center justify-center"
        >
          {buttonContent}
        </Link>
      )}
    </div>
  )
}
