'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClientNavigateur } from '@/lib/supabase/navigateur'

/**
 * Connexion à l'administration : l'e-mail, puis le code à 6 chiffres reçu
 * par e-mail — comme dans l'application.
 *
 * `shouldCreateUser: false` : cette page ne crée jamais de compte. L'adresse
 * doit être celle d'un compte Reviz existant, et figurer dans ADMIN_EMAILS
 * pour que la page suivante s'ouvre.
 */
export default function ConnexionAdmin() {
  const router = useRouter()
  const [email, setEmail] = useState('')
  const [code, setCode] = useState('')
  const [etape, setEtape] = useState<'email' | 'code'>('email')
  const [envoi, setEnvoi] = useState(false)
  const [erreur, setErreur] = useState<string | null>(null)

  async function demanderCode(e: React.FormEvent) {
    e.preventDefault()
    setEnvoi(true)
    setErreur(null)
    const { error } = await createClientNavigateur().auth.signInWithOtp({
      email: email.trim(),
      options: { shouldCreateUser: false },
    })
    setEnvoi(false)
    if (error) setErreur('Impossible d’envoyer le code à cette adresse.')
    else setEtape('code')
  }

  async function verifier(e: React.FormEvent) {
    e.preventDefault()
    setEnvoi(true)
    setErreur(null)
    const { error } = await createClientNavigateur().auth.verifyOtp({
      email: email.trim(),
      token: code.trim(),
      type: 'email',
    })
    setEnvoi(false)
    if (error) {
      setErreur('Code incorrect ou expiré.')
      return
    }
    router.replace('/admin')
    router.refresh()
  }

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-[420px] flex-col justify-center gap-6 px-4 py-10">
      <div>
        <p className="text-sm font-semibold uppercase tracking-[0.12em] text-reviz-orange-deep">Reviz</p>
        <h1 className="mt-2 font-titre text-4xl">Administration</h1>
        <p className="mt-2 text-reviz-muted">
          {etape === 'email'
            ? 'Entre l’adresse de ton compte Reviz. Tu recevras un code.'
            : `Code envoyé à ${email}. Il arrive en moins d’une minute.`}
        </p>
      </div>

      <form
        onSubmit={etape === 'email' ? demanderCode : verifier}
        className="flex flex-col gap-4 rounded-card bg-reviz-card p-6 shadow-card"
      >
        {etape === 'email' ? (
          <label className="flex flex-col gap-2 text-sm font-semibold">
            Adresse e-mail
            <input
              id="email"
              type="email"
              required
              autoComplete="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="rounded-2xl border border-[#E5D3A6] bg-reviz-surface-low px-4 py-3 text-base font-normal outline-none focus:border-reviz-ink"
            />
          </label>
        ) : (
          <label className="flex flex-col gap-2 text-sm font-semibold">
            Code à 6 chiffres
            <input
              id="code"
              inputMode="numeric"
              autoComplete="one-time-code"
              required
              pattern="[0-9]{6}"
              maxLength={6}
              value={code}
              onChange={(e) => setCode(e.target.value.replace(/\D/g, ''))}
              className="rounded-2xl border border-[#E5D3A6] bg-reviz-surface-low px-4 py-3 text-center font-titre text-2xl tracking-[0.4em] outline-none focus:border-reviz-ink"
            />
          </label>
        )}

        {erreur && <p className="text-sm font-semibold text-reviz-danger">{erreur}</p>}

        <button
          type="submit"
          disabled={envoi}
          className="h-[54px] rounded-[20px] bg-reviz-yellow font-semibold text-reviz-ink shadow-[0_8px_20px_rgba(255,196,0,0.35)] transition active:scale-[0.98] disabled:opacity-60 focus-visible:outline focus-visible:outline-2 focus-visible:outline-reviz-ink"
        >
          {envoi ? '…' : etape === 'email' ? 'Recevoir le code' : 'Se connecter'}
        </button>

        {etape === 'code' && (
          <button
            type="button"
            onClick={() => {
              setEtape('email')
              setCode('')
            }}
            className="text-sm font-semibold text-reviz-muted underline underline-offset-4"
          >
            Changer d’adresse
          </button>
        )}
      </form>
    </main>
  )
}
