'use client'

import { useEffect, useState } from 'react'
import { Moon, Sun } from 'lucide-react'

export default function DarkModeToggle() {
  const [dark, setDark] = useState(false)

  useEffect(() => {
    // Read saved preference
    const saved = localStorage.getItem('mensaena_dark')
    if (saved === 'true' || (!saved && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
      setDark(true)
      document.documentElement.classList.add('dark')
    }
  }, [])

  const toggle = () => {
    setDark((prev) => {
      const next = !prev
      if (next) {
        document.documentElement.classList.add('dark')
        localStorage.setItem('mensaena_dark', 'true')
      } else {
        document.documentElement.classList.remove('dark')
        localStorage.setItem('mensaena_dark', 'false')
      }
      return next
    })
  }

  return (
    <button
      onClick={toggle}
      title={dark ? 'Heller Modus' : 'Dunkler Modus'}
      className="w-9 h-9 flex items-center justify-center rounded-xl border border-gray-200 hover:border-green-300 transition-all text-gray-600 hover:text-green-700 bg-white dark:bg-gray-800 dark:border-gray-700 dark:text-gray-300"
    >
      {dark ? <Sun className="w-4 h-4" /> : <Moon className="w-4 h-4" />}
    </button>
  )
}
