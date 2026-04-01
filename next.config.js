/** @type {import('next').NextConfig} */
const nextConfig = {
  // Skip TS-Check & ESLint im Build (spart RAM)
  typescript: { ignoreBuildErrors: true },
  eslint:     { ignoreDuringBuilds: true },
  images: {
    remotePatterns: [
      { protocol: 'https', hostname: '*.supabase.co' },
      { protocol: 'https', hostname: 'images.unsplash.com' },
    ],
  },
  // Speicher-Optimierung für Low-RAM Build
  webpack: (config) => {
    config.parallelism = 1
    return config
  },
  experimental: {
    serverComponentsExternalPackages: ['@supabase/ssr'],
    workerThreads: false,
    cpus: 1,
  },
}

module.exports = nextConfig
