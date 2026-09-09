'use client'

import { useEffect, type ReactNode } from 'react'
import { AnimatePresence, motion } from 'motion/react'
import { useAnimationsReduites } from '@/lib/motion/reduced'
import { feuille, IMMOBILE } from '@/lib/motion/variantes'
import { Icon } from './icon'

export type BottomSheetProps = {
  ouverte: boolean
  onFermer: () => void
  titre?: string
  children: ReactNode
}

/**
 * Feuille modale qui monte du bas (docs/DESIGN.md § 7 : rayon 28 px en haut,
 * poignée de 36 × 4).
 *
 * Sur mobile, une modale centrée oblige le pouce à remonter ; la feuille
 * arrive là où la main se trouve déjà.
 */
export function BottomSheet({ ouverte, onFermer, titre, children }: BottomSheetProps) {
  const reduites = useAnimationsReduites()

  // Bloque le défilement de la page derrière, sinon le doigt fait défiler le
  // contenu sous la feuille.
  useEffect(() => {
    if (!ouverte) return
    const avant = document.body.style.overflow
    document.body.style.overflow = 'hidden'

    const surEchap = (e: KeyboardEvent) => e.key === 'Escape' && onFermer()
    window.addEventListener('keydown', surEchap)

    return () => {
      document.body.style.overflow = avant
      window.removeEventListener('keydown', surEchap)
    }
  }, [ouverte, onFermer])

  return (
    <AnimatePresence>
      {ouverte ? (
        <>
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: reduites ? 0 : 0.2 }}
            onClick={onFermer}
            className="fixed inset-0 z-50 bg-inverse-surface/40"
            aria-hidden="true"
          />

          <motion.div
            role="dialog"
            aria-modal="true"
            aria-label={titre}
            variants={reduites ? IMMOBILE : feuille}
            initial="cache"
            animate="visible"
            exit="sortie"
            className="pb-safe fixed inset-x-0 bottom-0 z-50 mx-auto w-full max-w-app rounded-t-sheet bg-reviz-card"
          >
            <div className="flex flex-col gap-space-16 p-space-20">
              <span
                aria-hidden="true"
                className="mx-auto h-1 w-9 rounded-full bg-reviz-border"
              />

              {titre ? (
                <div className="flex items-center justify-between gap-space-12">
                  <h2 className="text-headline-md text-reviz-ink">{titre}</h2>
                  <button
                    type="button"
                    onClick={onFermer}
                    aria-label="Fermer"
                    className="flex h-12 w-12 items-center justify-center rounded-full text-reviz-muted"
                  >
                    <Icon name="close" size={22} />
                  </button>
                </div>
              ) : null}

              {children}
            </div>
          </motion.div>
        </>
      ) : null}
    </AnimatePresence>
  )
}
