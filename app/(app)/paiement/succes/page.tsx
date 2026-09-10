import Link from 'next/link'
import { redirect } from 'next/navigation'
import { Button, Card, Icon } from '@/components/ui'
import { createClient } from '@/lib/supabase/server'
import { fr } from '@/lib/i18n/fr'
import { etatAcces } from '@/lib/payments/subscriptions'

/**
 * Écran 4b — Confirmation paiement réussi.
 *
 * Affiche la confirmation et les détails de l'accès activé.
 * Après quelques secondes, redirige vers la boutique ou le tableau de bord.
 */
export default async function PaiementSucces() {
  const supabase = await createClient()

  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) redirect('/connexion')

  // Récupère les abonnements actifs pour afficher l'état de l'accès
  const { data: lignes } = await supabase
    .from('subscriptions')
    .select('pack_code, starts_at, ends_at, corrections_left, packs(label, duration_days)')
    .order('ends_at', { ascending: false })

  const abonnements = (lignes ?? []).map((l) => ({
    packCode: l.pack_code,
    startsAt: new Date(l.starts_at),
    endsAt: new Date(l.ends_at),
    correctionsLeft: l.corrections_left,
    subjectsLimit: (l.packs as { duration_days: number | null } | null)?.duration_days ?? null,
  }))

  const acces = etatAcces(abonnements)
  const dernier = lignes?.[0]

  return (
    <div className="flex flex-col gap-space-20">
      <header className="flex flex-col gap-space-4">
        <h1 className="text-headline-xl text-reviz-ink">
          Accès activé!
        </h1>
        <p className="text-body-md text-reviz-muted">
          Votre pack est maintenant actif.
        </p>
      </header>

      {/* Affiche le pack activé */}
      {dernier && (
        <Card>
          <div className="flex items-center gap-space-12">
            <Icon
              name={
                dernier.pack_code === 'decouverte'
                  ? 'diamond'
                  : dernier.pack_code === 'controle'
                    ? 'school'
                    : 'checkmark'
              }
              size={32}
              filled
              className="text-primary"
            />
            <div className="flex-1 flex flex-col">
              <span className="text-headline-md text-reviz-ink">
                {(
                  dernier.packs as { label: string | null } | null
                )?.label ?? dernier.pack_code}
              </span>
              <span className="text-label-sm text-reviz-muted">
                Actif jusqu'au {new Date(dernier.ends_at).toLocaleDateString('fr-FR')}
              </span>
            </div>
          </div>
        </Card>
      )}

      {/* État de l'accès */}
      {acces.state === 'active' && (
        <Card size="sm">
          <div className="flex items-center gap-space-12">
            <Icon name="verified" size={24} filled className="text-primary" />
            <div className="flex-1">
              <span className="text-label-lg text-reviz-ink">
                Accès actif pour {acces.daysLeft} jours
              </span>
              {dernier && (
                <span className="text-label-sm text-reviz-muted">
                  {dernier.corrections_left ?? 0} corrections restantes
                </span>
              )}
            </div>
          </div>
        </Card>
      )}

      {/* Actions */}
      <div className="flex flex-col gap-space-12">
        <Link href="/" className="w-full">
          <Button icon="home" type="button">
            Aller au tableau de bord
          </Button>
        </Link>

        <Link href="/reviser" className="w-full">
          <Button variant="secondary" icon="school">
            Accéder aux cours
          </Button>
        </Link>
      </div>

      <p className="text-center text-label-sm text-reviz-muted">
        Redirection automatique...
      </p>

      {/* Script de redirection automatique */}
      <script dangerouslySetInnerHTML={{
        __html: `
          setTimeout(() => {
            window.location.href = '/';
          }, 4000);
        `,
      }} />
    </div>
  )
}
