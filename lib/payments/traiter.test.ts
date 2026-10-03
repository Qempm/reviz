import { beforeEach, describe, expect, it, vi } from 'vitest'

const attribuerXp = vi.fn(async () => 500)
vi.mock('@/lib/xp/attribuer', () => ({ attribuerXp }))

import { traiterTransaction } from './traiter'

/**
 * Une base en mémoire, juste assez pour `traiterTransaction` : des lectures
 * filtrées par `eq`, un comptage `head`, et la RPC `enregistrer_paiement`
 * dont on garde les arguments.
 */
function fausseBase(opts: { xpParrain: number; ambassadeur?: boolean; dejaRecompense?: boolean }) {
  const rpc = vi.fn(async (_nom: string, _args: Record<string, unknown>) => ({
    data: { resultat: 'ok' },
    error: null,
  }))

  const lignes: Record<string, Array<Record<string, unknown>>> = {
    payments: [
      { id: 'pay-1', user_id: 'filleul', pack_code: 'controle', amount_fcfa: 1500, status: 'pending', provider: 'fedapay', provider_ref: 'tx-1' },
    ],
    packs: [{ code: 'controle', duration_days: 7, corrections_included: 3, subjects_limit: 2 }],
    profiles: [
      { id: 'filleul', referred_by: 'parrain', verification_status: 'verified' },
      { id: 'parrain', is_ambassador: opts.ambassadeur ?? false, xp_total: opts.xpParrain },
    ],
    referrals: [{ referrer_id: 'parrain', referred_id: 'filleul', first_payment_at: null }],
    xp_events: opts.dejaRecompense
      ? [{ id: 'x', user_id: 'parrain', reason: 'referral', reference_id: 'filleul' }]
      : [],
  }

  const admin = {
    rpc,
    from(table: string) {
      const filtres: Array<[string, unknown]> = []
      let tete = false
      const filtrer = () =>
        (lignes[table] ?? []).filter((l) => filtres.every(([c, v]) => l[c] === v))
      const constructeur = {
        select(_colonnes: string, o?: { head?: boolean }) {
          tete = Boolean(o?.head)
          return constructeur
        },
        eq(colonne: string, valeur: unknown) {
          filtres.push([colonne, valeur])
          return constructeur
        },
        async maybeSingle() {
          return { data: filtrer()[0] ?? null, error: null }
        },
        then(resoudre: (r: unknown) => unknown) {
          return Promise.resolve(
            tete ? { count: filtrer().length, error: null } : { data: filtrer(), error: null },
          ).then(resoudre)
        },
      }
      return constructeur
    },
  }

  return { admin: admin as never, rpc }
}

describe('traiterTransaction — parrainage et seuil de 3 000 XP', () => {
  beforeEach(() => attribuerXp.mockClear())

  it('sous le seuil : aucune commission, mais les 500 XP du filleul', async () => {
    const { admin, rpc } = fausseBase({ xpParrain: 1200 })
    const issue = await traiterTransaction(admin, { reference: 'tx-1', statut: 'approved', brut: {} })

    expect(issue).toEqual({ ok: true, motif: 'traite' })
    const args = rpc.mock.calls[0]![1]
    expect(args.p_parrain).toBeUndefined()
    expect(args.p_commission_fcfa).toBeUndefined()
    expect(attribuerXp).toHaveBeenCalledWith({
      userId: 'parrain',
      gains: [{ reason: 'referral', amount: 500 }],
      referenceId: 'filleul',
    })
  })

  it('au seuil : la commission part, et les 500 XP aussi', async () => {
    const { admin, rpc } = fausseBase({ xpParrain: 3000 })
    await traiterTransaction(admin, { reference: 'tx-1', statut: 'approved', brut: {} })

    const args = rpc.mock.calls[0]![1]
    expect(args.p_parrain).toBe('parrain')
    expect(args.p_commission_fcfa).toBe(375)
    expect(attribuerXp).toHaveBeenCalledTimes(1)
  })

  it('un ambassadeur touche sa commission sans les 3 000 XP', async () => {
    const { admin, rpc } = fausseBase({ xpParrain: 0, ambassadeur: true })
    await traiterTransaction(admin, { reference: 'tx-1', statut: 'approved', brut: {} })

    expect(rpc.mock.calls[0]![1].p_commission_fcfa).toBe(525)
  })

  it('les 500 XP ne se versent qu’une fois par filleul', async () => {
    const { admin } = fausseBase({ xpParrain: 1200, dejaRecompense: true })
    await traiterTransaction(admin, { reference: 'tx-1', statut: 'approved', brut: {} })

    expect(attribuerXp).not.toHaveBeenCalled()
  })
})
