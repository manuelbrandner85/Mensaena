const createNextIntlPlugin = require('next-intl/plugin')
const withNextIntl = createNextIntlPlugin('./src/i18n/request.ts')

/** @type {import('next').NextConfig} */
const nextConfig = {
  typescript: { ignoreBuildErrors: true },
  eslint: { ignoreDuringBuilds: true },

  // Required for Cloudflare Pages via @opennextjs/cloudflare
  output: 'standalone',

  trailingSlash: false,
  poweredByHeader: false,

  // Compress output for smaller bundles
  compress: true,

  // Tree-shake large packages → smaller JS bundles
  experimental: {
    optimizePackageImports: [
      'lucide-react',
      'date-fns',
      'react-hot-toast',
      'clsx',
      '@supabase/supabase-js',
      'react-leaflet',
      'leaflet',
      'zustand',
      'tailwind-merge',
    ],
    // Opt-in to the experimental View Transitions bridge so that
    // soft navigations (App Router) use document.startViewTransition().
    // Paired with @view-transition CSS for hard navigations.
    viewTransition: true,
  },

  images: {
    unoptimized: true,
    remotePatterns: [
      { protocol: 'https', hostname: '*.supabase.co' },
      { protocol: 'https', hostname: 'images.unsplash.com' },
      { protocol: 'https', hostname: 'covers.openlibrary.org' },
      { protocol: 'https', hostname: 'api.deutsche-digitale-bibliothek.de' },
      { protocol: 'https', hostname: 'iiif.deutsche-digitale-bibliothek.de' },
      { protocol: 'https', hostname: 'www.deutsche-digitale-bibliothek.de' },
    ],
  },

  // ── Security & performance headers ────────────────────────────────
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'X-Frame-Options', value: 'SAMEORIGIN' },
          { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
          { key: 'Permissions-Policy', value: 'camera=(self), microphone=(self), display-capture=(self), geolocation=(self), payment=()' },
          { key: 'X-XSS-Protection', value: '1; mode=block' },
          { key: 'Strict-Transport-Security', value: 'max-age=63072000; includeSubDomains; preload' },
        ],
      },
      {
        source: '/_next/static/(.*)',
        headers: [
          { key: 'Cache-Control', value: 'public, max-age=31536000, immutable' },
        ],
      },
      {
        source: '/icons/(.*)',
        headers: [
          { key: 'Cache-Control', value: 'public, max-age=2592000' },
        ],
      },
      {
        source: '/sounds/(.*)',
        headers: [
          { key: 'Cache-Control', value: 'public, max-age=2592000' },
        ],
      },
      // Public marketing + legal pages — short TTL + SWR so Cloudflare
      // serves cached HTML instantly while revalidating in background.
      {
        source: '/(|about|kontakt|spenden)',
        headers: [
          { key: 'Cache-Control', value: 'public, max-age=300, stale-while-revalidate=86400' },
        ],
      },
      {
        source: '/(datenschutz|impressum|nutzungsbedingungen|haftungsausschluss|agb)',
        headers: [
          { key: 'Cache-Control', value: 'public, max-age=3600, stale-while-revalidate=604800' },
        ],
      },
      // Dashboard pages are user-specific — never cache at CDN level.
      {
        source: '/dashboard/:path*',
        headers: [
          { key: 'Cache-Control', value: 'private, no-cache, must-revalidate' },
        ],
      },
      // API routes — never cache.
      {
        source: '/api/:path*',
        headers: [
          { key: 'Cache-Control', value: 'no-store, no-cache, must-revalidate' },
        ],
      },
      // Sitemap + robots — short public cache.
      {
        source: '/(sitemap.xml|robots.txt)',
        headers: [
          { key: 'Cache-Control', value: 'public, max-age=3600, stale-while-revalidate=86400' },
        ],
      },
      // Staging preview deployments should never be indexed.
      {
        source: '/:path*',
        has: [{ type: 'host', value: '(?:.*\\.)?mensaena\\.pages\\.dev' }],
        headers: [
          { key: 'X-Robots-Tag', value: 'noindex, nofollow' },
        ],
      },
    ]
  },

  // ── SEO redirects ──────────────────────────────────────────────────
  async redirects() {
    return [
      { source: '/home', destination: '/', permanent: true },
      { source: '/login', destination: '/auth?mode=login', permanent: true },
      { source: '/register', destination: '/auth?mode=register', permanent: true },
      { source: '/signup', destination: '/auth?mode=register', permanent: true },
      { source: '/anmelden', destination: '/auth?mode=login', permanent: true },
      { source: '/registrieren', destination: '/auth?mode=register', permanent: true },
      { source: '/passwort-vergessen', destination: '/auth?mode=forgot', permanent: true },
      { source: '/forgot-password', destination: '/auth?mode=forgot', permanent: true },
      { source: '/passwort-zuruecksetzen', destination: '/auth?mode=reset', permanent: true },
      { source: '/reset-password', destination: '/auth?mode=reset', permanent: true },
      { source: '/privacy', destination: '/datenschutz', permanent: true },
      { source: '/datenschutzerklaerung', destination: '/datenschutz', permanent: true },
      { source: '/imprint', destination: '/impressum', permanent: true },
      { source: '/terms', destination: '/nutzungsbedingungen', permanent: true },
      { source: '/agb', destination: '/nutzungsbedingungen', permanent: true },
      { source: '/tos', destination: '/nutzungsbedingungen', permanent: true },
      { source: '/contact', destination: '/kontakt', permanent: true },
      { source: '/map', destination: '/dashboard/map', permanent: true },
      { source: '/karte', destination: '/dashboard/map', permanent: true },
      { source: '/community-guidelines', destination: '/nutzungsbedingungen', permanent: true },
      { source: '/haftungsausschluss', destination: '/impressum', permanent: true },
      // F-Droid serviert APKs per de.mensaena.app_VERSION.apk Schema.
      // Wir leiten alle Versions-APKs auf die stabile GitHub-Release-URL
      // (latest build). Old versions werden vom F-Droid-Client dann einfach
      // zur neuesten Version upgegradet – ein tolerable Trade-off, damit
      // das Repo klein bleibt und keine APK-Binaries in git landen.
      {
        source: '/fdroid/repo/de.mensaena.app_:version.apk',
        destination:
          'https://github.com/manuelbrandner85/Mensaena/releases/latest/download/mensaena-release.apk',
        permanent: false,
      },
    ]
  },

  // Fix WasmHash issue with Node.js 20+ / Next.js 15.3
  webpack: (config) => {
    config.output = config.output || {}
    config.output.hashFunction = 'xxhash64'
    return config
  },
}

module.exports = withNextIntl(nextConfig)
