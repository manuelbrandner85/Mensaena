/** @type {import('next').NextConfig} */
const nextConfig = {
  typescript: { ignoreBuildErrors: true },
  eslint: { ignoreDuringBuilds: true },

  // Required for Cloudflare Pages via @opennextjs/cloudflare
  output: 'standalone',

  trailingSlash: false,

  images: {
    unoptimized: true,
    remotePatterns: [
      { protocol: 'https', hostname: '*.supabase.co' },
      { protocol: 'https', hostname: 'images.unsplash.com' },
    ],
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
    ]
  },

  // Fix WasmHash issue with Node.js 20+ / Next.js 15.3
  webpack: (config) => {
    config.output = config.output || {}
    config.output.hashFunction = 'xxhash64'
    return config
  },
}

module.exports = nextConfig
