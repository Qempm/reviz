import Link from 'next/link'
import { redirect } from 'next/navigation'
import { Button, Card, Icon } from '@/components/ui'
import { createClient } from '@/lib/supabase/server'

/**
 * Écran 4c — Confirmation paiement décliné.
 *
 * Affiche le motif d'erreur et propose de réessayer ou retourner à la boutique.
 */
export default async function PaiementErreur() {
  const supabase = await createClient()

  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) redirect('/connexion')

  // Récupère le dernier paiement échoué pour afficher un détail si possible
  const { data: payment } = await supabase
    .from('payments')
    .select('pack_code, status, amount_fcfa')
    .eq('user_id', user.id)
    .eq('status', 'failed')
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle()

  return (
    <div className="flex flex-col gap-space-20">
      <header className="flex flex-col gap-space-4">
        <h1 className="text-headline-xl text-reviz-ink">
          Paiement décliné
        </h1>
        <p className="text-body-md text-reviz-muted">
          Le paiement n'a pas pu être complété. Veuillez vérifier et réessayer.
        </p>
      </header>

      <Card>
        <div className="flex flex-col items-center gap-space-16 py-space-20">
          <Icon name="error" size={48} className="text-reviz-danger" filled />

          <div className="flex flex-col gap-space-8">
            <div className="flex items-center gap-space-12">
              <Icon name="warning" size={20} className="text-reviz-danger" />
              <span className="text-body-md text-reviz-ink">
                Vérifiez votre compte Mobile Money et votre solde.
              </span>
            </div>

            {payment && (
              <div className="flex items-center gap-space-12">
                <Icon name="info" size={20} className="text-reviz-muted" />
                <span className="text-label-sm text-reviz-muted">
                  Montant: {payment.amount_fcfa.toLocaleString('fr-FR')} FCFA
                </span>
              </div>
            )}
          </div>
        </div>
      </Card>

      <Card size="sm">
        <span className="text-label-md text-reviz-muted">
          Conseils
        </span>
        <ul className="flex flex-col gap-space-8 text-label-sm text-reviz-ink">
          <li>• Vérifiez votre solde Mobile Money</li>
          <li>• Vérifiez que vous avez entré le bon numéro</li>
          <li>• Attendez quelques minutes et réessayez</li>
          <li>• Contactez le support si le problème persiste</li>
        </ul>
      </Card>

      {/* Actions */}
      <div className="flex flex-col gap-space-12">
        <Link href="/boutique" className="w-full">
          <Button icon="shopping_bag">
            Réessayer
          </Button>
        </Link>

        <Link href="/" className="w-full">
          <Button variant="secondary" icon="arrow_back">
            Retourner
          </Button>
        </Link>
      </div>
    </div>
  )
}
