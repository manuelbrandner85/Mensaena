import { getRequestConfig } from 'next-intl/server'
import { cookies } from 'next/headers'

export default getRequestConfig(async () => {
  const cookieStore = await cookies()
  const locale = cookieStore.get('NEXT_LOCALE')?.value || 'de'
  const validLocales = ['de', 'en', 'it', 'tr', 'uk', 'ar']
  const safeLocale = validLocales.includes(locale) ? locale : 'de'

  return {
    locale: safeLocale,
    messages: (await import(`@/messages/${safeLocale}.json`)).default
  }
})
