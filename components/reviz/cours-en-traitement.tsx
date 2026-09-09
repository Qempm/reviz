'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { Button, Card, MascotState } from '@/components/ui'
import { useAnimationsReduites } from '@/lib/motion/reduced'
import { fr } from '@/lib/i18n/fr'

/**
 * Écran D2 — attente de traitement d'un cours.
 *
 * Deux décisions de fond.
 *
 * **Pas de barre de progression.** On ne mesure pas l'avancement du
 * traitement : une barre qui monte de 0 à 90 % puis s'arrête est un mensonge,
 * et l'étudiant qui l'a vue une fois ne croit plus aucun écran d'attente. Des
 * étapes qui défilent disent la même chose sans rien promettre.
 *
 * **Relance bornée.** L'écran se rafraîchit dix fois, à cadence décroissante,
 * puis s'arrête et propose un bouton. La cible a un forfait limité : un
 * `setInterval` laissé ouvert sur un onglet oublié consommerait toute la nuit.
 */

/** Délais entre deux relances, en secondes. La somme fait ~3 minutes. */
const CADENCE = [4, 4, 6, 8, 10, 15, 20, 30, 40, 60]

export function CoursEnTraitement() {
  const [etape, setEtape] = useState(0)
  const [essai, setEssai] = useState(0)
  const router = useRouter()
  const reduites = useAnimationsReduites()

  const etapes = fr.cours.traitementEtapes
  const epuise = essai >= CADENCE.length

  // Les étapes défilent pour elles-mêmes, indépendamment des relances : le
  // rythme de l'écran ne doit pas trahir celui du réseau.
  useEffect(() => {
    if (reduites) return
    const id = setInterval(() => setEtape((e) => (e + 1) % etapes.length), 2600)
    return () => clearInterval(id)
  }, [etapes.length, reduites])

  useEffect(() => {
    if (epuise) return

    const id = setTimeout(() => {
      // `refresh()` rejoue le composant serveur : si `courses.status` est
      // passé à `ready`, la page bascule d'elle-même.
      router.refresh()
      setEssai((n) => n + 1)
    }, CADENCE[essai] * 1000)

    return () => clearTimeout(id)
  }, [essai, epuise, router])

  return (
    <div className="flex flex-1 flex-col items-center justify-center gap-space-24">
      <MascotState
        mood="chargement"
        title={fr.cours.traitementTitre}
        description={fr.cours.traitementDetail}
      />

      <Card size="sm">
        <span
          key={etape}
          className={
            reduites
              ? 'text-center text-label-md text-reviz-ink'
              : 'animate-apparition text-center text-label-md text-reviz-ink'
          }
        >
          {etapes[etape]}
        </span>

        {/* Trois points qui pulsent : la seule animation de l'écran, et elle
            ne prétend rien mesurer. */}
        {reduites ? null : (
          <span className="flex items-center justify-center gap-space-4">
            {[0, 1, 2].map((i) => (
              <span
                key={i}
                className="h-2 w-2 animate-pulsation rounded-full bg-reviz-yellow"
                style={{ animationDelay: `${i * 0.16}s` }}
              />
            ))}
          </span>
        )}

        <p className="text-center text-label-sm text-reviz-muted">
          {epuise ? fr.cours.traitementLong : fr.cours.traitementAstuce}
        </p>
      </Card>

      {epuise ? (
        <Button
          variant="secondary"
          icon="refresh"
          onClick={() => {
            setEssai(0)
            router.refresh()
          }}
        >
          {fr.cours.actualiser}
        </Button>
      ) : null}
    </div>
  )
}
