import { redirect } from 'next/navigation'
import { Button, Card, Icon } from '@/components/ui'
import { createClient } from '@/lib/supabase/server'
import { fr } from '@/lib/i18n/fr'
import { etatAcces, type Subscription } from '@/lib/payments/subscriptions'
import { cn } from '@/lib/utils'

/**
 * Écran 5 — Boutique des packs.
 *
 * Achat unique, à durée limitée, sans reconduction (règle métier 1). Le texte
 * le dit explicitement : c'est la promesse qui distingue Reviz d'un
 * abonnement, elle doit être lisible avant de payer, pas dans les conditions.
 */
export default async function Boutique() {
  const supabase = await createClient()

  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) redirect('/connexion')

  const [{ data: packs }, { data: lignes }] = await Promise.all([
    supabase
      .from('packs')
      .select('code, label, description, price_fcfa, duration_days, corrections_included, subjects_limit')
      .order('price_fcfa'),
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

  return (
    <div className="flex flex-col gap-space-20">
      <header className="flex flex-col gap-space-4">
        <h1 className="text-headline-xl text-reviz-ink">{fr.boutique.titre}</h1>
        <p className="text-body-md text-reviz-muted">{fr.boutique.sousTitre}</p>
      </header>

      {/* État de l'accès en cours ------------------------------------------ */}
      {acces.state === 'active' ? (
        <Card size="sm">
          <div className="flex items-center gap-space-12">
            <Icon name="verified" size={24} filled className="text-primary" />
            <span className="flex flex-col">
              <span className="text-label-lg text-reviz-ink">
                {fr.boutique.accesActif(acces.daysLeft)}
              </span>
              <span className="text-label-sm text-reviz-muted">
                {fr.boutique.correctionsRestantes(acces.correctionsLeft)}
              </span>
            </span>
          </div>
        </Card>
      ) : acces.state === 'expired' ? (
        <Card size="sm">
          <div className="flex items-center gap-space-12">
            <Icon name="lock_clock" size={24} filled className="text-secondary" />
            <span className="flex flex-col">
              <span className="text-label-lg text-reviz-ink">
                {fr.boutique.accesExpire}
              </span>
              <span className="text-label-sm text-reviz-muted">
                {fr.boutique.accesExpireDetail}
              </span>
            </span>
          </div>
        </Card>
      ) : null}

      {/* Packs -------------------------------------------------------------- */}
      <div className="flex flex-col gap-space-12">
        {(packs ?? []).map((p) => {
          const gratuit = p.price_fcfa === 0
          // Le semestre est le meilleur rapport durée/prix : on le désigne
          // plutôt que de laisser l'étudiant faire le calcul.
          const recommande = p.code === 'semestre'

          return (
            <Card key={p.code}>
              <div className="flex items-start justify-between gap-space-12">
                <span className="flex flex-col gap-space-2">
                  <span className="flex items-center gap-space-8">
                    <span className="text-headline-md text-reviz-ink">{p.label}</span>
                    {recommande ? (
                      <span className="rounded-full bg-reviz-yellow px-space-8 py-space-2 text-caption text-reviz-on-yellow">
                        {fr.boutique.recommande}
                      </span>
                    ) : null}
                  </span>
                  <span className="text-body-md text-reviz-muted">
                    {p.description}
                  </span>
                </span>

                <span className="shrink-0 text-right">
                  <span
                    className={cn(
                      'text-headline-lg',
                      gratuit ? 'text-primary' : 'text-reviz-ink',
                    )}
                  >
                    {gratuit
                      ? fr.boutique.gratuit
                      : p.price_fcfa.toLocaleString('fr-FR')}
                  </span>
                  {gratuit ? null : (
                    <span className="text-label-sm text-reviz-muted"> FCFA</span>
                  )}
                </span>
              </div>

              <div className="flex flex-col gap-space-8">
                <Detail
                  icone="schedule"
                  texte={fr.boutique.duree(p.duration_days)}
                />
                <Detail
                  icone="fact_check"
                  texte={fr.boutique.corrections(p.corrections_included)}
                />
                <Detail
                  icone="menu_book"
                  texte={fr.boutique.matieres(p.subjects_limit)}
                />
              </div>

              <Button icon="shopping_cart" disabled>
                {fr.boutique.choisir}
              </Button>
            </Card>
          )
        })}
      </div>

      <p className="pb-space-16 text-center text-label-sm text-reviz-muted">
        {fr.boutique.sansReconduction}
      </p>
    </div>
  )
}

function Detail({ icone, texte }: { icone: string; texte: string }) {
  return (
    <span className="flex items-center gap-space-8">
      <Icon name={icone} size={18} className="text-reviz-muted" />
      <span className="text-label-md text-reviz-ink">{texte}</span>
    </span>
  )
}
