/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // Le dossier apps/android/ est une coquille Capacitor, hors du build web.
  outputFileTracingExcludes: {
    // Ni la coquille Kotlin ni le projet Flutter n'ont à peser sur le paquet
    // déployé sur Vercel.
    '*': ['./apps/android/**', './apps/mobile/**'],
  },
}

export default nextConfig
