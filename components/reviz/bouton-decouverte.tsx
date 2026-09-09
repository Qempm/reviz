'use client'

import { useState, useTransition } from 'react'
import { useRouter } from 'next/navigation'
import { Button } from '@/components/ui'
import { activerDecouverte } from '@/app/(app)/boutique/actions'
import { fr } from '@/lib/i18n/fr'

/**
 * Activation du pack gratuit.
 *
 * Seul bouton d'achat vivant tant que FedaPay n'est pas branché : un pack à
 * 0 F ne passe par aucun fournisseur de paiement.
 */
export function BoutonDecouverte({ dejaUtilise }: { dejaUtilise: boolean }) {
  const [erreur, setErreur] = useState<string | null>(null)
  const [enCours, demarrer] = useTransition()
  const router = useRouter()

  if (dejaUtilise) {
    return (
      <Button icon="check" disabled>
        {fr.boutique.decouverteUtilisee}
      </Button>
    )
  }

  return (
    <div className="flex flex-col gap-space-4">
      <Button
        icon="card_giftcard"
        disabled={enCours}
        onClick={() =>
          demarrer(async () => {
            setErreur(null)
            const r = await activerDecouverte()

            if (r.ok) {
              router.push('/reviser')
              return
            }

            setErreur(
              r.error === 'deja-utilise'
                ? fr.boutique.decouverteUtilisee
                : r.error === 'session'
                  ? fr.connexion.erreurs.codeExpire
                  : fr.boutique.activationImpossible,
            )
          })
        }
      >
        {enCours ? fr.commun.chargement : fr.boutique.activerDecouverte}
      </Button>

      {erreur ? (
        <p className="text-center text-label-sm text-reviz-danger">{erreur}</p>
      ) : null}
    </div>
  )
}
