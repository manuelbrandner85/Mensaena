/** @type {import('next').NextConfig} */
const nextConfig = {
  // Skip TS-Check & ESLint im Build
  typescript: { ignoreBuildErrors: true },
  eslint:     { ignoreDuringBuilds: true },

  images: {
    remotePatterns: [
      { protocol: 'https', hostname: '*.supabase.co' },
      { protocol: 'https', hostname: 'images.unsplash.com' },
    ],
    unoptimized: true,
  },

  experimental: {
    serverComponentsExternalPackages: ['@supabase/ssr'],
  },

  webpack: (config) => {
    config.parallelism = 1
    return config
  },
}

module.exports = nextConfig
