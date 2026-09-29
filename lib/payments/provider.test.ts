import { createHmac } from 'node:crypto'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import {
  baseFedaPay,
  createPaymentProvider,
  FedaPayProvider,
  validateWebhookSignature,
} from './provider'

/**
 * Tests du fournisseur de paiement.
 *
 * Les formats attendus viennent de la doc FedaPay et du SDK Node officiel
 * (`fedapay` 1.2.5), pas de ce que le code faisait : la première version de
 * ce fichier testait fidèlement une implémentation qui ne parlait pas la
 * langue de l'API, et elle passait au vert.
 */

const SECRET = 'wh_sandbox_un-secret-de-webhook'
const CHARGE = JSON.stringify({
  name: 'transaction.approved',
  object: 'transaction',
  entity: { id: 42, status: 'approved', amount: 1500 },
})
const MAINTENANT = 1_790_000_000

/** L'en-tête tel que FedaPay le produit (`generateTestHeaderString`). */
const entete = (
  charge: string,
  { secret = SECRET, t = MAINTENANT }: { secret?: string; t?: number } = {},
) =>
  `t=${t},s=${createHmac('sha256', secret).update(`${t}.${charge}`).digest('hex')}`

const verifier = (charge: string, en: string, secret = SECRET) =>
  validateWebhookSignature(charge, en, secret, MAINTENANT)

describe('validateWebhookSignature', () => {
  it('accepte un en-tête FedaPay juste', () => {
    expect(verifier(CHARGE, entete(CHARGE))).toBe(true)
  })

  it('refuse l’ancien calcul, sur le corps seul', () => {
    // C'est ce que faisait la première version : aucune vraie notification
    // FedaPay ne l'aurait passé. Garder ce test empêche d'y revenir.
    const corpsSeul = createHmac('sha256', SECRET).update(CHARGE).digest('hex')
    expect(verifier(CHARGE, corpsSeul)).toBe(false)
    expect(verifier(CHARGE, `t=${MAINTENANT},s=${corpsSeul}`)).toBe(false)
  })

  it('refuse un corps modifié', () => {
    const falsifiee = CHARGE.replace('1500', '1')
    expect(verifier(falsifiee, entete(CHARGE))).toBe(false)
  })

  it('refuse un autre secret', () => {
    expect(verifier(CHARGE, entete(CHARGE, { secret: 'wh_sandbox_autre' }))).toBe(
      false,
    )
  })

  it('refuse un message rejoué au-delà de cinq minutes', () => {
    const ancien = entete(CHARGE, { t: MAINTENANT - 301 })
    expect(verifier(CHARGE, ancien)).toBe(false)
    const recent = entete(CHARGE, { t: MAINTENANT - 299 })
    expect(verifier(CHARGE, recent)).toBe(true)
  })

  it('ne se laisse pas tromper par un horodatage changé', () => {
    // L'horodatage est signé : le rajeunir invalide la signature.
    const vieux = entete(CHARGE, { t: MAINTENANT - 3600 })
    const rajeuni = vieux.replace(`t=${MAINTENANT - 3600}`, `t=${MAINTENANT}`)
    expect(verifier(CHARGE, rajeuni)).toBe(false)
  })

  it('accepte une signature parmi plusieurs, pendant une rotation', () => {
    const bonne = entete(CHARGE).split(',s=')[1]
    expect(verifier(CHARGE, `t=${MAINTENANT},s=${'0'.repeat(64)},s=${bonne}`)).toBe(
      true,
    )
  })

  it('accepte la signature en majuscules', () => {
    const [t, s] = entete(CHARGE).split(',s=')
    expect(verifier(CHARGE, `${t},s=${s.toUpperCase()}`)).toBe(true)
  })

  it('refuse les en-têtes incomplets ou mal formés, sans lever', () => {
    const s = entete(CHARGE).split(',s=')[1]
    expect(verifier(CHARGE, '')).toBe(false)
    expect(verifier(CHARGE, `s=${s}`)).toBe(false)
    expect(verifier(CHARGE, `t=${MAINTENANT}`)).toBe(false)
    expect(verifier(CHARGE, `t=abc,s=${s}`)).toBe(false)
    expect(verifier(CHARGE, `t=${MAINTENANT},s=zz${s.slice(2)}`)).toBe(false)
    expect(verifier(CHARGE, `t=${MAINTENANT},s=${s.slice(1)}`)).toBe(false)
    expect(verifier(CHARGE, entete(CHARGE), '')).toBe(false)
  })
})

describe('baseFedaPay', () => {
  it('lit l’environnement sur la clé', () => {
    expect(baseFedaPay('sk_live_abc')).toBe('https://api.fedapay.com')
    expect(baseFedaPay('sk_sandbox_abc')).toBe('https://sandbox-api.fedapay.com')
  })

  it('refuse une clé publique ou une autre valeur', () => {
    expect(() => baseFedaPay('pk_live_abc')).toThrow(/secrète/)
    expect(() => baseFedaPay('https://exemple.com')).toThrow(/sk_live_/)
  })
})

describe('createPaymentProvider', () => {
  const env = { ...process.env }

  beforeEach(() => {
    process.env.FEDAPAY_SECRET_KEY = 'sk_sandbox_test'
  })

  afterEach(() => {
    process.env = { ...env }
    vi.restoreAllMocks()
  })

  it('rend une implémentation FedaPay', () => {
    expect(createPaymentProvider('fedapay')).toBeInstanceOf(FedaPayProvider)
    // La casse ne doit pas décider d'un refus de paiement.
    expect(createPaymentProvider('FedaPay')).toBeInstanceOf(FedaPayProvider)
  })

  it('refuse un fournisseur inconnu', () => {
    expect(() => createPaymentProvider('moneroo')).toThrow(/moneroo/)
  })

  it('refuse de se construire sans clé', () => {
    delete process.env.FEDAPAY_SECRET_KEY
    // Mieux vaut échouer tôt qu'envoyer une requête sans authentification et
    // prendre le refus pour un paiement échoué.
    expect(() => createPaymentProvider()).toThrow(/FEDAPAY_SECRET_KEY/)
  })

  it('n’exige pas le secret du webhook pour ouvrir un paiement', () => {
    // La première version l'exigeait : un secret manquant empêchait
    // l'étudiant de payer, alors qu'il ne sert qu'à lire les notifications.
    delete process.env.FEDAPAY_WEBHOOK_SECRET
    expect(() => createPaymentProvider()).not.toThrow()
  })
})

describe('FedaPayProvider.initPayment', () => {
  afterEach(() => vi.restoreAllMocks())

  const reponse = (corps: unknown, ok = true, status = 200) =>
    ({ ok, status, json: async () => corps }) as Response

  const opts = {
    userId: '11111111-1111-1111-1111-111111111111',
    paiementId: '22222222-2222-2222-2222-222222222222',
    amount: 1500,
    packCode: 'controle',
    retourUrl: 'https://reviz.app/paiement/retour',
  }

  it('crée la transaction dans la forme de l’API, puis demande le lien', async () => {
    const appels = vi
      .spyOn(globalThis, 'fetch')
      .mockResolvedValueOnce(
        reponse({ 'v1/transaction': { id: 42, status: 'pending' } }, true, 201),
      )
      .mockResolvedValueOnce(
        reponse({ token: 'JETON', url: 'https://process.fedapay.com/JETON' }),
      )

    const resultat = await new FedaPayProvider('sk_sandbox_x').initPayment(opts)

    expect(resultat).toEqual({
      ok: true,
      transactionId: '42',
      redirectUrl: 'https://process.fedapay.com/JETON',
      amount: 1500,
    })

    const [url, init] = appels.mock.calls[0]
    expect(url).toBe('https://sandbox-api.fedapay.com/v1/transactions')
    expect((init?.headers as Record<string, string>).Authorization).toBe(
      'Bearer sk_sandbox_x',
    )
    const corps = JSON.parse(String(init?.body))
    expect(corps.currency).toEqual({ iso: 'XOF' })
    expect(corps.amount).toBe(1500)
    expect(corps.callback_url).toBe(opts.retourUrl)
    expect(corps.custom_metadata).toEqual({
      user_id: opts.userId,
      pack_code: 'controle',
      paiement_id: opts.paiementId,
    })

    expect(appels.mock.calls[1][0]).toBe(
      'https://sandbox-api.fedapay.com/v1/transactions/42/token',
    )
    expect(appels.mock.calls[1][1]?.method).toBe('POST')
  })

  it('va en production avec une clé live', async () => {
    const appels = vi
      .spyOn(globalThis, 'fetch')
      .mockResolvedValueOnce(reponse({ 'v1/transaction': { id: 7 } }))
      .mockResolvedValueOnce(reponse({ url: 'https://process.fedapay.com/T' }))

    await new FedaPayProvider('sk_live_x').initPayment(opts)
    expect(appels.mock.calls[0][0]).toBe('https://api.fedapay.com/v1/transactions')
  })

  it('rend le message de FedaPay quand la création est refusée', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(
      reponse({ message: 'Montant invalide' }, false, 422),
    )
    const resultat = await new FedaPayProvider('sk_sandbox_x').initPayment(opts)
    expect(resultat).toEqual({ ok: false, error: 'Montant invalide' })
  })

  it('ne prend jamais une réponse sans identifiant pour un succès', async () => {
    // L'ancienne lecture (`data.data`) sur une réponse réelle, enveloppée
    // sous `v1/transaction`, aurait abouti ici.
    vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(
      reponse({ data: { id: 42 } }),
    )
    const resultat = await new FedaPayProvider('sk_sandbox_x').initPayment(opts)
    expect(resultat.ok).toBe(false)
  })

  it('échoue si le lien de paiement ne vient pas', async () => {
    vi.spyOn(globalThis, 'fetch')
      .mockResolvedValueOnce(reponse({ 'v1/transaction': { id: 42 } }))
      .mockResolvedValueOnce(reponse({}, false, 500))
    const resultat = await new FedaPayProvider('sk_sandbox_x').initPayment(opts)
    expect(resultat.ok).toBe(false)
  })

  it('transforme une coupure réseau en échec, sans lever', async () => {
    vi.spyOn(globalThis, 'fetch').mockRejectedValueOnce(new Error('réseau'))
    vi.spyOn(console, 'error').mockImplementation(() => {})
    const resultat = await new FedaPayProvider('sk_sandbox_x').initPayment(opts)
    expect(resultat).toEqual({ ok: false, error: 'réseau' })
  })
})

describe('FedaPayProvider.checkStatus', () => {
  afterEach(() => vi.restoreAllMocks())

  it('lit la transaction dans son enveloppe', async () => {
    const appel = vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce({
      ok: true,
      status: 200,
      json: async () => ({
        'v1/transaction': { id: 42, status: 'approved', amount: 1500 },
      }),
    } as Response)

    const etat = await new FedaPayProvider('sk_sandbox_x').checkStatus('42')

    expect(etat).toEqual({ id: '42', status: 'approved', amount: 1500 })
    expect(appel.mock.calls[0][0]).toBe(
      'https://sandbox-api.fedapay.com/v1/transactions/42',
    )
  })

  it('rend null plutôt qu’un statut inventé', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce({
      ok: false,
      status: 404,
      json: async () => ({}),
    } as Response)
    expect(await new FedaPayProvider('sk_sandbox_x').checkStatus('9')).toBeNull()
  })
})
