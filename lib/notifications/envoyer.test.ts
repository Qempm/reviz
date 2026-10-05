import { generateKeyPairSync } from 'node:crypto'
import { describe, expect, it } from 'vitest'
import { envoyerEnAttente } from './envoyer'
import { oublierJeton, type Fetch } from './fcm'

const { privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 })
const compte = {
  project_id: 'reviz-test',
  client_email: 'push@reviz-test.iam.gserviceaccount.com',
  private_key: privateKey.export({ type: 'pkcs8', format: 'pem' }).toString(),
}

type Ligne = { id: string; user_id: string; kind: string; reference_id: string | null; data: unknown }

/** Un client Supabase réduit à ce qu'utilise `envoyerEnAttente`. */
function base(
  lignes: Ligne[],
  profils: Array<{ id: string; notifications: unknown }>,
  appareils: Array<{ token: string; user_id: string; plateforme?: string; abonnement?: unknown }>,
) {
  const supprimes: string[] = []
  const admin = {
    rpc: async () => ({ data: lignes, error: null }),
    from: (table: string) => ({
      select: () => ({
        in: async () => ({ data: table === 'profiles' ? profils : appareils, error: null }),
      }),
      delete: () => ({
        in: async (_colonne: string, valeurs: string[]) => {
          supprimes.push(...valeurs)
          return { error: null }
        },
      }),
    }),
  }
  return { admin: admin as never, supprimes }
}

function reseau(morts: string[] = []) {
  const envois: Array<{ token: string; titre: string; lien: string }> = []
  const f = (async (url: string | URL | Request, init?: RequestInit) => {
    if (String(url).includes('oauth2')) {
      return new Response(JSON.stringify({ access_token: 'j', expires_in: 3600 }), { status: 200 })
    }
    const m = JSON.parse(String(init?.body)).message
    envois.push({ token: m.token, titre: m.notification.title, lien: m.data.lien })
    if (morts.includes(m.token)) {
      return new Response(JSON.stringify({ error: { details: [{ errorCode: 'UNREGISTERED' }] } }), {
        status: 404,
      })
    }
    return new Response('{}', { status: 200 })
  }) as Fetch
  return { f, envois }
}

describe('envoi des notifications en attente', () => {
  it('sans Firebase, ne réserve rien et n’envoie rien', async () => {
    const { admin } = base([], [], [])
    expect(await envoyerEnAttente(admin, { compte: null, vapid: null })).toEqual({
      reservees: 0,
      envoyes: 0,
      jetonsSupprimes: 0,
    })
  })

  it('envoie à chaque téléphone, respecte les préférences, efface les jetons morts', async () => {
    oublierJeton()
    const { admin, supprimes } = base(
      [
        { id: 'n1', user_id: 'awa', kind: 'cours_pret', reference_id: 'c1', data: { titre: 'Droit' } },
        {
          id: 'n2',
          user_id: 'awa',
          kind: 'ligue_cloturee',
          reference_id: 'g1',
          data: { issue: 'monte', division: 3, rang: 2 },
        },
        { id: 'n3', user_id: 'koffi', kind: 'commission_recue', reference_id: 'l1', data: { montant: 375 } },
        { id: 'n4', user_id: 'yao', kind: 'cours_pret', reference_id: 'c9', data: {} },
      ],
      [
        { id: 'awa', notifications: { ligue: false } },
        { id: 'koffi', notifications: {} },
        { id: 'yao', notifications: {} },
      ],
      [
        { token: 'awa-tel', user_id: 'awa' },
        { token: 'awa-tablette', user_id: 'awa' },
        { token: 'koffi-mort', user_id: 'koffi' },
      ],
    )
    const { f, envois } = reseau(['koffi-mort'])
    const bilan = await envoyerEnAttente(admin, { compte, f, vapid: null })

    // Awa : le cours, sur ses deux appareils ; pas la ligue, coupée.
    expect(envois.filter((e) => e.token.startsWith('awa'))).toEqual([
      { token: 'awa-tel', titre: 'Ton cours est prêt', lien: '/cours/c1' },
      { token: 'awa-tablette', titre: 'Ton cours est prêt', lien: '/cours/c1' },
    ])
    // Yao n'a aucun téléphone enregistré : rien ne part, sans erreur.
    expect(envois.some((e) => e.token.startsWith('yao'))).toBe(false)
    expect(bilan).toEqual({ reservees: 4, envoyes: 2, jetonsSupprimes: 1 })
    expect(supprimes).toEqual(['koffi-mort'])
  })

  it('l’app web installée reçoit par Web Push, même sans Firebase', async () => {
    const { admin, supprimes } = base(
      [{ id: 'n1', user_id: 'awa', kind: 'cours_pret', reference_id: 'c1', data: { titre: 'Droit' } }],
      [{ id: 'awa', notifications: {} }],
      [
        // L'iPhone d'Awa (app web installée), et un vieil abonnement mort.
        { token: 'https://web.push.apple.com/awa', user_id: 'awa', plateforme: 'web', abonnement: { p256dh: 'BNc', auth: 'tBH' } },
        { token: 'https://web.push.apple.com/vieux', user_id: 'awa', plateforme: 'web', abonnement: { p256dh: 'BNc', auth: 'tBH' } },
        // Un téléphone Android : sans Firebase, il est sauté, sans erreur.
        { token: 'awa-android', user_id: 'awa', plateforme: 'android' },
      ],
    )
    const envois: Array<{ endpoint: string; charge: unknown }> = []
    const bilan = await envoyerEnAttente(admin, {
      compte: null,
      vapid: { publique: 'pub', privee: 'priv', sujet: 'https://revizapp.fun' },
      expediteur: async (abonnement, charge) => {
        envois.push({ endpoint: abonnement.endpoint, charge: JSON.parse(charge) })
        if (abonnement.endpoint.endsWith('vieux')) {
          throw Object.assign(new Error('Gone'), { statusCode: 410 })
        }
        return { statusCode: 201 }
      },
    })

    expect(envois[0]).toEqual({
      endpoint: 'https://web.push.apple.com/awa',
      charge: { titre: 'Ton cours est prêt', corps: expect.any(String), lien: '/cours/c1', id: 'n1' },
    })
    expect(bilan).toEqual({ reservees: 1, envoyes: 1, jetonsSupprimes: 1 })
    expect(supprimes).toEqual(['https://web.push.apple.com/vieux'])
  })
})
