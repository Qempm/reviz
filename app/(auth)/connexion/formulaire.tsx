'use client'

import { useEffect, useState, useTransition } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import { Button, Icon, OtpInput, TextField } from '@/components/ui'
import { fr, t } from '@/lib/i18n/fr'
import { connexionGoogle, envoyerCodeEmail, verifierCodeEmail } from '../actions'

/**
 * B1 — Connexion par Google ou par code reçu par email.
 *
 * Google d'abord : sur Android le compte est déjà là, c'est un seul geste.
 * L'email reste la porte pour qui n'a pas de compte Google.
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

  const [etape, setEtape] = useState<'choix' | 'code'>('choix')
  const [email, setEmail] = useState('')
  const [code, setCode] = useState('')
  const [erreur, setErreur] = useState<string | null>(params.get('erreur'))
  const [compteur, setCompteur] = useState(0)
  const [enCours, demarrer] = useTransition()

  useEffect(() => {
    if (compteur <= 0) return
    const id = setTimeout(() => setCompteur((c) => c - 1), 1000)
    return () => clearTimeout(id)
  }, [compteur])

  const emailValide = /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email.trim())

  function demanderCode() {
    setErreur(null)
    demarrer(async () => {
      const r = await envoyerCodeEmail({ email })
      if (!r.ok) {
        setErreur(r.error)
        return
      }
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
      const r = await verifierCodeEmail({ email, code })
      if (!r.ok) {
        setErreur(r.error)
        setCode('')
        return
      }
      router.replace(r.data.profilExistant ? (suite ?? '/') : '/inscription')
    })
  }

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-app flex-col px-screen-margin-mobile pb-space-32 pt-space-48">
      <div className="flex flex-1 flex-col gap-space-32">
        {etape === 'choix' ? (
          <>
            <header className="flex flex-col gap-space-8">
              <h1 className="text-headline-xl text-reviz-ink">
                {fr.connexion.titre}
              </h1>
              <p className="text-body-md text-reviz-muted">
                {fr.connexion.sousTitre}
              </p>
            </header>

            <div className="flex flex-col gap-space-20">
              <Button
                variant="secondary"
                onClick={() => demarrer(() => connexionGoogle(suite ?? undefined))}
                disabled={enCours}
              >
                <GoogleLogo />
                {fr.connexion.avecGoogle}
              </Button>

              <div className="flex items-center gap-space-12">
                <span className="h-px flex-1 bg-reviz-border" />
                <span className="text-label-sm text-reviz-muted">
                  {fr.connexion.ou}
                </span>
                <span className="h-px flex-1 bg-reviz-border" />
              </div>

              <TextField
                id="email"
                label={fr.connexion.labelEmail}
                type="email"
                inputMode="email"
                autoComplete="email"
                placeholder="prenom@exemple.com"
                hint={fr.connexion.aideEmail}
                error={erreur ?? undefined}
                value={email}
                onChange={(e) => {
                  setEmail(e.target.value)
                  setErreur(null)
                }}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' && emailValide) demanderCode()
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
                  setEtape('choix')
                  setCode('')
                  setErreur(null)
                }}
                className="flex min-h-[48px] w-fit items-center gap-space-4 text-label-md text-reviz-muted"
              >
                <Icon name="arrow_back" size={20} />
                {fr.connexion.changerEmail}
              </button>

              <h1 className="text-headline-xl text-reviz-ink">
                {fr.connexion.titreCode}
              </h1>
              <p className="text-body-md text-reviz-muted">
                {t(fr.connexion.sousTitreCode, email)}
              </p>
            </header>

            <div className="flex flex-col gap-space-16">
              <OtpInput
                value={code}
                onChange={(v) => {
                  setCode(v)
                  setErreur(null)
                }}
                // Six chiffres saisis ou collés : on valide sans attendre un
                // appui de plus.
                onComplete={soumettreCode}
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
        icon={etape === 'choix' ? 'mail' : 'check'}
        disabled={enCours || (etape === 'choix' ? !emailValide : code.length < 6)}
        onClick={etape === 'choix' ? demanderCode : soumettreCode}
      >
        {enCours
          ? fr.commun.chargement
          : etape === 'choix'
            ? fr.connexion.envoyerCode
            : fr.connexion.valider}
      </Button>
    </main>
  )
}

/** Logo Google officiel, en SVG : un glyphe Material ferait générique. */
function GoogleLogo() {
  return (
    <svg width="20" height="20" viewBox="0 0 48 48" aria-hidden="true">
      <path
        fill="#EA4335"
        d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"
      />
      <path
        fill="#4285F4"
        d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"
      />
      <path
        fill="#FBBC05"
        d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"
      />
      <path
        fill="#34A853"
        d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"
      />
    </svg>
  )
}
