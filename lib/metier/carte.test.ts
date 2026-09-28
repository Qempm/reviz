import { describe, expect, it } from 'vitest'
import {
  cheminDeSonDossier,
  CONFIANCE_MINIMALE,
  deciderVerification,
  empreinteCarte,
  normaliserNumero,
  VALIDITE_PAR_DEFAUT_JOURS,
} from './carte'
import type { StudentCardPayload } from '@/lib/ai/schemas'

/**
 * Tests de la vérification de carte étudiante.
 *
 * C'est la seule barrière « un compte par personne » depuis que le téléphone
 * est facultatif : sans elle, une personne ouvre dix comptes, se parraine
 * elle-même et encaisse 25 % de ses propres paiements. Les tests qui comptent
 * ici sont donc ceux du **refus** : une vérification accordée à tort ne se
 * détecte pas.
 */

const T0 = new Date('2026-09-28T12:00:00.000Z')

/** Une carte que le modèle n'a pas su lire, telle que le schéma la rend. */
const illisible = (reason: string | null = null): StudentCardPayload => ({
  isReadable: false,
  fullName: null,
  university: null,
  faculty: null,
  studentId: null,
  expiresOn: null,
  confidence: 0,
  reason,
})

const lisible = (over: Partial<StudentCardPayload> = {}): StudentCardPayload =>
  ({
    isReadable: true,
    fullName: 'KOFFI Awa',
    university: 'Université d’Abomey-Calavi',
    faculty: 'FADESP',
    studentId: '21A0453',
    expiresOn: null,
    confidence: 0.92,
    reason: null,
    ...over,
  })

describe('normalisation du numéro', () => {
  it('rend la même chaîne pour deux photos de la même carte', () => {
    // Le modèle transcrit la ponctuation comme il la voit.
    expect(normaliserNumero('21-A/0453')).toBe('21A0453')
    expect(normaliserNumero('21 a 0453')).toBe('21A0453')
    expect(normaliserNumero('  21A0453  ')).toBe('21A0453')
  })

  it('enlève les accents sans perdre la lettre', () => {
    // « é » devient « E » : le modèle peut accentuer à tort une lettre du
    // numéro, et perdre le caractère changerait l'empreinte.
    expect(normaliserNumero('Nº 21é0453')).toBe('N21E0453')
    expect(normaliserNumero('N° 21E0453')).toBe('N21E0453')
  })
})

describe('empreinte', () => {
  it('est stable et fait 64 caractères hexadécimaux', () => {
    const a = empreinteCarte('21A0453')
    expect(a).toMatch(/^[0-9a-f]{64}$/)
    expect(empreinteCarte('21-a-0453')).toBe(a)
  })

  it('diffère d’un numéro à l’autre', () => {
    expect(empreinteCarte('21A0453')).not.toBe(empreinteCarte('21A0454'))
  })

  it('refuse un numéro qui ne distingue personne', () => {
    // Sans empreinte, il n'y a pas de barrière : mieux vaut rien qu'une
    // empreinte que trois étudiants partagent.
    expect(empreinteCarte('12')).toBeNull()
    expect(empreinteCarte('—')).toBeNull()
    expect(empreinteCarte('')).toBeNull()
  })

  it('ne dépend pas de l’université', () => {
    // Ni celle lue sur la carte — le modèle écrit tantôt « UAC », tantôt
    // « Université d'Abomey-Calavi », et la même carte ouvrirait deux
    // comptes —, ni celle déclarée par l'étudiant, qu'il suffirait de changer
    // au deuxième compte pour contourner la barrière.
    expect(empreinteCarte('21A0453')).toBe(empreinteCarte('21A0453'))
  })
})

describe('ce qui est vérifié', () => {
  it('valide une carte nette avec son numéro', () => {
    const v = deciderVerification({ payload: lisible(), now: T0 })
    expect(v.issue).toBe('verifiee')
    if (v.issue !== 'verifiee') return

    expect(v.empreinte).toBe(empreinteCarte('21A0453'))
    expect(v.lecture.nom).toBe('KOFFI Awa')
  })

  it('accorde une année scolaire à défaut de date sur la carte', () => {
    const v = deciderVerification({ payload: lisible(), now: T0 })
    if (v.issue !== 'verifiee') throw new Error('vérification attendue')

    const jours =
      (v.valideJusqua.getTime() - T0.getTime()) / 86_400_000
    expect(Math.round(jours)).toBe(VALIDITE_PAR_DEFAUT_JOURS)
  })

  it('retient la date de la carte quand elle en porte une', () => {
    const v = deciderVerification({
      payload: lisible({ expiresOn: '2027-07-31' }),
      now: T0,
    })
    if (v.issue !== 'verifiee') throw new Error('vérification attendue')
    expect(v.valideJusqua.toISOString()).toBe('2027-07-31T00:00:00.000Z')
  })
})

describe('ce qui est refusé', () => {
  it('refuse une photo illisible, en disant quoi corriger', () => {
    const v = deciderVerification({
      payload: illisible('Trop de reflet sur le plastique.'),
      now: T0,
    })

    expect(v.issue).toBe('refusee')
    if (v.issue !== 'refusee') return
    expect(v.motif).toBe('illisible')
    // On reprend le motif du modèle : il est plus précis que le nôtre.
    expect(v.raison).toBe('Trop de reflet sur le plastique.')
  })

  it('retombe sur notre message quand le modèle n’en donne pas', () => {
    const v = deciderVerification({ payload: illisible(), now: T0 })
    expect(v.issue).toBe('refusee')
    if (v.issue === 'refusee') expect(v.raison).toContain('Reprends la photo')
  })

  it('refuse une carte périmée', () => {
    const v = deciderVerification({
      payload: lisible({ expiresOn: '2025-07-31' }),
      now: T0,
    })
    expect(v.issue).toBe('refusee')
    if (v.issue === 'refusee') expect(v.motif).toBe('carte-expiree')
  })

  it('refuse le jour même de l’expiration', () => {
    // Une carte valable « jusqu'au 28 septembre » ne l'est plus le 28 à midi :
    // le doute profite à la barrière, pas au dépôt.
    const v = deciderVerification({
      payload: lisible({ expiresOn: '2026-09-28' }),
      now: T0,
    })
    expect(v.issue).toBe('refusee')
  })
})

describe('ce qui attend un humain', () => {
  it('n’accorde rien sans numéro exploitable', () => {
    // Sans empreinte il n'y a pas de barrière : vérifier reviendrait à ouvrir
    // la porte à autant de comptes qu'on veut.
    for (const numero of [null, '12', '']) {
      const v = deciderVerification({
        payload: lisible({ studentId: numero }),
        now: T0,
      })
      expect(v.issue).toBe('a_revoir')
      if (v.issue === 'a_revoir') expect(v.empreinte).toBeNull()
    }
  })

  it('n’accorde rien sous le seuil de confiance', () => {
    const v = deciderVerification({
      payload: lisible({ confidence: CONFIANCE_MINIMALE - 0.01 }),
      now: T0,
    })

    expect(v.issue).toBe('a_revoir')
    // L'empreinte est tout de même calculée : elle servira à la revue, et
    // c'est elle qui détectera un doublon.
    if (v.issue === 'a_revoir') {
      expect(v.empreinte).toBe(empreinteCarte('21A0453'))
    }
  })

  it('valide pile au seuil', () => {
    const v = deciderVerification({
      payload: lisible({ confidence: CONFIANCE_MINIMALE }),
      now: T0,
    })
    expect(v.issue).toBe('verifiee')
  })

  it('refuse une carte périmée avant de regarder la confiance', () => {
    // L'ordre compte : une carte de l'an dernier lue nettement n'est pas
    // « à revoir », elle est périmée.
    const v = deciderVerification({
      payload: lisible({ expiresOn: '2025-01-01', confidence: 0.2 }),
      now: T0,
    })
    expect(v.issue).toBe('refusee')
    if (v.issue === 'refusee') expect(v.motif).toBe('carte-expiree')
  })
})

describe('le chemin de la photo', () => {
  const moi = '11111111-1111-4111-8111-111111111111'
  const toi = '22222222-2222-4222-8222-222222222222'

  it('accepte une photo de son propre dossier', () => {
    expect(cheminDeSonDossier(`${moi}/carte-1759000000000.jpg`, moi)).toBe(true)
  })

  it('refuse la photo de quelqu’un d’autre', () => {
    // Le vrai risque du dépôt : faire vérifier la carte d'un camarade
    // reviendrait à s'attribuer son empreinte, et à faire refuser la sienne
    // comme « déjà utilisée ».
    expect(cheminDeSonDossier(`${toi}/carte-1.jpg`, moi)).toBe(false)
  })

  it('refuse un préfixe qui ressemble au bon', () => {
    expect(cheminDeSonDossier(`${moi}bis/carte-1.jpg`, moi)).toBe(false)
    expect(cheminDeSonDossier(`x${moi}/carte-1.jpg`, moi)).toBe(false)
  })

  it('refuse de remonter d’un dossier', () => {
    expect(cheminDeSonDossier(`${moi}/../${toi}/carte-1.jpg`, moi)).toBe(false)
    expect(cheminDeSonDossier(`${moi}/..`, moi)).toBe(false)
  })

  it('refuse un sous-dossier et un dossier nu', () => {
    // Le traitement lit le chemin tel quel : une arborescence n'apporterait
    // rien qu'un angle mort.
    expect(cheminDeSonDossier(`${moi}/a/carte-1.jpg`, moi)).toBe(false)
    expect(cheminDeSonDossier(`${moi}/`, moi)).toBe(false)
    expect(cheminDeSonDossier(moi, moi)).toBe(false)
  })

  it('refuse l’antislash, que le stockage n’a pas à interpréter', () => {
    expect(cheminDeSonDossier(`${moi}/..\carte.jpg`, moi)).toBe(false)
  })

  it('refuse tout quand l’identifiant est vide', () => {
    // Sinon le préfixe attendu serait « / », que tout chemin absolu
    // satisferait.
    expect(cheminDeSonDossier('/carte-1.jpg', '')).toBe(false)
  })
})
