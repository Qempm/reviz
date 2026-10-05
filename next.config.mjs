/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // Le dossier apps/android/ est une coquille Capacitor, hors du build web.
  outputFileTracingExcludes: {
    // Ni la coquille Kotlin ni le projet Flutter n'ont à peser sur le paquet
    // déployé sur Vercel.
    '*': ['./apps/android/**', './apps/mobile/**'],
  },
  // La version web de l'application (`npm run web`) vit dans public/web/.
  // Next.js sert ses fichiers, mais pas l'index d'un dossier : sans ces
  // réécritures, /web répondrait 404. Les écrans de l'application sont dans
  // le fragment (#/accueil), donc rien d'autre à réécrire.
  async rewrites() {
    return [
      { source: '/web', destination: '/web/index.html' },
      { source: '/web/', destination: '/web/index.html' },
    ]
  },
  // Le service worker de la version web (`apps/mobile/web/sw.js`) vit dans
  // /web/, mais la page, elle, est servie à /web — Next.js redirige /web/
  // vers /web. Sa portée doit donc couvrir /web, ce qu'un script de /web/ ne
  // peut obtenir que si le serveur le permet. Et jamais de cache HTTP sur
  // lui : une nouvelle version doit être vue dès la visite suivante.
  async headers() {
    return [
      {
        source: '/web/sw.js',
        headers: [
          { key: 'Service-Worker-Allowed', value: '/web' },
          { key: 'Cache-Control', value: 'no-cache' },
        ],
      },
    ]
  },
}

export default nextConfig
