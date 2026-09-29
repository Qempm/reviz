/**
 * Abstraction des fournisseurs de paiement Mobile Money.
 *
 * Chaque fournisseur implémente l'interface PaymentProvider : ouvrir une
 * transaction, dire où l'étudiant la paie, et relire son statut. FedaPay est
 * la première implémentation (Bénin, Togo, Côte d'Ivoire) ; Moneroo et
 * KkiaPay suivront avec la même interface.
 *
 * **Réécrit le 29 septembre 2026, doc et SDK officiel en main.** La première
 * version avait été écrite sans eux, et six points divergeaient de l'API
 * réelle — chacun suffisait à ce qu'aucun paiement n'aboutisse : adresse de
 * l'API figée sur la production, devise `'FCFA'` au lieu de `{ iso: 'XOF' }`,
 * `metadata` au lieu de `custom_metadata`, lien de paiement fabriqué à la
 * main au lieu d'être demandé, réponse lue sous `data` alors que FedaPay
 * l'enveloppe sous `v1/transaction`, et signature de webhook calculée sur le
 * corps seul. Les références :
 *
 *   https://docs.fedapay.com/api-reference/transactions/create
 *   https://docs.fedapay.com/api-reference/transactions/create-token
 *   https://docs.fedapay.com/fr/integration-api/webhooks
 *   SDK Node `fedapay` 1.2.5, `src/Webhook.ts` et `src/Requestor.ts`
 */

import { createHmac, timingSafeEqual } from 'node:crypto'

/** Résultat de l'ouverture d'une transaction. */
export type InitPaymentResult =
  | {
      ok: true
      transactionId: string
      /** La page FedaPay où l'étudiant choisit son opérateur et paie. */
      redirectUrl: string
      amount: number
    }
  | {
      ok: false
      error: string
    }

/** Les statuts d'une transaction FedaPay. */
export type StatutTransaction =
  | 'pending'
  | 'approved'
  | 'declined'
  | 'canceled'
  | 'refunded'
  | 'transferred'
  | 'expired'
  | (string & {})

export type EtatTransaction = {
  id: string
  status: StatutTransaction
  amount: number
}

export interface PaymentProvider {
  /** Ouvre une transaction et rend l'URL où l'étudiant la paie. */
  initPayment(opts: {
    userId: string
    paiementId: string
    amount: number
    packCode: string
    /** Où FedaPay renvoie l'étudiant une fois le paiement tranché. */
    retourUrl: string
  }): Promise<InitPaymentResult>

  /**
   * Relit une transaction auprès du fournisseur.
   *
   * C'est le filet du webhook : si la notification se perd ou arrive avec
   * une signature refusée, l'écran qui attend le paiement le demande
   * directement, avec la clé secrète — une source aussi sûre que le webhook.
   */
  checkStatus(transactionId: string): Promise<EtatTransaction | null>
}

/** Les adresses de l'API, reprises du SDK officiel (`Requestor.ts`). */
const BASE_SANDBOX = 'https://sandbox-api.fedapay.com'
const BASE_LIVE = 'https://api.fedapay.com'

/**
 * L'environnement se lit sur la clé elle-même.
 *
 * FedaPay préfixe ses clés secrètes `sk_sandbox_` ou `sk_live_`, et une clé
 * d'un environnement est refusée par l'autre. Le déduire évite une seconde
 * variable qui pourrait contredire la première — une clé de test envoyée en
 * production répondrait 401, et on chercherait longtemps pourquoi.
 */
export function baseFedaPay(cle: string): string {
  if (cle.startsWith('sk_live_')) return BASE_LIVE
  if (cle.startsWith('sk_sandbox_')) return BASE_SANDBOX
  throw new Error(
    'FEDAPAY_SECRET_KEY doit commencer par sk_live_ ou sk_sandbox_ : ' +
      'c’est la clé **secrète** du tableau de bord FedaPay, pas la publique.',
  )
}

/**
 * FedaPay enveloppe chaque objet sous son type : `{ "v1/transaction": {…} }`.
 * Constaté dans les fixtures du SDK officiel, que la doc ne montre pas.
 */
function deballer(corps: unknown, cle: string): Record<string, unknown> | null {
  if (!corps || typeof corps !== 'object') return null
  const objet = (corps as Record<string, unknown>)[cle]
  return objet && typeof objet === 'object'
    ? (objet as Record<string, unknown>)
    : null
}

class FedaPayProvider implements PaymentProvider {
  private cle: string
  private base: string

  constructor(cle?: string) {
    this.cle = cle || process.env.FEDAPAY_SECRET_KEY || ''
    if (!this.cle) {
      throw new Error('FEDAPAY_SECRET_KEY missing in environment')
    }
    this.base = baseFedaPay(this.cle)
  }

  private appeler(methode: 'GET' | 'POST', chemin: string, corps?: unknown) {
    return fetch(`${this.base}/v1${chemin}`, {
      method: methode,
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${this.cle}`,
      },
      body: corps === undefined ? undefined : JSON.stringify(corps),
    })
  }

  async initPayment(opts: {
    userId: string
    paiementId: string
    amount: number
    packCode: string
    retourUrl: string
  }): Promise<InitPaymentResult> {
    try {
      // 1. La transaction.
      const creation = await this.appeler('POST', '/transactions', {
        description: `Reviz — pack ${opts.packCode}`,
        amount: opts.amount,
        currency: { iso: 'XOF' },
        // Pour FedaPay, `callback_url` est la page où **l'étudiant** revient
        // après avoir payé — pas l'adresse du webhook, qui se déclare dans
        // le tableau de bord. Les confondre renvoyait l'étudiant sur une
        // route d'API qui ne répond qu'en POST.
        callback_url: opts.retourUrl,
        custom_metadata: {
          user_id: opts.userId,
          pack_code: opts.packCode,
          paiement_id: opts.paiementId,
        },
      })

      const corpsCreation = await creation.json().catch(() => null)
      if (!creation.ok) {
        return {
          ok: false,
          error:
            (corpsCreation as { message?: string } | null)?.message ??
            `FedaPay a répondu ${creation.status} à la création.`,
        }
      }

      const transaction = deballer(corpsCreation, 'v1/transaction')
      const id = transaction?.id
      if (typeof id !== 'number' && typeof id !== 'string') {
        return { ok: false, error: 'Réponse FedaPay sans identifiant.' }
      }

      // 2. Le lien de paiement, qui ne se devine pas : il porte un jeton.
      const jeton = await this.appeler('POST', `/transactions/${id}/token`)
      const corpsJeton = (await jeton.json().catch(() => null)) as {
        url?: unknown
      } | null

      if (!jeton.ok || typeof corpsJeton?.url !== 'string') {
        return {
          ok: false,
          error: `FedaPay n’a pas rendu de lien de paiement (${jeton.status}).`,
        }
      }

      return {
        ok: true,
        transactionId: String(id),
        redirectUrl: corpsJeton.url,
        amount: opts.amount,
      }
    } catch (error) {
      console.error('FedaPay initPayment :', error)
      return {
        ok: false,
        error: error instanceof Error ? error.message : 'Erreur inconnue',
      }
    }
  }

  async checkStatus(transactionId: string): Promise<EtatTransaction | null> {
    try {
      const reponse = await this.appeler(
        'GET',
        `/transactions/${encodeURIComponent(transactionId)}`,
      )
      if (!reponse.ok) return null

      const transaction = deballer(
        await reponse.json().catch(() => null),
        'v1/transaction',
      )
      if (!transaction || typeof transaction.status !== 'string') return null

      return {
        id: String(transaction.id),
        status: transaction.status,
        amount: Number(transaction.amount ?? 0),
      }
    } catch (error) {
      console.error('FedaPay checkStatus :', error)
      return null
    }
  }
}

/** Le fournisseur demandé. FedaPay seul pour l'instant. */
export function createPaymentProvider(
  provider: string = 'fedapay',
): PaymentProvider {
  switch (provider.toLowerCase()) {
    case 'fedapay':
      return new FedaPayProvider()
    default:
      throw new Error(`Unknown payment provider: ${provider}`)
  }
}

export { FedaPayProvider }

/** Au-delà de cinq minutes, une signature est refusée : c'est le rejeu. */
export const TOLERANCE_SIGNATURE_S = 300

/**
 * Vérifie l'en-tête `X-FEDAPAY-SIGNATURE` d'un webhook.
 *
 * Le format est celui du SDK officiel (`WebhookSignature.verifyHeader`) :
 * `t=<horodatage>,s=<signature>`, où la signature est le HMAC-SHA256
 * hexadécimal de `"<horodatage>.<corps brut>"` avec le secret du point de
 * terminaison (`wh_live_…` ou `wh_sandbox_…`). Plusieurs `s=` peuvent
 * coexister pendant une rotation de secret : une seule doit correspondre.
 *
 * **L'horodatage est signé**, ce qui permet de refuser un vieux message
 * rejoué : sans la tolérance, quelqu'un qui aurait intercepté une
 * notification `approved` pourrait la renvoyer indéfiniment.
 *
 * **La comparaison est à temps constant.** Un `===` s'arrête au premier
 * caractère différent, et le temps de réponse renseigne alors sur ce qui a
 * été deviné. Une signature qui n'est pas de l'hexadécimal de la bonne
 * longueur est écartée avant, parce que `timingSafeEqual` exige deux tampons
 * de même taille et lèverait.
 */
export function validateWebhookSignature(
  payload: string,
  entete: string,
  secret: string,
  maintenantS: number = Math.floor(Date.now() / 1000),
  toleranceS: number = TOLERANCE_SIGNATURE_S,
): boolean {
  if (!secret || !entete) return false

  let horodatage = -1
  const signatures: string[] = []
  for (const morceau of entete.split(',')) {
    const [cle, ...reste] = morceau.trim().split('=')
    const valeur = reste.join('=')
    if (cle === 't') horodatage = Number.parseInt(valeur, 10)
    if (cle === 's') signatures.push(valeur)
  }

  if (!Number.isFinite(horodatage) || horodatage < 0) return false
  if (signatures.length === 0) return false
  if (Math.abs(maintenantS - horodatage) > toleranceS) return false

  const attendu = Buffer.from(
    createHmac('sha256', secret)
      .update(`${horodatage}.${payload}`, 'utf8')
      .digest('hex'),
    'hex',
  )

  return signatures.some((s) => {
    if (s.length !== attendu.length * 2 || !/^[0-9a-fA-F]+$/.test(s)) {
      return false
    }
    return timingSafeEqual(attendu, Buffer.from(s.toLowerCase(), 'hex'))
  })
}
