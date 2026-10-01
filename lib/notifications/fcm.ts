import { createSign } from 'node:crypto'

/**
 * Envoi par Firebase Cloud Messaging (API HTTP v1), sans dépendance.
 *
 * FCM attend un jeton OAuth obtenu à partir d'un compte de service Google :
 * on signe nous-mêmes l'assertion JWT (RS256, `node:crypto`) et on
 * l'échange contre un jeton d'accès, gardé en mémoire jusqu'à sa fin. Le
 * SDK firebase-admin ferait la même chose avec quelques mégaoctets de plus
 * dans chaque fonction serverless.
 *
 * Le compte de service vit dans `FIREBASE_SERVICE_ACCOUNT` : son JSON, en
 * base64 (ou brut). **Secret serveur** — il permet d'envoyer à tous les
 * téléphones —, jamais préfixé `NEXT_PUBLIC_`. Absent, rien ne part : le
 * centre de notifications de l'application suffit.
 */

export interface CompteService {
  project_id: string
  client_email: string
  private_key: string
}

export type Fetch = typeof fetch

export function lireCompteService(
  brut: string | undefined = process.env.FIREBASE_SERVICE_ACCOUNT,
): CompteService | null {
  if (!brut || brut.trim().length === 0) return null
  const essais = [brut.trim()]
  try {
    essais.push(Buffer.from(brut.trim(), 'base64').toString('utf8'))
  } catch {
    // Pas du base64 : seul le JSON brut reste à essayer.
  }
  for (const texte of essais) {
    try {
      const v = JSON.parse(texte) as Partial<CompteService>
      if (v.project_id && v.client_email && v.private_key) {
        return { project_id: v.project_id, client_email: v.client_email, private_key: v.private_key }
      }
    } catch {
      // Essai suivant.
    }
  }
  return null
}

const b64url = (v: string | Buffer) => Buffer.from(v).toString('base64url')

/** L'assertion JWT signée que Google échange contre un jeton d'accès. */
export function assertionJwt(compte: CompteService, maintenantS: number): string {
  const entete = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
  const corps = b64url(
    JSON.stringify({
      iss: compte.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: maintenantS,
      exp: maintenantS + 3600,
    }),
  )
  const signeur = createSign('RSA-SHA256')
  signeur.update(`${entete}.${corps}`)
  return `${entete}.${corps}.${b64url(signeur.sign(compte.private_key))}`
}

let cache: { cle: string; jeton: string; expire: number } | null = null

/** Pour les tests : oublie le jeton gardé en mémoire. */
export function oublierJeton() {
  cache = null
}

async function jetonAcces(compte: CompteService, f: Fetch): Promise<string> {
  const maintenant = Math.floor(Date.now() / 1000)
  if (cache && cache.cle === compte.client_email && cache.expire - 60 > maintenant) {
    return cache.jeton
  }
  const reponse = await f('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: assertionJwt(compte, maintenant),
    }),
  })
  const corps = (await reponse.json().catch(() => ({}))) as {
    access_token?: string
    expires_in?: number
  }
  if (!reponse.ok || !corps.access_token) {
    throw new Error(`Jeton FCM refusé (${reponse.status})`)
  }
  cache = {
    cle: compte.client_email,
    jeton: corps.access_token,
    expire: maintenant + (corps.expires_in ?? 3600),
  }
  return corps.access_token
}

export interface MessagePush {
  token: string
  titre: string
  corps: string
  lien: string
  id: string
}

/** Le corps attendu par `messages:send`. */
export function messageFcm(m: MessagePush) {
  return {
    message: {
      token: m.token,
      notification: { title: m.titre, body: m.corps },
      // L'application lit `lien` au toucher, et relit son centre.
      data: { lien: m.lien, id: m.id },
      android: {
        priority: 'high',
        notification: { channel_id: 'evenements', color: '#FFC300' },
      },
      apns: { payload: { aps: { sound: 'default' } } },
    },
  }
}

export type IssueEnvoi = 'envoye' | 'jeton-invalide' | 'erreur'

/**
 * Envoie un message. `jeton-invalide` : le téléphone n'existe plus pour FCM
 * (application désinstallée, jeton renouvelé) — l'appelant le supprime.
 */
export async function envoyerFcm(compte: CompteService, m: MessagePush, f: Fetch = fetch): Promise<IssueEnvoi> {
  try {
    const jeton = await jetonAcces(compte, f)
    const reponse = await f(
      `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(compte.project_id)}/messages:send`,
      {
        method: 'POST',
        headers: { authorization: `Bearer ${jeton}`, 'content-type': 'application/json' },
        body: JSON.stringify(messageFcm(m)),
      },
    )
    if (reponse.ok) return 'envoye'

    const erreur = (await reponse.json().catch(() => ({}))) as {
      error?: { status?: string; details?: Array<{ errorCode?: string }> }
    }
    const codes = [erreur.error?.status, ...(erreur.error?.details ?? []).map((d) => d.errorCode)]
    // Seul UNREGISTERED dit que le jeton est mort. INVALID_ARGUMENT peut
    // aussi venir d'un message mal formé — une erreur de notre part, qui
    // ferait sinon effacer les jetons de tout le monde.
    if (reponse.status === 404 || codes.includes('UNREGISTERED')) return 'jeton-invalide'
    return 'erreur'
  } catch {
    return 'erreur'
  }
}
