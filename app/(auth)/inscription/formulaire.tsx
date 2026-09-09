'use client'

import { useMemo, useState, useTransition } from 'react'
import { useRouter } from 'next/navigation'
import { Button, Card, Icon, TextField } from '@/components/ui'
import { formaterNational, PAYS, PAYS_PAR_DEFAUT, type Pays } from '@/lib/auth/phone'
import { fr } from '@/lib/i18n/fr'
import { cn } from '@/lib/utils'
import { creerProfil } from './actions'

export type Universite = {
  id: string
  code: string
  name: string
  city: string | null
}

export type Faculte = {
  id: string
  university_id: string
  code: string
  name: string
}

/**
 * B2 — Création du profil.
 *
 * Tout tient sur un seul écran défilant plutôt qu'en assistant à étapes :
 * l'étudiant vient de se connecter, chaque écran de plus est une occasion
 * d'abandonner. Seul le téléphone est replié, puisqu'il est facultatif.
 */
export function FormulaireInscription({
  universites,
  facultes,
}: {
  universites: Universite[]
  facultes: Faculte[]
}) {
  const router = useRouter()
  const [enCours, demarrer] = useTransition()

  const [prenom, setPrenom] = useState('')
  const [universiteId, setUniversiteId] = useState('')
  const [faculteId, setFaculteId] = useState('')
  const [annee, setAnnee] = useState<number | null>(null)
  const [codeParrain, setCodeParrain] = useState('')
  const [pays, setPays] = useState<Pays>(PAYS_PAR_DEFAUT)
  const [telephone, setTelephone] = useState('')
  const [telephoneOuvert, setTelephoneOuvert] = useState(false)
  const [erreur, setErreur] = useState<string | null>(null)
  const [champEnErreur, setChampEnErreur] = useState<string | null>(null)

  const facultesDeLUniversite = useMemo(
    () => facultes.filter((f) => f.university_id === universiteId),
    [facultes, universiteId],
  )

  const complet =
    prenom.trim().length >= 2 && universiteId && faculteId && annee !== null

  function envoyer() {
    setErreur(null)
    setChampEnErreur(null)

    demarrer(async () => {
      const r = await creerProfil({
        prenom,
        universiteId,
        faculteId,
        annee: annee!,
        telephone: telephone || undefined,
        pays: pays.code,
        codeParrain: codeParrain || undefined,
      })

      if (!r.ok) {
        setErreur(r.error)
        setChampEnErreur(r.champ ?? null)
        return
      }
      router.replace('/')
    })
  }

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-app flex-col gap-space-24 px-screen-margin-mobile pb-space-32 pt-space-48">
      <header className="flex flex-col gap-space-8">
        <h1 className="text-headline-xl text-reviz-ink">{fr.inscription.titre}</h1>
        <p className="text-body-md text-reviz-muted">{fr.inscription.sousTitre}</p>
      </header>

      <TextField
        id="prenom"
        label={fr.inscription.labelPrenom}
        autoComplete="given-name"
        autoFocus
        placeholder="Moussa"
        value={prenom}
        error={champEnErreur === 'prenom' ? (erreur ?? undefined) : undefined}
        onChange={(e) => setPrenom(e.target.value)}
      />

      {/* Université ------------------------------------------------------- */}
      <fieldset className="flex flex-col gap-space-8">
        <legend className="pb-space-8 text-label-md text-reviz-ink">
          {fr.inscription.labelUniversite}
        </legend>
        <div className="flex flex-col gap-space-8">
          {universites.map((u) => (
            <Choix
              key={u.id}
              actif={u.id === universiteId}
              onClick={() => {
                setUniversiteId(u.id)
                setFaculteId('')
              }}
              titre={u.code}
              detail={u.city ? `${u.name} • ${u.city}` : u.name}
            />
          ))}
        </div>
      </fieldset>

      {/* Filière ---------------------------------------------------------- */}
      {universiteId ? (
        <fieldset className="flex flex-col gap-space-8">
          <legend className="pb-space-8 text-label-md text-reviz-ink">
            {fr.inscription.labelFiliere}
          </legend>
          <div className="flex flex-col gap-space-8">
            {facultesDeLUniversite.map((f) => (
              <Choix
                key={f.id}
                actif={f.id === faculteId}
                onClick={() => setFaculteId(f.id)}
                titre={f.code}
                detail={f.name}
              />
            ))}
          </div>
        </fieldset>
      ) : null}

      {/* Année ------------------------------------------------------------ */}
      {faculteId ? (
        <fieldset className="flex flex-col gap-space-8">
          <legend className="pb-space-8 text-label-md text-reviz-ink">
            {fr.inscription.labelAnnee}
          </legend>
          <div className="flex flex-wrap gap-space-8">
            {[1, 2, 3, 4, 5, 6, 7].map((a) => (
              <button
                key={a}
                type="button"
                onClick={() => setAnnee(a)}
                aria-pressed={a === annee}
                className={cn(
                  'flex h-12 min-w-[56px] items-center justify-center rounded-full px-space-16 text-label-lg transition-all',
                  a === annee
                    ? 'bg-reviz-yellow text-reviz-on-yellow shadow-tactile-sm'
                    : 'border-2 border-reviz-border bg-reviz-card text-reviz-muted',
                )}
              >
                {fr.inscription.annee(a)}
              </button>
            ))}
          </div>
        </fieldset>
      ) : null}

      {/* Code parrain ----------------------------------------------------- */}
      <TextField
        id="parrain"
        label={fr.inscription.labelParrain}
        hint={fr.inscription.aideParrain}
        placeholder="ABC123"
        maxLength={12}
        autoCapitalize="characters"
        value={codeParrain}
        error={champEnErreur === 'codeParrain' ? (erreur ?? undefined) : undefined}
        onChange={(e) => setCodeParrain(e.target.value.toUpperCase())}
      />

      {/* Téléphone, replié car facultatif --------------------------------- */}
      <Card size="sm">
        {telephoneOuvert ? (
          <div className="flex flex-col gap-space-12">
            <div className="flex flex-wrap gap-space-8">
              {PAYS.map((p) => (
                <button
                  key={p.code}
                  type="button"
                  onClick={() => setPays(p)}
                  aria-pressed={p.code === pays.code}
                  className={cn(
                    'flex min-h-[48px] items-center gap-space-4 rounded-full px-space-12 text-label-sm transition-all',
                    p.code === pays.code
                      ? 'bg-reviz-yellow text-reviz-on-yellow shadow-tactile-sm'
                      : 'border-2 border-reviz-border bg-reviz-card text-reviz-muted',
                  )}
                >
                  <span aria-hidden="true">{p.emoji}</span>
                  {p.nom}
                </button>
              ))}
            </div>

            <TextField
              id="telephone"
              label={fr.telephone.label}
              type="tel"
              inputMode="tel"
              autoComplete="tel"
              prefix={`+${pays.indicatif}`}
              placeholder={pays.exemple}
              hint={fr.telephone.aide}
              value={formaterNational(telephone, pays)}
              error={champEnErreur === 'telephone' ? (erreur ?? undefined) : undefined}
              onChange={(e) => setTelephone(e.target.value)}
            />
          </div>
        ) : (
          <button
            type="button"
            onClick={() => setTelephoneOuvert(true)}
            className="flex min-h-[48px] items-center gap-space-12 text-left"
          >
            <Icon name="add_circle" size={22} className="text-primary" />
            <span className="flex flex-col">
              <span className="text-label-lg text-reviz-ink">
                {fr.telephone.label}
              </span>
              <span className="text-label-sm text-reviz-muted">
                {fr.telephone.aide}
              </span>
            </span>
          </button>
        )}
      </Card>

      {erreur && !champEnErreur ? (
        <span role="alert" className="text-label-sm text-reviz-danger">
          {erreur}
        </span>
      ) : null}

      <Button icon="check" disabled={!complet || enCours} onClick={envoyer}>
        {enCours ? fr.commun.chargement : fr.inscription.terminer}
      </Button>
    </main>
  )
}

/** Ligne de choix : un titre court et un libellé complet. */
function Choix({
  actif,
  onClick,
  titre,
  detail,
}: {
  actif: boolean
  onClick: () => void
  titre: string
  detail: string
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-pressed={actif}
      className={cn(
        'flex min-h-[56px] items-center justify-between gap-space-12 rounded-xl px-space-16 py-space-12 text-left transition-all',
        actif
          ? 'bg-reviz-yellow-soft shadow-tactile'
          : 'border-2 border-reviz-border bg-reviz-card',
      )}
    >
      <span className="flex flex-col">
        <span className="text-label-lg text-reviz-ink">{titre}</span>
        <span className="text-label-sm text-reviz-muted">{detail}</span>
      </span>
      {actif ? (
        <Icon name="check_circle" size={22} filled className="text-primary" />
      ) : null}
    </button>
  )
}
