'use client'

import { useEffect, useState, useTransition } from 'react'
import { useSearchParams } from 'next/navigation'
import { useRouter } from 'next/navigation'
import { Button, Card, Icon, MascotState, OtpInput, TextField } from '@/components/ui'
import { fr, t } from '@/lib/i18n/fr'
import { useCoquille } from '@/lib/coquille'
import { connexionGoogle, envoyerCodeEmail, verifierCodeEmail } from '../actions'

/**
 * B1 — Connexion par Google ou par lien reçu par email.
 *
 * Google d'abord : sur Android le compte est déjà là, c'est un seul geste.
 * L'email reste la porte pour qui n'a pas de compte Google.
 *
 * L'email envoie un lien **et** — si le gabarit Supabase porte `{{ .Token }}`
 * — un code à six chiffres. Le lien reste le chemin par défaut, le code est
 * derrière un interrupteur : montrer d'emblée six cases devant un mail qui
 * n'en contient pas serait une impasse.
 *
 * Le code n'est pas un raffinement : dans la coquille Android, un lien reçu
 * par mail s'ouvre dans le navigateur et la session s'y installe, pas dans
 * l'application. Les six chiffres se saisissent sur place, et c'est le seul
 * chemin qui aboutisse depuis l'APK.
 *
 * Séparé de page.tsx parce que useSearchParams force le rendu côté client :
 * sans frontière Suspense au-dessus, le prérendu de la route échoue.
 */

/** Délai avant de pouvoir redemander un lien. */
const DELAI_RENVOI_S = 45

export function FormulaireConnexion() {
  const params = useSearchParams()
  const suite = params.get('suite')

  const [etape, setEtape] = useState<'choix' | 'envoye'>('choix')
  const [email, setEmail] = useState('')
  const [code, setCode] = useState('')
  const [saisieCode, setSaisieCode] = useState(false)
  const [erreur, setErreur] = useState<string | null>(params.get('erreur'))
  const [compteur, setCompteur] = useState(0)
  const [enCours, demarrer] = useTransition()
  const router = useRouter()
  const coquille = useCoquille()

  useEffect(() => {
    if (compteur <= 0) return
    const id = setTimeout(() => setCompteur((c) => c - 1), 1000)
    return () => clearTimeout(id)
  }, [compteur])

  const emailValide = /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email.trim())

  function envoyerLien() {
    setErreur(null)
    demarrer(async () => {
      const r = await envoyerCodeEmail({ email })
      if (!r.ok) {
        setErreur(r.error)
        return
      }
      setEtape('envoye')
      setCompteur(DELAI_RENVOI_S)
    })
  }

  function validerCode(valeur: string) {
    setErreur(null)
    demarrer(async () => {
      const r = await verifierCodeEmail({ email, code: valeur })
      if (!r.ok) {
        setErreur(r.error)
        setCode('')
        return
      }

      // Un compte sans profil doit finir son inscription : le layout des
      // écrans connectés y renverrait de toute façon, autant y aller
      // directement.
      const destination = r.data.profilExistant ? (suite ?? '/') : '/inscription'
      router.replace(destination)
    })
  }

  if (etape === 'envoye') {
    return (
      <main className="mx-auto flex min-h-screen w-full max-w-app flex-col justify-between px-screen-margin-mobile pb-space-32 pt-space-48">
        <div className="flex flex-1 flex-col items-center justify-center gap-space-24">
          <MascotState
            mood="chargement"
            title={fr.connexion.lienEnvoye}
            description={t(fr.connexion.lienEnvoyeDetail, email)}
          />

          <Card size="sm">
            <div className="flex items-start gap-space-12">
              <Icon name="lightbulb" size={22} className="text-primary" />
              <p className="text-label-sm text-reviz-muted">
                {coquille ? fr.connexion.codeAstuce : fr.connexion.lienAstuce}
              </p>
            </div>
          </Card>

          {saisieCode || coquille ? (
            <div className="flex w-full flex-col gap-space-12">
              <OtpInput
                value={code}
                onChange={(v) => {
                  setCode(v)
                  setErreur(null)
                }}
                onComplete={validerCode}
                error={erreur !== null}
                disabled={enCours}
                name="code"
              />
              {erreur ? (
                <p className="text-center text-label-sm text-reviz-danger">
                  {erreur}
                </p>
              ) : null}
              <Button
                icon="login"
                disabled={enCours || code.length < 6}
                onClick={() => validerCode(code)}
              >
                {enCours ? fr.commun.chargement : fr.connexion.valider}
              </Button>
            </div>
          ) : (
            <button
              type="button"
              onClick={() => setSaisieCode(true)}
              className="min-h-[48px] text-label-md text-primary underline"
            >
              {fr.connexion.jaiUnCode}
            </button>
          )}
        </div>

        <div className="flex flex-col gap-space-12">
          <Button
            variant="secondary"
            icon="refresh"
            disabled={compteur > 0 || enCours}
            onClick={envoyerLien}
          >
            {compteur > 0
              ? t(fr.connexion.renvoyerDans, compteur)
              : coquille
                ? fr.connexion.renvoyer
                : fr.connexion.renvoyerLien}
          </Button>

          <button
            type="button"
            onClick={() => {
              setEtape('choix')
              setSaisieCode(false)
              setCode('')
              setErreur(null)
            }}
            className="min-h-[48px] text-label-md text-reviz-muted"
          >
            {fr.connexion.changerEmail}
          </button>
        </div>
      </main>
    )
  }

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-app flex-col px-screen-margin-mobile pb-space-32 pt-space-48">
      <div className="flex flex-1 flex-col gap-space-32">
        <header className="flex flex-col gap-space-8">
          <h1 className="text-headline-xl text-reviz-ink">{fr.connexion.titre}</h1>
          <p className="text-body-md text-reviz-muted">{fr.connexion.sousTitre}</p>
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
            <span className="text-label-sm text-reviz-muted">{fr.connexion.ou}</span>
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
              if (e.key === 'Enter' && emailValide) envoyerLien()
            }}
          />
        </div>
      </div>

      <Button
        icon="mail"
        disabled={enCours || !emailValide}
        onClick={envoyerLien}
      >
        {enCours
          ? fr.commun.chargement
          : coquille
            ? fr.connexion.recevoirCode
            : fr.connexion.envoyerLien}
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
