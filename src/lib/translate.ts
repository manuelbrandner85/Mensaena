const LIBRE_TRANSLATE_URL = 'https://libretranslate.com'

export interface TranslateResult {
  translatedText: string
  detectedLanguage: { confidence: number; language: string }
}

export const SUPPORTED_LANGUAGES = [
  { code: 'de', name: 'Deutsch' },
  { code: 'en', name: 'English' },
  { code: 'tr', name: 'Türkçe' },
  { code: 'uk', name: 'Українська' },
  { code: 'ar', name: 'العربية' },
  { code: 'fr', name: 'Français' },
  { code: 'es', name: 'Español' },
  { code: 'ru', name: 'Русский' },
]

export async function translateText(
  text: string,
  targetLang: string,
  sourceLang: string = 'auto',
): Promise<TranslateResult> {
  try {
    const res = await fetch(`${LIBRE_TRANSLATE_URL}/translate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ q: text, source: sourceLang, target: targetLang, format: 'text' }),
    })
    if (!res.ok) throw new Error(`${res.status}`)
    const data = await res.json()
    return {
      translatedText: data.translatedText ?? text,
      detectedLanguage: data.detectedLanguage ?? { confidence: 0, language: 'unknown' },
    }
  } catch {
    return { translatedText: text, detectedLanguage: { confidence: 0, language: 'unknown' } }
  }
}

export async function detectLanguage(text: string): Promise<string> {
  try {
    const res = await fetch(`${LIBRE_TRANSLATE_URL}/detect`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ q: text }),
    })
    if (!res.ok) throw new Error(`${res.status}`)
    const data: { confidence: number; language: string }[] = await res.json()
    if (!Array.isArray(data) || data.length === 0) return 'de'
    return data.reduce((best, cur) => (cur.confidence > best.confidence ? cur : best)).language
  } catch {
    return 'de'
  }
}
