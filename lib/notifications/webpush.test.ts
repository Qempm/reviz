import { createECDH, randomBytes } from 'node:crypto'
import { describe, expect, it } from 'vitest'
import webpush from 'web-push'
import { abonnementDe, envoyerWebPush, type Expediteur, lireVapid } from './webpush'

const cles = webpush.generateVAPIDKeys()
const vapid = { publique: cles.publicKey, privee: cles.privateKey, sujet: 'https://revizapp.fun' }
const abonnement = abonnementDe('https://web.push.apple.com/QGuQ', { p256dh: 'BNcRd', auth: 'tBHI' })!
const message = { titre: 'Ton cours est prêt', corps: 'Droit', lien: '/cours/c1', id: 'n1' }

describe('Web Push', () => {
  it('lit les clés, et rien sans la privée', () => {
    expect(lireVapid({ VAPID_PUBLIC_KEY: 'pub', VAPID_PRIVATE_KEY: 'priv' })).toEqual({
      publique: 'pub',
      privee: 'priv',
      sujet: 'https://revizapp.fun',
    })
    expect(lireVapid({ VAPID_PUBLIC_KEY: 'pub' })).toBeNull()
  })

  it('refuse un abonnement sans ses clés', () => {
    expect(abonnementDe('https://x', null)).toBeNull()
    expect(abonnementDe('https://x', { p256dh: 'a' })).toBeNull()
  })

  it('envoie le message, signé par nos clés, avec un délai de vie', async () => {
    let recu: { charge: string; options: webpush.RequestOptions } | null = null
    const envoyer: Expediteur = async (_a, charge, options) => {
      recu = { charge, options }
      return { statusCode: 201 }
    }
    expect(await envoyerWebPush(vapid, abonnement, message, envoyer)).toBe('envoye')
    expect(JSON.parse(recu!.charge)).toEqual(message)
    expect(recu!.options.vapidDetails?.publicKey).toBe(cles.publicKey)
    expect(recu!.options.TTL).toBe(86400)
  })

  it('un abonnement disparu (410) est à oublier, une panne non', async () => {
    const parti: Expediteur = async () => {
      throw Object.assign(new Error('Gone'), { statusCode: 410 })
    }
    const panne: Expediteur = async () => {
      throw Object.assign(new Error('Boom'), { statusCode: 500 })
    }
    expect(await envoyerWebPush(vapid, abonnement, message, parti)).toBe('jeton-invalide')
    expect(await envoyerWebPush(vapid, abonnement, message, panne)).toBe('erreur')
  })

  it('chiffre vraiment pour le navigateur (bibliothèque, sans réseau)', () => {
    // Une vraie paire de clés de navigateur : la bibliothèque doit savoir
    // préparer la requête chiffrée (aes128gcm) et signée (ES256) qu'Apple
    // attend, sans l'envoyer.
    const ecdh = createECDH('prime256v1')
    ecdh.generateKeys()
    const vrai = {
      endpoint: 'https://web.push.apple.com/QGuQ',
      keys: {
        p256dh: ecdh.getPublicKey().toString('base64url'),
        auth: randomBytes(16).toString('base64url'),
      },
    }
    const requete = webpush.generateRequestDetails(vrai, JSON.stringify(message), {
      vapidDetails: { subject: vapid.sujet, publicKey: vapid.publique, privateKey: vapid.privee },
      TTL: 60,
    })
    expect(requete.method).toBe('POST')
    expect(requete.headers['Content-Encoding']).toBe('aes128gcm')
    expect(String(requete.headers.Authorization)).toMatch(/^vapid t=.+, k=/)
  })
})
