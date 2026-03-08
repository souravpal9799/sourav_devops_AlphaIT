/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  async rewrites() {
    // Only use API proxy in development
    // In production (Kubernetes), let ingress handle /api/* routing
    if (process.env.NODE_ENV === 'development') {
      return [
        {
          source: '/api/:path*',
          destination: process.env.API_URL ? `${process.env.API_URL}/:path*` : 'http://localhost:8000/:path*',
        },
      ];
    }
    // In production, no rewrites - let ingress handle routing
    return [];
  },
  env: {
    NEXT_PUBLIC_API_URL: process.env.API_URL || '',
  }
}

module.exports = nextConfig
