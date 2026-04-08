import type { MetadataRoute } from 'next'
import { SITE_URL } from '@/lib/seo'

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: '*',
        allow: [
          '/',
          '/dashboard/posts/*',
          '/dashboard/profile/*',
          '/dashboard/map',
          '/nutzungsbedingungen',
          '/datenschutz',
          '/impressum',
          '/about',
          '/kontakt',
        ],
        disallow: [
          '/dashboard',
          '/dashboard/chat',
          '/dashboard/settings',
          '/dashboard/notifications',
          '/dashboard/profile',
          '/dashboard/create',
          '/dashboard/admin',
          '/auth',
          '/api',
          '/login',
          '/register',
        ],
      },
    ],
    sitemap: `${SITE_URL}/sitemap.xml`,
    host: SITE_URL,
  }
}
