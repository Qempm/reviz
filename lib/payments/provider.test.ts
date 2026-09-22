import { createHmac } from 'node:crypto'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import {
  createPaymentProvider,
  FedaPayProvider,
  validateWebhookSignature,
} from './provider'

/**
 * Tests du fournisseur de paiement.
 *
 * Ce fichier — celui qui manipule l'argent — n'en avait aucun. Deux choses
 * comptent ici : qu'une signature ne soit acceptée que si elle est juste, et
 * qu'une réponse inattendue du fournisseur ne soit jamais prise pour un
 * succès. Le reste de la chaîne est vérifié par `lib/metier/paiement.test.ts`.
 */

const SECRET = 'un-secret-de-webhook'
const CHARGE = '{"event":"transaction.approved","data":{"id":42}}'

const signer = (charge: string, secret = SECRET) =>
  createHmac('sha256', secret).update(charge).digest('hex')

describe('validateWebhookSignature', () => {
  it('accepte une signature juste', () => {
    expect(validateWebhookSignature(CHARGE, signer(CHARGE), SECRET)).toBe(true)
  })

  it('accepte la même signature en majuscules', () => {
    // L'hexadécimal n'a pas de casse ; un fournisseur peut envoyer l'un ou
    // l'autre, et refuser sur ce motif serait un refus au hasard.
    expect(
      validateWebhookSignature(CHARGE, signer(CHARGE).toUpperCase(), SECRET),
    ).toBe(true)
  })

  it('refuse une charge utile modifiée', () => {
    const signature = signer(CHARGE)
    const falsifiee = CHARGE.replace('42', '43')
    expect(validateWebhookSignature(falsifiee, signature, SECRET)).toBe(false)
  })

  it('refuse un autre secret', () => {
    expect(
      validateWebhookSignature(CHARGE, signer(CHARGE, 'autre'), SECRET),
    ).toBe(false)
  })

  it('refuse une signature absente', () => {
    // Cas de l'en-tête manquant, qui arrive au code sous forme de chaîne
    // vide. `timingSafeEqual` lèverait sur des tampons de tailles
    // différentes : le refus doit venir avant.
    expect(validateWebhookSignature(CHARGE, '', SECRET)).toBe(false)
  })

  it('refuse un secret absent', () => {
    // Sans secret configuré, tout serait accepté par une HMAC sur chaîne
    // vide — c'est-à-dire n'importe quel appelant.
    expect(validateWebhookSignature(CHARGE, signer(CHARGE), '')).toBe(false)
  })

  it('refuse une signature trop courte, sans lever', () => {
    const tronquee = signer(CHARGE).slice(0, 32)
    expect(() =>
      validateWebhookSignature(CHARGE, tronquee, SECRET),
    ).not.toThrow()
    expect(validateWebhookSignature(CHARGE, tronquee, SECRET)).toBe(false)
  })

  it('refuse ce qui n’est pas de l’hexadécimal, sans lever', () => {
    // `Buffer.from(x, 'hex')` ne lève pas sur une chaîne invalide : il
    // s'arrête au premier caractère non hexadécimal et rend un tampon plus
    // court, ce qui ferait lever `timingSafeEqual`. D'où le filtre explicite.
    const bruit = 'z'.repeat(signer(CHARGE).length)
    expect(() => validateWebhookSignature(CHARGE, bruit, SECRET)).not.toThrow()
    expect(validateWebhookSignature(CHARGE, bruit, SECRET)).toBe(false)
  })

  it('compare la totalité de la signature, pas seulement son début', () => {
    // Le premier octet juste et le reste faux doit être refusé comme
    // n'importe quoi d'autre : c'est ce qu'un `===` interrompu rendrait
    // mesurable au chronomètre.
    const juste = signer(CHARGE)
    const presque = juste.slice(0, 2) + 'f'.repeat(juste.length - 2)
    expect(validateWebhookSignature(CHARGE, presque, SECRET)).toBe(false)
  })
})

describe('createPaymentProvider', () => {
  const env = { ...process.env }

  beforeEach(() => {
    process.env.FEDAPAY_SECRET_KEY = 'sk_test'
    process.env.FEDAPAY_WEBHOOK_SECRET = SECRET
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
    // Mieux vaut échouer au démarrage qu'envoyer une requête sans
    // authentification et interpréter le refus comme un paiement échoué.
    expect(() => createPaymentProvider()).toThrow(/FEDAPAY_SECRET_KEY/)
  })

  it('refuse de se construire sans secret de webhook', () => {
    delete process.env.FEDAPAY_WEBHOOK_SECRET
    expect(() => createPaymentProvider()).toThrow(/FEDAPAY_WEBHOOK_SECRET/)
  })

  it('vérifie une signature à travers l’interface', () => {
    // Le point de la correction : cette méthode existait déjà mais était
    // absente de l'interface, donc inatteignable par `createPaymentProvider`.
    const fournisseur = createPaymentProvider()
    expect(fournisseur.verifyWebhookSignature(CHARGE, signer(CHARGE))).toBe(
      true,
    )
    expect(fournisseur.verifyWebhookSignature(CHARGE, signer(CHARGE, 'x'))).toBe(
      false,
    )
  })
})

describe('FedaPayProvider.initPayment', () => {
  const env = { ...process.env }

  beforeEach(() => {
    process.env.FEDAPAY_SECRET_KEY = 'sk_test'
    process.env.FEDAPAY_WEBHOOK_SECRET = SECRET
    process.env.NEXT_PUBLIC_APP_URL = 'https://reviz.app'
  })

  afterEach(() => {
    process.env = { ...env }
    vi.restoreAllMocks()
  })

  const reponse = (corps: unknown, ok = true, status = 200) =>
    ({
      ok,
      status,
      json: async () => corps,
    }) as Response

  const opts = {
    userId: '11111111-1111-1111-1111-111111111111',
    amount: 500,
    packCode: 'controle',
    phone: '+22997123456',
  }

  it('rend l’identifiant et l’URL de paiement', async () => {
    const fetchMock = vi
      .spyOn(globalThis, 'fetch')
      .mockResolvedValue(reponse({ data: { id: 777, token: 'tok' } }))

    const resultat = await new FedaPayProvider().initPayment(opts)

    expect(resultat.ok).toBe(true)
    if (!resultat.ok) return
    expect(resultat.transactionId).toBe('777')
    expect(resultat.redirectUrl).toContain('777')
    expect(resultat.redirectUrl).toContain('token=tok')
    // Le montant rendu est celui demandé : jamais celui que renvoie le
    // fournisseur, qui n'a pas à décider du prix d'un pack.
    expect(resultat.amount).toBe(500)

    const [, init] = fetchMock.mock.calls[0]
    const envoye = JSON.parse(String((init as RequestInit).body))
    // Les métadonnées sont ce que le webhook retrouvera : sans elles, un
    // paiement ne peut pas être rattaché à un étudiant.
    expect(envoye.metadata).toEqual({
      user_id: opts.userId,
      pack_code: 'controle',
    })
    expect(envoye.callback_url).toBe('https://reviz.app/api/payments/webhook')
  })

  it('accepte aussi la forme « transaction » de la réponse', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(
      reponse({ transaction: { id: '888' } }),
    )

    const resultat = await new FedaPayProvider().initPayment(opts)
    expect(resultat.ok).toBe(true)
    if (resultat.ok) expect(resultat.transactionId).toBe('888')
  })

  it('refuse une réponse sans identifiant de transaction', async () => {
    // Le cas qui compte : sans identifiant, le webhook ne pourra jamais
    // rattacher le paiement. Prendre cela pour un succès laisserait
    // l'étudiant devant une page de paiement vide.
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(reponse({ data: {} }))

    const resultat = await new FedaPayProvider().initPayment(opts)
    expect(resultat.ok).toBe(false)
  })

  it('rapporte une erreur HTTP du fournisseur', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(
      reponse({ message: 'Montant invalide' }, false, 422),
    )

    const resultat = await new FedaPayProvider().initPayment(opts)
    expect(resultat.ok).toBe(false)
    if (!resultat.ok) expect(resultat.error).toBe('Montant invalide')
  })

  it('rapporte une panne réseau sans lever', async () => {
    // Une exception qui traverse ferait un 500 opaque sur l'écran boutique.
    vi.spyOn(globalThis, 'fetch').mockRejectedValue(new Error('ECONNRESET'))
    vi.spyOn(console, 'error').mockImplementation(() => {})

    const resultat = await new FedaPayProvider().initPayment(opts)
    expect(resultat.ok).toBe(false)
    if (!resultat.ok) expect(resultat.error).toBe('ECONNRESET')
  })
})
