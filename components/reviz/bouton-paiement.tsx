'use client'

import { useState, useTransition } from 'react'
import { useRouter } from 'next/navigation'
import { Button } from '@/components/ui'
import { initiatePayment } from '@/app/(app)/boutique/actions'
import { fr } from '@/lib/i18n/fr'

/**
 * Initiateur de paiement FedaPay.
 *
 * Appelle l'action initiatePayment, qui crée un payment record
 * et retourne l'URL de redirection vers FedaPay.
 */
export function BoutonPaiement({
  packCode,
}: {
  packCode: 'decouverte' | 'controle' | 'partiel' | 'semestre' | 'rattrapage'
}) {
  const [erreur, setErreur] = useState<string | null>(null)
  const [enCours, demarrer] = useTransition()
  const router = useRouter()

  return (
    <div className="flex flex-col gap-space-4">
      <Button
        icon="shopping_cart"
        disabled={enCours}
        onClick={() =>
          demarrer(async () => {
            setErreur(null)
            const r = await initiatePayment(packCode)

            if (r.ok) {
              // Redirection immédiate vers FedaPay
              window.location.href = r.redirectUrl
              return
            }

            const messages: Record<string, string> = {
              session: 'Session expirée',
              reseau: 'Erreur de connexion',
              serveur: 'Erreur serveur. Veuillez réessayer.',
            }

            setErreur(messages[r.error] || 'Erreur inconnue')
          })
        }
      >
        {enCours ? fr.commun.chargement : fr.boutique.choisir}
      </Button>

      {erreur ? (
        <p className="text-center text-label-sm text-reviz-danger">{erreur}</p>
      ) : null}
    </div>
  )
}
