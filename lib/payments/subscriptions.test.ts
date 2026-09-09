import { describe, expect, it } from 'vitest'
import {
  activerPack,
  CORRECTIONS_PAR_JOUR,
  estActif,
  etatAcces,
  peutAjouterMatiere,
  peutCorriger,
  type Pack,
  type Subscription,
} from './subscriptions'

/** Grille « accessible » arbitrée le 08/09/2026, cf. la migration de seed. */
const PACKS: Record<string, Pack> = {
  decouverte: {
    code: 'decouverte',
    durationDays: 3,
    correctionsIncluded: 1,
    subjectsLimit: 1,
  },
  controle: {
    code: 'controle',
    durationDays: 7,
    correctionsIncluded: 3,
    subjectsLimit: 2,
  },
  partiel: {
    code: 'partiel',
    durationDays: 30,
    correctionsIncluded: 10,
    subjectsLimit: 5,
  },
  semestre: {
    code: 'semestre',
    durationDays: 120,
    correctionsIncluded: 30,
    subjectsLimit: null,
  },
}

const T0 = new Date('2026-09-09T08:00:00Z')

describe('activation d’un pack', () => {
  it('court sur la durée du pack, à partir de maintenant', () => {
    const s = activerPack({ pack: PACKS.controle, source: 'payment', now: T0 })

    expect(s.startsAt).toEqual(T0)
    expect(s.endsAt.toISOString()).toBe('2026-09-16T08:00:00.000Z')
    expect(s.correctionsLeft).toBe(3)
    expect(s.subjectsLimit).toBe(2)
  })

  it('reporte le crédit de corrections du pack', () => {
    expect(
      activerPack({ pack: PACKS.semestre, source: 'payment', now: T0 })
        .correctionsLeft,
    ).toBe(30)
  })

  it('n’emporte aucune notion de reconduction', () => {
    const s = activerPack({ pack: PACKS.decouverte, source: 'bonus', now: T0 })
    // Règle métier 1 : l'objet ne porte volontairement aucun champ de
    // renouvellement. Ce test échouera si quelqu'un en ajoute un.
    expect(Object.keys(s).sort()).toEqual([
      'correctionsLeft',
      'endsAt',
      'packCode',
      'startsAt',
      'subjectsLimit',
    ])
  })
})

describe('expiration des packs', () => {
  const sub = (jours: number, opts: Partial<Subscription> = {}): Subscription => ({
    packCode: 'controle',
    startsAt: T0,
    endsAt: new Date(T0.getTime() + jours * 24 * 3600 * 1000),
    correctionsLeft: 3,
    subjectsLimit: 2,
    ...opts,
  })

  it('est actif pendant la fenêtre, plus après', () => {
    const s = sub(7)
    expect(estActif(s, T0)).toBe(true)
    expect(estActif(s, new Date(T0.getTime() + 6 * 86400_000))).toBe(true)
    // Borne haute exclue : à ends_at, c'est fini.
    expect(estActif(s, s.endsAt)).toBe(false)
    expect(estActif(s, new Date(s.endsAt.getTime() + 1))).toBe(false)
  })

  it('passe en lecture seule à l’expiration, sans se renouveler', () => {
    const s = sub(7)
    const apres = new Date(T0.getTime() + 30 * 86400_000)

    const acces = etatAcces([s], apres)
    expect(acces.state).toBe('expired')
    if (acces.state === 'expired') {
      expect(acces.expiredAt).toEqual(s.endsAt)
    }
  })

  it('distingue « jamais payé » de « pack expiré »', () => {
    expect(etatAcces([], T0).state).toBe('none')
    expect(
      etatAcces([sub(7)], new Date(T0.getTime() + 30 * 86400_000)).state,
    ).toBe('expired')
  })

  it('compte les jours restants au jour entier', () => {
    const acces = etatAcces([sub(7)], new Date(T0.getTime() + 36 * 3600 * 1000))
    expect(acces.state).toBe('active')
    // 7 jours moins 36 heures = 5 jours et 12 heures → 5.
    if (acces.state === 'active') expect(acces.daysLeft).toBe(5)
  })
})

describe('cumul de plusieurs packs', () => {
  const controle: Subscription = {
    packCode: 'controle',
    startsAt: T0,
    endsAt: new Date('2026-09-16T08:00:00Z'),
    correctionsLeft: 3,
    subjectsLimit: 2,
  }
  const semestre: Subscription = {
    packCode: 'semestre',
    startsAt: T0,
    endsAt: new Date('2027-01-07T08:00:00Z'),
    correctionsLeft: 30,
    subjectsLimit: null,
  }

  it('retient la fin la plus lointaine et additionne les corrections', () => {
    const acces = etatAcces([controle, semestre], T0)
    expect(acces.state).toBe('active')
    if (acces.state === 'active') {
      expect(acces.endsAt).toEqual(semestre.endsAt)
      expect(acces.correctionsLeft).toBe(33)
      expect(acces.packCodes).toHaveLength(2)
    }
  })

  it('laisse l’illimité l’emporter sur un plafond chiffré', () => {
    const acces = etatAcces([controle, semestre], T0)
    if (acces.state === 'active') expect(acces.subjectsLimit).toBeNull()
  })

  it('prend le plafond le plus généreux entre deux packs limités', () => {
    const acces = etatAcces(
      [controle, { ...controle, packCode: 'partiel', subjectsLimit: 5 }],
      T0,
    )
    if (acces.state === 'active') expect(acces.subjectsLimit).toBe(5)
  })

  it('ignore les lignes expirées dans le calcul', () => {
    // Le contrôle est fini, le semestre court toujours.
    const apres = new Date('2026-10-01T08:00:00Z')
    const acces = etatAcces([controle, semestre], apres)
    if (acces.state === 'active') {
      expect(acces.correctionsLeft).toBe(30)
      expect(acces.packCodes).toEqual(['semestre'])
    }
  })
})

describe('droit à une correction', () => {
  const actif = etatAcces(
    [
      {
        packCode: 'semestre',
        startsAt: T0,
        endsAt: new Date('2027-01-07T08:00:00Z'),
        correctionsLeft: 30,
        subjectsLimit: null,
      },
    ],
    T0,
  )

  it('autorise quand le crédit et le quota le permettent', () => {
    expect(peutCorriger({ acces: actif, correctionsAujourdhui: 2 }).autorise).toBe(
      true,
    )
  })

  it('applique le plafond de 5 par jour même en pack illimité', () => {
    const d = peutCorriger({
      acces: actif,
      correctionsAujourdhui: CORRECTIONS_PAR_JOUR,
    })
    expect(d.autorise).toBe(false)
    if (!d.autorise) expect(d.reason).toBe('plafond_journalier')
  })

  it('refuse quand le crédit du pack est épuisé', () => {
    const epuise = etatAcces(
      [
        {
          packCode: 'controle',
          startsAt: T0,
          endsAt: new Date('2026-09-16T08:00:00Z'),
          correctionsLeft: 0,
          subjectsLimit: 2,
        },
      ],
      T0,
    )
    const d = peutCorriger({ acces: epuise, correctionsAujourdhui: 0 })
    expect(d.autorise).toBe(false)
    if (!d.autorise) expect(d.reason).toBe('credit_epuise')
  })

  it('refuse sans pack et sur pack expiré, avec des motifs distincts', () => {
    const sansPack = peutCorriger({
      acces: { state: 'none' },
      correctionsAujourdhui: 0,
    })
    expect(sansPack.autorise).toBe(false)
    if (!sansPack.autorise) expect(sansPack.reason).toBe('aucun_pack')

    const expire = peutCorriger({
      acces: { state: 'expired', expiredAt: T0 },
      correctionsAujourdhui: 0,
    })
    expect(expire.autorise).toBe(false)
    if (!expire.autorise) expect(expire.reason).toBe('pack_expire')
  })
})

describe('plafond de matières', () => {
  const limite2 = etatAcces(
    [
      {
        packCode: 'controle',
        startsAt: T0,
        endsAt: new Date('2026-09-16T08:00:00Z'),
        correctionsLeft: 3,
        subjectsLimit: 2,
      },
    ],
    T0,
  )

  it('laisse ajouter sous le plafond et refuse au-delà', () => {
    expect(peutAjouterMatiere({ acces: limite2, matieresActives: 1 })).toBe(true)
    expect(peutAjouterMatiere({ acces: limite2, matieresActives: 2 })).toBe(false)
  })

  it('ne plafonne jamais un pack illimité', () => {
    const illimite = etatAcces(
      [
        {
          packCode: 'semestre',
          startsAt: T0,
          endsAt: new Date('2027-01-07T08:00:00Z'),
          correctionsLeft: 30,
          subjectsLimit: null,
        },
      ],
      T0,
    )
    expect(peutAjouterMatiere({ acces: illimite, matieresActives: 99 })).toBe(true)
  })

  it('refuse dès que l’accès n’est plus actif', () => {
    expect(
      peutAjouterMatiere({ acces: { state: 'none' }, matieresActives: 0 }),
    ).toBe(false)
  })
})
