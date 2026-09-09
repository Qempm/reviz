import { Suspense } from 'react'
import { FormulaireConnexion } from './formulaire'

/**
 * B1 — Connexion par numéro et code à usage unique.
 *
 * Le formulaire lit `?suite=` pour revenir à la page demandée après
 * connexion, ce qui l'oblige à rendre côté client. La frontière Suspense
 * ci-dessous permet à Next de prérendre la route malgré tout.
 */
export default function Connexion() {
  return (
    <Suspense fallback={<Squelette />}>
      <FormulaireConnexion />
    </Suspense>
  )
}

/** Même gabarit que le formulaire, pour éviter un saut à l'hydratation. */
function Squelette() {
  return (
    <main className="mx-auto flex min-h-screen w-full max-w-app flex-col gap-space-32 px-screen-margin-mobile pb-space-32 pt-space-48">
      <div className="h-8 w-2/3 animate-pulse rounded-xl bg-surface-container" />
      <div className="h-5 w-full animate-pulse rounded-xl bg-surface-container" />
      <div className="h-cta w-full animate-pulse rounded-xl bg-surface-container" />
    </main>
  )
}
