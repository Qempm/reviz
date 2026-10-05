import type { Metadata, Viewport } from 'next'
import { Fredoka, Inter } from 'next/font/google'
import './globals.css'

/**
 * Les deux polices de l'identité du 3 octobre 2026 (docs/DESIGN.md § 11 ter),
 * les mêmes que l'application : Inter pour le texte (fonte variable, toutes
 * les graisses), Fredoka pour les titres et les chiffres héros, en sa seule
 * graisse 600. `tailwind.config.ts` les expose en `font-sans` et
 * `font-titre`.
 */
const inter = Inter({
  subsets: ['latin'],
  display: 'swap',
  variable: '--font-inter',
})

const fredoka = Fredoka({
  subsets: ['latin'],
  weight: '600',
  display: 'swap',
  variable: '--font-fredoka',
})

export const metadata: Metadata = {
  // Adresse absolue de l'image de partage (`app/opengraph-image.jpg`) :
  // WhatsApp et Facebook n'affichent pas un aperçu en chemin relatif.
  // L'image est un JPEG de 112 Ko : WhatsApp ignore les aperçus au-delà
  // d'environ 300 Ko, et le PNG en pesait 314. Next ajoute à son adresse
  // une empreinte de son contenu : la changer suffit à faire relire
  // l'aperçu par les messageries.
  metadataBase: new URL('https://revizapp.fun'),
  title: 'Reviz',
  description:
    'Révise tes cours, entraîne-toi sur des QCM et fais corriger tes copies.',
  openGraph: {
    title: 'Reviz — ton cours, ton niveau, ta note',
    description:
      'Des QCM tirés de ton propre cours, et tu vois chapitre par chapitre ce que tu maîtrises. 3 jours gratuits, sans abonnement.',
    url: 'https://revizapp.fun',
    siteName: 'Reviz',
    locale: 'fr_FR',
    type: 'website',
  },
  twitter: { card: 'summary_large_image' },
  // Pas de `manifest` : il n'y a plus d'application web à installer depuis le
  // navigateur, et celui de `public/` désignait trois icônes qui n'ont jamais
  // existé — soit trois 404 à chaque visite des deux pages publiques. La
  // distribution passe par l'APK (`/app`).
}

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  // Le zoom reste permis : le bloquer empêche un étudiant malvoyant
  // d'agrandir le texte, et Android l'ignore de toute façon en partie.
  viewportFit: 'cover',
  // Le crème de l'identité du 3 octobre 2026 (#FCEFD0).
  themeColor: '#fcefd0',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    // Plus de feuille Material Symbols : aucune des pages publiques ne s'en
    // sert depuis le retrait des écrans web, et elle faisait télécharger une
    // police d'icônes à chaque visiteur — sur un forfait data limité.
    <html lang="fr" className={`${inter.variable} ${fredoka.variable}`}>
      <body className="bg-surface text-on-surface text-body-md font-sans">
        {children}
      </body>
    </html>
  )
}
