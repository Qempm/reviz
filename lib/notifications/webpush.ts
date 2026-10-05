import webpush from 'web-push'
import type { IssueEnvoi } from './fcm'

/**
 * Envoi par Web Push standard (VAPID) : les notifications de l'app web
 * installée — sur iPhone, depuis iOS 16.4, c'est la seule voie sans compte
 * développeur Apple (arbitrage du 5 octobre 2026). Ni Firebase ni Apple à
 * configurer : le navigateur donne un abonnement (une adresse d'envoi chez
 * Apple, Google ou Mozilla, et deux clés), on lui envoie un message chiffré
 * et signé par nos clés VAPID.
 *
 * `VAPID_PRIVATE_KEY` est un **secret serveur** (il permet d'écrire sur
 * l'écran de tous les abonnés), jamais préfixé `NEXT_PUBLIC_`. La publique
 * se lit par `/api/notifications/vapid`. Sans les deux, rien ne part : le
 * centre de notifications suffit.
 */

export interface Vapid {
  publique: string
  privee: string
  sujet: string
}

export function lireVapid(env: Record<string, string | undefined> = process.env): Vapid | null {
  const publique = env.VAPID_PUBLIC_KEY?.trim()
  const privee = env.VAPID_PRIVATE_KEY?.trim()
  if (!publique || !privee) return null
  // Le service de push d'Apple refuse un sujet qui n'est ni `mailto:` ni
  // `https:` (BadJwtToken).
  const sujet = env.VAPID_SUBJECT?.trim() || 'https://revizapp.fun'
  return { publique, privee, sujet }
}

export interface AbonnementWeb {
  endpoint: string
  keys: { p256dh: string; auth: string }
}

/** Ce que reçoit le service worker (`apps/mobile/web/sw.js`). */
export interface MessageWeb {
  titre: string
  corps: string
  lien: string
  id: string
}

export type Expediteur = (
  abonnement: AbonnementWeb,
  charge: string,
  options: webpush.RequestOptions,
) => Promise<{ statusCode: number }>

export async function envoyerWebPush(
  vapid: Vapid,
  abonnement: AbonnementWeb,
  m: MessageWeb,
  envoyer: Expediteur = webpush.sendNotification,
): Promise<IssueEnvoi> {
  try {
    const reponse = await envoyer(abonnement, JSON.stringify(m), {
      vapidDetails: { subject: vapid.sujet, publicKey: vapid.publique, privateKey: vapid.privee },
      // Un « cours prêt » vieux d'un jour n'a plus d'intérêt sur l'écran.
      TTL: 24 * 3600,
      urgency: 'normal',
    })
    return reponse.statusCode >= 200 && reponse.statusCode < 300 ? 'envoye' : 'erreur'
  } catch (e) {
    const statut = (e as { statusCode?: number }).statusCode
    // 404 et 410 : l'abonnement n'existe plus (app désinstallée,
    // notifications coupées). On l'oublie.
    if (statut === 404 || statut === 410) return 'jeton-invalide'
    return 'erreur'
  }
}

/** L'abonnement d'une ligne `appareils`, ou `null` s'il est incomplet. */
export function abonnementDe(token: string, brut: unknown): AbonnementWeb | null {
  if (!brut || typeof brut !== 'object') return null
  const { p256dh, auth } = brut as Record<string, unknown>
  if (typeof p256dh !== 'string' || typeof auth !== 'string') return null
  return { endpoint: token, keys: { p256dh, auth } }
}
