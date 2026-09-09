'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { cn } from '@/lib/utils'
import { Icon } from './icon'

export type NavTab = {
  href: string
  label: string
  icon: string
}

/** Les 5 onglets de CLAUDE.md, dans l'ordre. */
export const NAV_TABS: NavTab[] = [
  { href: '/', label: 'Accueil', icon: 'home' },
  { href: '/reviser', label: 'Réviser', icon: 'menu_book' },
  { href: '/corriger', label: 'Corriger', icon: 'fact_check' },
  { href: '/gains', label: 'Gains', icon: 'emoji_events' },
  { href: '/profil', label: 'Profil', icon: 'person' },
]

/**
 * Barre de navigation basse (docs/DESIGN.md § 7).
 *
 * Variante à onglet-pilule, arbitrée le 8 septembre 2026 (§ 11) : la barre
 * reste plate à 80 px et les 5 onglets restent égaux. La variante à bouton
 * flottant central présente dans certains écrans Stitch est abandonnée.
 *
 * Prévoir `pb-[96px]` sur le contenu pour dégager la barre et la zone de
 * sécurité basse.
 */
export function BottomNav({
  active,
  tabs = NAV_TABS,
}: {
  /** Force l'onglet actif. Sans cela, il suit la route courante. */
  active?: string
  tabs?: NavTab[]
}) {
  const chemin = usePathname()
  const courant = active ?? chemin

  return (
    <nav
      // Même colonne que le contenu et l'en-tête. Sans « max-w-app », la
      // barre s'étirait d'un bord à l'autre sur tablette pendant que le
      // reste de l'écran restait dans sa colonne de 440 px.
      className="pb-safe fixed inset-x-0 bottom-0 z-50 mx-auto w-full max-w-app bg-surface/90 shadow-nav backdrop-blur-xl"
    >
      <div className="flex h-nav items-center justify-around px-space-8">
        {tabs.map((tab) => {
          // « Accueil » ne s'allume que sur la racine exacte, sinon tous
          // les chemins commenceraient par « / ».
          const isActive =
            tab.href === '/' ? courant === '/' : courant.startsWith(tab.href)

          return (
            <Link
              key={tab.href}
              href={tab.href}
              aria-current={isActive ? 'page' : undefined}
              className={cn(
                'flex h-12 min-w-[56px] flex-col items-center justify-center gap-space-2 px-space-8 transition-all',
                isActive
                  ? 'rounded-full bg-reviz-yellow text-reviz-on-yellow shadow-tactile'
                  : 'text-reviz-muted',
              )}
            >
              <Icon name={tab.icon} size={22} filled={isActive} />
              <span className="text-caption">{tab.label}</span>
            </Link>
          )
        })}
      </div>
    </nav>
  )
}
