/** @type {import('next').NextConfig} */
const nextConfig = {
  // Skip TS-Check & ESLint im Build (spart RAM + Zeit)
  typescript: { ignoreBuildErrors: true },
  eslint:     { ignoreDuringBuilds: true },

  images: {
    remotePatterns: [
      { protocol: 'https', hostname: '*.supabase.co' },
      { protocol: 'https', hostname: 'images.unsplash.com' },
    ],
    // Cloudflare Pages: kein Image-Optimization-Server
    unoptimized: true,
  },

  // Cloudflare Pages / next-on-pages Kompatibilität
  experimental: {
    serverComponentsExternalPackages: ['@supabase/ssr'],
  },

  // Speicher-Optimierung für Low-RAM-Build (lokal)
  webpack: (config, { isServer }) => {
    config.parallelism = 1
    return config
  },
}

module.exports = nextConfig
