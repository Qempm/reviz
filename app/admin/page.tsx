import { redirect } from 'next/navigation'
import {
  adminConnecte,
  lirePaiements,
  lireTableau,
  lireTelechargementsGithub,
} from '@/lib/admin/serveur'
import { Deconnexion } from './Deconnexion'
import { TableauDirect } from './TableauDirect'

/**
 * L'espace administrateur : téléchargements, comptes, activité, et les
 * paiements en direct. Réservé aux adresses de ADMIN_EMAILS.
 */
export const dynamic = 'force-dynamic'

export default async function Admin() {
  const admin = await adminConnecte()
  if (admin.statut === 'deconnecte') redirect('/admin/connexion')

  if (admin.statut === 'refuse') {
    return (
      <main className="mx-auto flex min-h-screen w-full max-w-[420px] flex-col justify-center gap-4 px-4 py-10">
        <h1 className="font-titre text-3xl">Accès réservé</h1>
        <p className="text-reviz-muted">
          Le compte {admin.email} n’a pas accès à l’administration.
        </p>
        <Deconnexion />
      </main>
    )
  }

  const [tableau, paiements, github] = await Promise.all([
    lireTableau(),
    lirePaiements(50),
    lireTelechargementsGithub(),
  ])

  return (
    <main className="mx-auto flex w-full max-w-[1100px] flex-col gap-6 px-4 pb-16 pt-8">
      <header className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <p className="text-sm font-semibold uppercase tracking-[0.12em] text-reviz-orange-deep">Reviz</p>
          <h1 className="font-titre text-4xl">Administration</h1>
        </div>
        <div className="flex min-w-0 items-center gap-3 text-sm text-reviz-muted">
          <span className="truncate">{admin.email}</span>
          <Deconnexion />
        </div>
      </header>
      <TableauDirect tableauInitial={tableau} paiementsInitiaux={paiements} github={github} />
    </main>
  )
}
