import { redirect } from 'next/navigation'
import { Card, EmptyState, Icon } from '@/components/ui'
import { createClient } from '@/lib/supabase/server'
import { fr } from '@/lib/i18n/fr'
import { SEUIL_RETRAIT_FCFA } from '@/lib/payments/commission'

/** Écran 7 — Portefeuille et parrainage. */
export default async function Gains() {
  const supabase = await createClient()

  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) redirect('/connexion')

  const [{ data: solde }, { data: profil }, { data: filleuls }] = await Promise.all([
    supabase.rpc('wallet_balance'),
    supabase.from('profiles').select('referral_code').eq('id', user.id).maybeSingle(),
    supabase.from('referrals').select('referred_id, first_payment_at'),
  ])

  const montant = typeof solde === 'number' ? solde : 0
  const payants = (filleuls ?? []).filter((f) => f.first_payment_at !== null).length

  return (
    <div className="flex flex-col gap-space-20">
      <h1 className="text-headline-xl text-reviz-ink">{fr.gains.titre}</h1>

      <Card>
        <span className="text-label-md text-reviz-muted">{fr.gains.solde}</span>
        <span className="text-display-hero-mobile text-reviz-ink">
          {montant.toLocaleString('fr-FR')}{' '}
          <span className="text-headline-md text-reviz-muted">FCFA</span>
        </span>
        <span className="text-label-sm text-reviz-muted">
          {montant >= SEUIL_RETRAIT_FCFA
            ? fr.gains.retraitPossible
            : fr.gains.resteAvantRetrait(SEUIL_RETRAIT_FCFA - montant)}
        </span>
      </Card>

      <Card>
        <span className="text-label-md text-reviz-muted">{fr.gains.tonCode}</span>
        <div className="flex items-center gap-space-12">
          <span className="flex-1 rounded-xl bg-reviz-yellow-soft px-space-16 py-space-12 text-headline-lg tracking-widest text-reviz-ink">
            {profil?.referral_code ?? '—'}
          </span>
          <Icon name="content_copy" size={22} className="text-reviz-muted" />
        </div>
        <span className="text-label-sm text-reviz-muted">{fr.gains.aideCode}</span>
      </Card>

      {payants === 0 ? (
        <Card>
          <EmptyState
            icon="group_add"
            title={fr.gains.aucunFilleul}
            description={fr.gains.aucunFilleulDetail}
          />
        </Card>
      ) : (
        <Card size="sm">
          <span className="text-label-lg text-reviz-ink">
            {fr.gains.filleulsPayants(payants)}
          </span>
        </Card>
      )}
    </div>
  )
}
