import type { Metadata, Viewport } from 'next'
import { Nunito_Sans } from 'next/font/google'
import './globals.css'

/**
 * Nunito Sans — police unique du design system (docs/DESIGN.md § 3).
 * Fonte variable : on ne fige pas de graisse ici, tailwind.config.ts porte
 * l'échelle typographique (500 corps, 700 labels, 800 titres).
 */
const nunitoSans = Nunito_Sans({
  subsets: ['latin'],
  display: 'swap',
  variable: '--font-nunito-sans',
})

export const metadata: Metadata = {
  // Adresse absolue de l'image de partage (`app/opengraph-image.png`) :
  // WhatsApp et Facebook n'affichent pas un aperçu en chemin relatif.
  metadataBase: new URL('https://reviz-eight.vercel.app'),
  title: 'Reviz',
  description:
    'Révise tes cours, entraîne-toi sur des QCM et fais corriger tes copies.',
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
  // Le fond de la deuxième version (#F5F5F7), et non plus le crème de la v1.
  themeColor: '#f5f5f7',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    // Plus de feuille Material Symbols : aucune des deux pages publiques ne
    // s'en sert depuis le retrait des écrans web, et elle faisait télécharger
    // une police d'icônes à chaque visiteur — sur un forfait data limité.
    <html lang="fr" className={nunitoSans.variable}>
      <body className="bg-surface text-on-surface text-body-md font-sans">
        {children}
      </body>
    </html>
  )
}
