/** @type {import('next').NextConfig} */
const nextConfig = {
  typescript: { ignoreBuildErrors: true },
  eslint:     { ignoreDuringBuilds: true },
  images: {
    unoptimized: true,
    remotePatterns: [
      { protocol: 'https', hostname: '*.supabase.co' },
      { protocol: 'https', hostname: 'images.unsplash.com' },
    ],
  },
  serverExternalPackages: ['@supabase/ssr'],
  webpack: (config) => {
    // Fix WasmHash issue with Node.js 20+ / Next.js 15.3
    config.output = config.output || {}
    config.output.hashFunction = 'xxhash64'
    return config
  },
}

module.exports = nextConfig
