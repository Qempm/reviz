import { createVerify, generateKeyPairSync } from 'node:crypto'
import { beforeEach, describe, expect, it } from 'vitest'
import { assertionJwt, envoyerFcm, lireCompteService, messageFcm, oublierJeton, type Fetch } from './fcm'

const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 })
const compte = {
  project_id: 'reviz-test',
  client_email: 'push@reviz-test.iam.gserviceaccount.com',
  private_key: privateKey.export({ type: 'pkcs8', format: 'pem' }).toString(),
}

/** Un réseau simulé : le jeton OAuth, puis la réponse donnée à l'envoi. */
function reseau(envoi: { status: number; corps?: unknown }) {
  const appels: string[] = []
  const f = (async (url: string | URL | Request) => {
    const u = String(url)
    appels.push(u)
    if (u.includes('oauth2')) {
      return new Response(JSON.stringify({ access_token: 'jeton', expires_in: 3600 }), { status: 200 })
    }
    return new Response(JSON.stringify(envoi.corps ?? {}), { status: envoi.status })
  }) as Fetch
  return { f, appels }
}

const message = { token: 't1', titre: 'Ton cours est prêt', corps: '…', lien: '/cours/c1', id: 'n1' }

describe('FCM', () => {
  beforeEach(() => oublierJeton())

  it('lit le compte de service en base64 comme en JSON brut', () => {
    const json = JSON.stringify(compte)
    expect(lireCompteService(json)?.project_id).toBe('reviz-test')
    expect(lireCompteService(Buffer.from(json).toString('base64'))?.client_email).toBe(compte.client_email)
    expect(lireCompteService('')).toBeNull()
    expect(lireCompteService(undefined)).toBeNull()
    expect(lireCompteService('{"project_id":"x"}')).toBeNull()
  })

  it('signe une assertion que la clé publique vérifie', () => {
    const jwt = assertionJwt(compte, 1_800_000_000)
    const [entete, corps, signature] = jwt.split('.')
    const v = createVerify('RSA-SHA256')
    v.update(`${entete}.${corps}`)
    expect(v.verify(publicKey, Buffer.from(signature, 'base64url'))).toBe(true)
    const charge = JSON.parse(Buffer.from(corps, 'base64url').toString())
    expect(charge.scope).toBe('https://www.googleapis.com/auth/firebase.messaging')
    expect(charge.exp - charge.iat).toBe(3600)
  })

  it('le message porte le lien et le canal Android', () => {
    const m = messageFcm(message).message
    expect(m.data).toEqual({ lien: '/cours/c1', id: 'n1' })
    expect(m.android.notification.channel_id).toBe('evenements')
  })

  it('envoie, et ne redemande pas de jeton tant qu’il est valable', async () => {
    const { f, appels } = reseau({ status: 200, corps: { name: 'projects/x/messages/1' } })
    expect(await envoyerFcm(compte, message, f)).toBe('envoye')
    expect(await envoyerFcm(compte, message, f)).toBe('envoye')
    expect(appels.filter((u) => u.includes('oauth2'))).toHaveLength(1)
    expect(appels.filter((u) => u.includes('projects/reviz-test/messages:send'))).toHaveLength(2)
  })

  it('un jeton désinscrit est signalé pour suppression', async () => {
    const { f } = reseau({
      status: 404,
      corps: { error: { status: 'NOT_FOUND', details: [{ errorCode: 'UNREGISTERED' }] } },
    })
    expect(await envoyerFcm(compte, message, f)).toBe('jeton-invalide')
  })

  it('un message refusé n’efface pas le jeton', async () => {
    const { f } = reseau({ status: 400, corps: { error: { status: 'INVALID_ARGUMENT' } } })
    expect(await envoyerFcm(compte, message, f)).toBe('erreur')
  })
})
