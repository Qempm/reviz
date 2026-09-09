'use client'

import { useEffect, useState, useTransition } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import { Button, Icon, OtpInput, TextField } from '@/components/ui'
import {
  formaterNational,
  masquerTelephone,
  normaliserTelephone,
  PAYS,
  PAYS_PAR_DEFAUT,
  type Pays,
} from '@/lib/auth/phone'
import { fr, t } from '@/lib/i18n/fr'
import { envoyerCode, verifierCode } from '../actions'

/**
 * B1 — Saisie du numéro puis du code reçu.
 *
 * Deux étapes dans un seul écran : revenir en arrière doit être immédiat,
 * un étudiant qui s'est trompé de chiffre ne doit pas perdre sa saisie.
 *
 * Séparé de page.tsx parce que useSearchParams force le rendu côté client :
 * sans frontière Suspense au-dessus, le prérendu de la route échoue.
 */

/** Délai avant de pouvoir redemander un code. */
const DELAI_RENVOI_S = 45

export function FormulaireConnexion() {
  const router = useRouter()
  const params = useSearchParams()
  const suite = params.get('suite')

  const [etape, setEtape] = useState<'telephone' | 'code'>('telephone')
  const [pays, setPays] = useState<Pays>(PAYS_PAR_DEFAUT)
  const [saisie, setSaisie] = useState('')
  const [e164, setE164] = useState('')
  const [code, setCode] = useState('')
  const [erreur, setErreur] = useState<string | null>(null)
  const [compteur, setCompteur] = useState(0)
  const [enCours, demarrer] = useTransition()

  // Compte à rebours avant de pouvoir redemander un code.
  useEffect(() => {
    if (compteur <= 0) return
    const id = setTimeout(() => setCompteur((c) => c - 1), 1000)
    return () => clearTimeout(id)
  }, [compteur])

  const numeroValide = normaliserTelephone(saisie, pays).ok

  function demanderCode() {
    setErreur(null)
    demarrer(async () => {
      const r = await envoyerCode({ telephone: saisie, pays: pays.code })
      if (!r.ok) {
        setErreur(r.error)
        return
      }
      setE164(r.data.telephone)
      setEtape('code')
      setCompteur(DELAI_RENVOI_S)
    })
  }

  function soumettreCode() {
    if (code.length < 6) {
      setErreur(fr.connexion.erreurs.codeIncomplet)
      return
    }
    setErreur(null)
    demarrer(async () => {
      const r = await verifierCode({ telephone: e164, code })
      if (!r.ok) {
        setErreur(r.error)
        setCode('')
        return
      }
      // Première connexion : on part construire le profil. Sinon, on reprend
      // là où l'étudiant voulait aller.
      router.replace(r.data.profilExistant ? (suite ?? '/') : '/inscription')
    })
  }

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-app flex-col px-screen-margin-mobile pb-space-32 pt-space-48">
      <div className="flex flex-1 flex-col gap-space-32">
        {etape === 'telephone' ? (
          <>
            <header className="flex flex-col gap-space-8">
              <h1 className="text-headline-xl text-reviz-ink">
                {fr.connexion.titreTelephone}
              </h1>
              <p className="text-body-md text-reviz-muted">
                {fr.connexion.sousTitreTelephone}
              </p>
            </header>

            <div className="flex flex-col gap-space-16">
              <div className="flex flex-col gap-space-8">
                <span className="text-label-md text-reviz-ink">
                  {fr.connexion.pays}
                </span>
                <div className="flex flex-wrap gap-space-8">
                  {PAYS.map((p) => (
                    <button
                      key={p.code}
                      type="button"
                      onClick={() => {
                        setPays(p)
                        setErreur(null)
                      }}
                      aria-pressed={p.code === pays.code}
                      className={
                        'flex min-h-[48px] items-center gap-space-4 rounded-full px-space-12 text-label-sm transition-all ' +
                        (p.code === pays.code
                          ? 'bg-reviz-yellow text-reviz-on-yellow shadow-tactile-sm'
                          : 'bg-reviz-card text-reviz-muted border-2 border-reviz-border')
                      }
                    >
                      <span aria-hidden="true">{p.emoji}</span>
                      {p.nom}
                    </button>
                  ))}
                </div>
              </div>

              <TextField
                id="telephone"
                label={fr.connexion.labelTelephone}
                type="tel"
                inputMode="tel"
                autoComplete="tel"
                autoFocus
                prefix={`+${pays.indicatif}`}
                placeholder={pays.exemple}
                hint={`Exemple : ${pays.exemple}`}
                error={erreur ?? undefined}
                value={formaterNational(saisie, pays)}
                onChange={(e) => {
                  setSaisie(e.target.value)
                  setErreur(null)
                }}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' && numeroValide) demanderCode()
                }}
              />
            </div>
          </>
        ) : (
          <>
            <header className="flex flex-col gap-space-8">
              <button
                type="button"
                onClick={() => {
                  setEtape('telephone')
                  setCode('')
                  setErreur(null)
                }}
                className="flex min-h-[48px] w-fit items-center gap-space-4 text-label-md text-reviz-muted"
              >
                <Icon name="arrow_back" size={20} />
                {fr.connexion.changerNumero}
              </button>

              <h1 className="text-headline-xl text-reviz-ink">
                {fr.connexion.titreCode}
              </h1>
              <p className="text-body-md text-reviz-muted">
                {t(fr.connexion.sousTitreCode, masquerTelephone(e164))}
              </p>
            </header>

            <div className="flex flex-col gap-space-16">
              <OtpInput
                value={code}
                onChange={(v) => {
                  setCode(v)
                  setErreur(null)
                }}
                error={Boolean(erreur)}
                disabled={enCours}
              />

              {erreur ? (
                <span role="alert" className="text-label-sm text-reviz-danger">
                  {erreur}
                </span>
              ) : null}

              <button
                type="button"
                disabled={compteur > 0 || enCours}
                onClick={demanderCode}
                className="min-h-[48px] text-label-md text-primary disabled:text-reviz-muted"
              >
                {compteur > 0
                  ? t(fr.connexion.renvoyerDans, compteur)
                  : fr.connexion.renvoyer}
              </button>
            </div>
          </>
        )}
      </div>

      <Button
        icon={etape === 'telephone' ? 'sms' : 'check'}
        disabled={
          enCours || (etape === 'telephone' ? !numeroValide : code.length < 6)
        }
        onClick={etape === 'telephone' ? demanderCode : soumettreCode}
      >
        {enCours
          ? fr.commun.chargement
          : etape === 'telephone'
            ? fr.connexion.envoyerCode
            : fr.connexion.valider}
      </Button>
    </main>
  )
}
