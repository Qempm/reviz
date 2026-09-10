import Link from 'next/link'
import { redirect } from 'next/navigation'
import { Button, Card, Icon } from '@/components/ui'
import { createClient } from '@/lib/supabase/server'
import { fr } from '@/lib/i18n/fr'
import { deconnexion } from '../../(auth)/actions'

/** Écran 8 — Profil et réglages. */
export default async function Profil() {
  const supabase = await createClient()

  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) redirect('/connexion')

  const { data: profil } = await supabase
    .from('profiles')
    .select('first_name, phone, study_year, verification_status, universities(code, name), faculties(code, name)')
    .eq('id', user.id)
    .maybeSingle()

  const universite = profil?.universities as { code: string; name: string } | null
  const faculte = profil?.faculties as { code: string; name: string } | null

  const verifie = profil?.verification_status === 'verified'

  return (
    <div className="flex flex-col gap-space-20">
      <h1 className="text-headline-xl text-reviz-ink">{fr.profil.titre}</h1>

      <Card>
        <span className="text-headline-md text-reviz-ink">
          {profil?.first_name ?? '—'}
        </span>
        <Ligne icone="school" valeur={universite ? `${universite.code} • ${faculte?.code ?? ''}` : '—'} />
        <Ligne icone="calendar_month" valeur={profil?.study_year ? `Année ${profil.study_year}` : '—'} />
        <Ligne icone="mail" valeur={user.email ?? '—'} />
        <Ligne icone="chat" valeur={profil?.phone ?? fr.profil.sansTelephone} />
      </Card>

      <Card size="sm">
        <div className="flex items-center gap-space-12">
          <Icon
            name={verifie ? 'verified' : 'gpp_maybe'}
            size={24}
            filled
            className={verifie ? 'text-primary' : 'text-reviz-muted'}
          />
          <span className="flex flex-col">
            <span className="text-label-lg text-reviz-ink">
              {verifie ? fr.profil.verifie : fr.profil.nonVerifie}
            </span>
            <span className="text-label-sm text-reviz-muted">
              {verifie ? fr.profil.verifieDetail : fr.profil.nonVerifieDetail}
            </span>
          </span>
        </div>
      </Card>

      <Link href="/boutique">
        <Card size="sm">
          <div className="flex items-center justify-between gap-space-12">
            <span className="flex items-center gap-space-12">
              <Icon name="shopping_bag" size={22} className="text-primary" />
              <span className="text-label-lg text-reviz-ink">
                {fr.profil.voirLesPacks}
              </span>
            </span>
            <Icon name="chevron_right" size={22} className="text-reviz-muted" />
          </div>
        </Card>
      </Link>

      {/* Avatar */}
      <Link href="/profil/avatar">
        <Card size="sm">
          <div className="flex items-center justify-between gap-space-12">
            <span className="flex items-center gap-space-12">
              <Icon name="face" size={22} className="text-primary" />
              <span className="text-label-lg text-reviz-ink">
                Changer mon avatar
              </span>
            </span>
            <Icon name="chevron_right" size={22} className="text-reviz-muted" />
          </div>
        </Card>
      </Link>

      {/* Parametres */}
      <Link href="/profil/parametres">
        <Card size="sm">
          <div className="flex items-center justify-between gap-space-12">
            <span className="flex items-center gap-space-12">
              <Icon name="settings" size={22} className="text-primary" />
              <span className="text-label-lg text-reviz-ink">
                Parametres
              </span>
            </span>
            <Icon name="chevron_right" size={22} className="text-reviz-muted" />
          </div>
        </Card>
      </Link>

      {/* Aide */}
      <Link href="/profil/aide">
        <Card size="sm">
          <div className="flex items-center justify-between gap-space-12">
            <span className="flex items-center gap-space-12">
              <Icon name="help" size={22} className="text-primary" />
              <span className="text-label-lg text-reviz-ink">
                Centre d\'aide
              </span>
            </span>
            <Icon name="chevron_right" size={22} className="text-reviz-muted" />
          </div>
        </Card>
      </Link>

      <form action={deconnexion}>
        <Button variant="secondary" icon="logout" type="submit">
          {fr.profil.deconnexion}
        </Button>
      </form>
    </div>
  )
}

function Ligne({ icone, valeur }: { icone: string; valeur: string }) {
  return (
    <div className="flex items-center gap-space-12">
      <Icon name={icone} size={20} className="text-reviz-muted" />
      <span className="text-body-md text-reviz-ink">{valeur}</span>
    </div>
  )
}
