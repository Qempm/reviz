import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '@/lib/supabase/database.types'
import { estSorte, lienDe, pushAutorise, textePush } from '@/lib/metier/notifications'
import { envoyerFcm, type Fetch, lireCompteService, type CompteService } from './fcm'
import { abonnementDe, envoyerWebPush, type Expediteur, lireVapid, type Vapid } from './webpush'

type Admin = SupabaseClient<Database>

export interface Bilan {
  reservees: number
  envoyes: number
  jetonsSupprimes: number
}

/**
 * Pousse les notifications qui ne sont pas encore parties.
 *
 * Appelée **après la réponse** (`after()` de Next.js) par les routes qui
 * produisent des événements — fin de traitement, paiement, fin de série —
 * et par le cron, en rattrapage : une ligne écrite par un déclencheur SQL
 * sans route derrière (un retrait passé à la main, la clôture des ligues)
 * part au plus tard le soir.
 *
 * Les lignes sont réservées avant l'envoi (`reserver_notifications_a_pousser`)
 * : deux passes simultanées ne poussent jamais la même. Une préférence
 * coupée, un étudiant sans téléphone enregistré : la ligne est réservée et
 * rien ne part — le centre de notifications la montre quand même.
 */
export async function envoyerEnAttente(
  admin: Admin,
  options: {
    userId?: string
    compte?: CompteService | null
    f?: Fetch
    vapid?: Vapid | null
    expediteur?: Expediteur
  } = {},
): Promise<Bilan> {
  const bilan: Bilan = { reservees: 0, envoyes: 0, jetonsSupprimes: 0 }

  // Deux canaux : Firebase pour les applications (Android, iPhone natif), le
  // Web Push pour l'app web installée (iPhone sans compte Apple). Sans aucun
  // des deux, on ne réserve rien : les lignes restent à pousser, et
  // partiront si la configuration arrive dans les vingt-quatre heures.
  const compte = options.compte === undefined ? lireCompteService() : options.compte
  const vapid = options.vapid === undefined ? lireVapid() : options.vapid
  if (!compte && !vapid) return bilan

  const { data: lignes, error } = await admin.rpc('reserver_notifications_a_pousser', {
    p_limite: 200,
    ...(options.userId ? { p_user: options.userId } : {}),
  })
  if (error || !lignes || lignes.length === 0) return bilan
  bilan.reservees = lignes.length

  const utilisateurs = [...new Set(lignes.map((l) => l.user_id))]
  const [{ data: profils }, { data: appareils }] = await Promise.all([
    admin.from('profiles').select('id, notifications').in('id', utilisateurs),
    admin.from('appareils').select('token, user_id, plateforme, abonnement').in('user_id', utilisateurs),
  ])

  type Appareil = { token: string; plateforme?: string; abonnement?: unknown }
  const prefs = new Map((profils ?? []).map((p) => [p.id, p.notifications]))
  const jetons = new Map<string, Appareil[]>()
  for (const a of (appareils ?? []) as Array<Appareil & { user_id: string }>) {
    jetons.set(a.user_id, [...(jetons.get(a.user_id) ?? []), a])
  }

  const morts = new Set<string>()
  for (const l of lignes) {
    if (!estSorte(l.kind) || !pushAutorise(prefs.get(l.user_id), l.kind)) continue
    const data = (l.data && typeof l.data === 'object' && !Array.isArray(l.data) ? l.data : {}) as Record<
      string,
      unknown
    >
    const { titre, corps } = textePush(l.kind, data)
    const lien = lienDe(l.kind, l.reference_id)

    for (const appareil of jetons.get(l.user_id) ?? []) {
      const { token } = appareil
      if (morts.has(token)) continue
      let issue: Awaited<ReturnType<typeof envoyerFcm>> | null = null
      if (appareil.plateforme === 'web') {
        const abonnement = abonnementDe(token, appareil.abonnement)
        if (!vapid || !abonnement) continue
        issue = await envoyerWebPush(vapid, abonnement, { titre, corps, lien, id: l.id }, options.expediteur)
      } else {
        if (!compte) continue
        issue = await envoyerFcm(compte, { token, titre, corps, lien, id: l.id }, options.f)
      }
      if (issue === 'envoye') bilan.envoyes++
      if (issue === 'jeton-invalide') morts.add(token)
    }
  }

  if (morts.size > 0) {
    await admin.from('appareils').delete().in('token', [...morts])
    bilan.jetonsSupprimes = morts.size
  }
  return bilan
}

/**
 * Le même envoi, sans jamais lever : appelé dans `after()`, une panne de
 * push ne doit ni casser la route ni polluer ses journaux d'une erreur non
 * gérée.
 */
export async function pousserNotifications(options: { userId?: string } = {}): Promise<void> {
  try {
    if (!lireCompteService() && !lireVapid()) return
    const { createAdminClient } = await import('@/lib/supabase/admin')
    const bilan = await envoyerEnAttente(createAdminClient(), options)
    if (bilan.reservees > 0) {
      console.info('[notifications] push', bilan)
    }
  } catch (e) {
    console.error('[notifications] push impossible', e instanceof Error ? e.message : e)
  }
}
