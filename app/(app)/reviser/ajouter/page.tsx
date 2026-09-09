import Link from 'next/link'
import { redirect } from 'next/navigation'
import { Button, Card, EmptyState, Icon } from '@/components/ui'
import { DepotCours, type MatiereChoix } from '@/components/reviz/depot-cours'
import { createClient } from '@/lib/supabase/server'
import { fr } from '@/lib/i18n/fr'
import { etatAcces, type Subscription } from '@/lib/payments/subscriptions'

/**
 * Écran D1 — dépôt d'un cours.
 *
 * Le refus d'accès est rendu ici, avant le formulaire : faire remplir un
 * formulaire pour le refuser à l'envoi serait une perte de temps et de
 * données. La vérification est refaite côté serveur à l'envoi, car un écran
 * ne protège rien.
 */
export default async function AjouterCours() {
  const supabase = await createClient()

  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) redirect('/connexion')

  const [{ data: profil }, { data: lignes }] = await Promise.all([
    supabase.from('profiles').select('faculty_id').eq('id', user.id).maybeSingle(),
    supabase
      .from('subscriptions')
      .select('pack_code, starts_at, ends_at, corrections_left, packs(subjects_limit)'),
  ])

  const abonnements: Subscription[] = (lignes ?? []).map((l) => ({
    packCode: l.pack_code,
    startsAt: new Date(l.starts_at),
    endsAt: new Date(l.ends_at),
    correctionsLeft: l.corrections_left,
    subjectsLimit:
      (l.packs as { subjects_limit: number | null } | null)?.subjects_limit ?? null,
  }))

  const acces = etatAcces(abonnements)

  const { data: matieresBrutes } = profil?.faculty_id
    ? await supabase
        .from('subjects')
        .select('id, name')
        .eq('faculty_id', profil.faculty_id)
        .order('name')
    : { data: [] }

  const matieres: MatiereChoix[] = (matieresBrutes ?? []).map((m) => ({
    id: m.id,
    nom: m.name,
  }))

  return (
    <div className="flex flex-col gap-space-20">
      <div className="flex flex-col gap-space-4">
        <Link
          href="/reviser"
          className="flex min-h-[48px] w-fit items-center gap-space-4 text-label-md text-reviz-muted"
        >
          <Icon name="arrow_back" size={20} />
          {fr.reviser.titre}
        </Link>
        <h1 className="text-headline-xl text-reviz-ink">{fr.depot.titre}</h1>
        <p className="text-body-md text-reviz-muted">{fr.depot.sousTitre}</p>
      </div>

      {acces.state !== 'active' ? (
        <Card>
          <EmptyState
            icon={acces.state === 'expired' ? 'lock_clock' : 'card_giftcard'}
            title={
              acces.state === 'expired' ? fr.depot.accesExpire : fr.depot.aucunAcces
            }
            description={
              acces.state === 'expired'
                ? fr.depot.accesExpireDetail
                : fr.depot.aucunAccesDetail
            }
            action={
              <Link href="/boutique">
                <Button icon="shopping_bag">{fr.depot.voirLesPacks}</Button>
              </Link>
            }
          />
        </Card>
      ) : matieres.length === 0 ? (
        <Card>
          <EmptyState
            icon="school"
            title={fr.depot.erreurs.matiereManquante}
            description={fr.inscription.sousTitre}
            action={
              <Link href="/profil">
                <Button variant="secondary" icon="person">
                  {fr.profil.titre}
                </Button>
              </Link>
            }
          />
        </Card>
      ) : (
        <DepotCours matieres={matieres} />
      )}
    </div>
  )
}
