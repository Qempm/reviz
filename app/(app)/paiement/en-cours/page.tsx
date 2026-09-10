'use client'

import { useEffect, useState } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import { Button, Card, Icon } from '@/components/ui'
import { fr } from '@/lib/i18n/fr'

/**
 * Écran 4a — Paiement en cours.
 *
 * L'utilisateur revient du lien FedaPay avec un code paramètre.
 * On polle le statut du paiement jusqu'à confirmation ou échec,
 * puis redirige vers succès ou erreur.
 */
export default function PaiementEnCours() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const [statut, setStatut] = useState<'polling' | 'success' | 'failed'>('polling')
  const [erreur, setErreur] = useState<string>('')

  useEffect(() => {
    const pollStatus = async () => {
      // Le webhook aura mis à jour la base dans les secondes suivant le retour.
      // On peut aussi faire un appel optionnel de vérification côté client,
      // mais le webhook est déjà la source de vérité. On attend juste que
      // le rôle de service ait eu le temps de traiter.

      // Attendre 3 secondes avant la première vérification
      await new Promise(resolve => setTimeout(resolve, 3000))

      try {
        const res = await fetch('/api/payments/status', {
          method: 'GET',
        })

        if (!res.ok) {
          setErreur('Impossible de vérifier le statut')
          setStatut('failed')
          return
        }

        const data = (await res.json()) as {
          ok: boolean
          status: 'pending' | 'success' | 'failed'
          error?: string
        }

        if (!data.ok) {
          setErreur(data.error || 'Erreur inconnue')
          setStatut('failed')
          return
        }

        if (data.status === 'success') {
          setStatut('success')
          // Rediriger après 2s
          setTimeout(() => router.push('/paiement/succes'), 2000)
        } else if (data.status === 'failed') {
          setErreur("Le paiement a été décliné")
          setStatut('failed')
          // Rediriger après 3s
          setTimeout(() => router.push('/paiement/erreur'), 3000)
        } else {
          // Continuer le polling
          setTimeout(pollStatus, 2000)
        }
      } catch (e) {
        console.error('Error polling payment status:', e)
        setErreur('Erreur de connexion')
        setStatut('failed')
      }
    }

    pollStatus()
  }, [router])

  return (
    <div className="flex flex-col gap-space-20">
      <header className="flex flex-col gap-space-4">
        <h1 className="text-headline-xl text-reviz-ink">
          Paiement en cours
        </h1>
        <p className="text-body-md text-reviz-muted">
          Vérification auprès de votre opérateur…
        </p>
      </header>

      <Card>
        <div className="flex flex-col items-center gap-space-16 py-space-32">
          {statut === 'polling' && (
            <>
              <div className="animate-spin">
                <Icon name="hourglass_top" size={48} className="text-primary" filled />
              </div>
              <p className="text-center text-body-md text-reviz-muted">
                Ne fermez pas cette page…
              </p>
            </>
          )}

          {statut === 'failed' && (
            <>
              <Icon name="error" size={48} className="text-reviz-danger" filled />
              <div className="flex flex-col items-center gap-space-4">
                <p className="text-center text-headline-md text-reviz-ink">
                  Paiement décliné
                </p>
                <p className="text-center text-body-md text-reviz-muted">
                  {erreur || 'Veuillez réessayer'}
                </p>
              </div>
            </>
          )}

          {statut === 'success' && (
            <>
              <Icon name="check_circle" size={48} className="text-primary" filled />
              <p className="text-center text-headline-md text-reviz-ink">
                Paiement confirmé!
              </p>
            </>
          )}
        </div>
      </Card>

      {statut === 'failed' && (
        <Button
          onClick={() => router.push('/boutique')}
          variant="secondary"
          icon="arrow_back"
        >
          Retourner à la boutique
        </Button>
      )}
    </div>
  )
}
