import 'server-only'
import { createAdminClient } from '@/lib/supabase/admin'
import { createClient } from '@/lib/supabase/server'
import { estAdmin, masquerTelephone, telechargementsGithub } from './regles'

/**
 * L'espace administrateur, côté serveur : qui est connecté, et les chiffres.
 *
 * Les chiffres viennent de deux fonctions SQL réservées au rôle de service
 * (`admin_tableau`, `admin_paiements`, migration `20261011130000`). Elles ne
 * sont appelées qu'ici, après `adminConnecte()`.
 */

export type EtatAdmin =
  | { statut: 'admin'; email: string }
  | { statut: 'refuse'; email: string }
  | { statut: 'deconnecte' }

export async function adminConnecte(): Promise<EtatAdmin> {
  const supabase = await createClient()
  const { data } = await supabase.auth.getUser()
  const email = data.user?.email
  if (!email) return { statut: 'deconnecte' }
  return estAdmin(email, process.env.ADMIN_EMAILS) ? { statut: 'admin', email } : { statut: 'refuse', email }
}

export interface Tableau {
  comptes: number
  verifies: number
  enAttenteDeVerification: number
  nouveaux: { jour: number; semaine: number; mois: number }
  actifs: { jour: number; semaine: number; mois: number }
  appareils: Record<string, number>
  cours: number
  coursPrets: number
  corrections: number
  tuteur: number
  packsActifs: Record<string, number>
  encaisse: { jour: number; semaine: number; mois: number; total: number }
  paiements: { reussis: number; enAttente: number; echoues: number }
  coutIa30j: number
  telechargementsSite: { total: number; semaine: number }
}

export async function lireTableau(): Promise<Tableau | null> {
  const { data, error } = await createAdminClient().rpc('admin_tableau')
  if (error) {
    console.error('[admin] tableau illisible', error.message)
    return null
  }
  return data as unknown as Tableau
}

export interface PaiementAdmin {
  id: string
  le: string
  prenom: string | null
  pack: string | null
  montant: number
  operateur: string | null
  statut: 'success' | 'pending' | 'failed' | string
  telephone: string
}

/** Les derniers paiements, numéros masqués avant de quitter le serveur. */
export async function lirePaiements(limite = 50): Promise<PaiementAdmin[]> {
  const { data, error } = await createAdminClient().rpc('admin_paiements', { limite })
  if (error) {
    console.error('[admin] paiements illisibles', error.message)
    return []
  }
  return (data ?? []).map((p) => ({
    id: p.id,
    le: p.cree_le,
    prenom: p.prenom,
    pack: p.pack,
    montant: p.montant,
    operateur: p.operateur,
    statut: p.statut,
    telephone: masquerTelephone(p.telephone),
  }))
}

/** Les téléchargements de l'APK selon GitHub, relus toutes les 10 minutes. */
export async function lireTelechargementsGithub() {
  try {
    const res = await fetch('https://api.github.com/repos/Qempm/reviz/releases?per_page=100', {
      // GitHub refuse une requête sans User-Agent.
      headers: { accept: 'application/vnd.github+json', 'user-agent': 'reviz-admin' },
      next: { revalidate: 600 },
    })
    if (!res.ok) {
      console.error('[admin] GitHub a répondu', res.status)
      return telechargementsGithub(null)
    }
    return telechargementsGithub(await res.json())
  } catch (e) {
    console.error('[admin] GitHub injoignable', e instanceof Error ? e.message : e)
    return telechargementsGithub(null)
  }
}
