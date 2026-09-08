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
  title: 'Reviz',
  description:
    'Révise tes cours, entraîne-toi sur des QCM et fais corriger tes copies.',
  manifest: '/manifest.json',
}

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
  viewportFit: 'cover',
  themeColor: '#fcf9f8',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="fr" className={nunitoSans.variable}>
      <head>
        {/* Jeu d'icônes des maquettes Stitch (docs/DESIGN.md § 3). */}
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link
          rel="preconnect"
          href="https://fonts.gstatic.com"
          crossOrigin=""
        />
        <link
          rel="stylesheet"
          href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:opsz,wght,FILL,GRAD@20..48,100..700,0..1,-50..200&display=swap"
        />
      </head>
      <body className="bg-surface text-on-surface text-body-md font-sans">
        {children}
      </body>
    </html>
  )
}
