/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // Le dossier apps/android/ est une coquille Capacitor, hors du build web.
  outputFileTracingExcludes: {
    '*': ['./apps/android/**'],
  },
}

export default nextConfig
