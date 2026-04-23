'use client'

import { useState, useRef, useEffect } from 'react'
import { Languages, Loader2, ChevronDown } from 'lucide-react'
import { translateText, SUPPORTED_LANGUAGES } from '@/lib/translate'
import { cn } from '@/lib/utils'

interface TranslateButtonProps {
  text: string
  onTranslated: (translatedText: string) => void
}

export default function TranslateButton({ text, onTranslated }: TranslateButtonProps) {
  const [isTranslated, setIsTranslated] = useState(false)
  const [loading, setLoading] = useState(false)
  const [targetLang, setTargetLang] = useState('de')
  const [showDropdown, setShowDropdown] = useState(false)
  const [originalText] = useState(text)
  const dropdownRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target as Node)) {
        setShowDropdown(false)
      }
    }
    if (showDropdown) document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [showDropdown])

  async function handleTranslate() {
    if (isTranslated) {
      onTranslated(originalText)
      setIsTranslated(false)
      return
    }
    setLoading(true)
    try {
      const { translatedText } = await translateText(text, targetLang)
      onTranslated(translatedText)
      setIsTranslated(true)
    } finally {
      setLoading(false)
    }
  }

  async function handleLangSelect(code: string) {
    setShowDropdown(false)
    setTargetLang(code)
    if (isTranslated) {
      setLoading(true)
      try {
        const { translatedText } = await translateText(originalText, code)
        onTranslated(translatedText)
      } finally {
        setLoading(false)
      }
    }
  }

  const selectedLang = SUPPORTED_LANGUAGES.find(l => l.code === targetLang)

  return (
    <div className="relative inline-flex items-center" ref={dropdownRef}>
      <button
        onClick={handleTranslate}
        disabled={loading}
        title={isTranslated ? 'Original anzeigen' : `Übersetzen auf ${selectedLang?.name}`}
        className={cn(
          'flex items-center gap-0.5 text-xs p-1 rounded transition-colors',
          isTranslated
            ? 'text-primary-500 hover:bg-primary-50'
            : 'text-gray-400 hover:bg-stone-100',
          loading && 'opacity-60 cursor-not-allowed'
        )}
      >
        {loading
          ? <Loader2 className="w-3.5 h-3.5 animate-spin" />
          : <Languages className="w-3.5 h-3.5" />
        }
      </button>

      <button
        onClick={() => setShowDropdown(prev => !prev)}
        title="Sprache wählen"
        className={cn(
          'flex items-center p-0.5 rounded transition-colors text-gray-400 hover:bg-stone-100',
          showDropdown && 'bg-stone-100'
        )}
      >
        <ChevronDown className="w-3 h-3" />
      </button>

      {showDropdown && (
        <div className="absolute bottom-full left-0 mb-1 z-50 bg-white border border-stone-200 rounded-lg shadow-md py-1 min-w-[130px]">
          {SUPPORTED_LANGUAGES.map(lang => (
            <button
              key={lang.code}
              onClick={() => handleLangSelect(lang.code)}
              className={cn(
                'w-full text-left px-3 py-1.5 text-xs hover:bg-stone-50 transition-colors',
                lang.code === targetLang && 'text-primary-500 font-medium bg-primary-50/40'
              )}
            >
              {lang.name}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
