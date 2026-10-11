import { describe, expect, it } from 'vitest'
import { tuteurTourSchema } from '@/lib/ai/schemas'
import type { EtatAcces } from '@/lib/payments/subscriptions'
import {
  BUDGET_CHAPITRE,
  consigneTuteur,
  entreeRepondre,
  messagesTuteur,
  peutVerifier,
  points,
  QUESTIONS_PAR_SESSION,
  REPONSE_MAX,
  scoreDe,
  suiteAttendue,
  TUTEUR_PAR_JOUR,
  verdictDe,
  type ContexteTuteur,
  type Echange,
} from './tuteur'

const ACTIF: EtatAcces = {
  state: 'active',
  endsAt: new Date('2026-11-01'),
  daysLeft: 20,
  correctionsLeft: 3,
  subjectsLimit: 5,
  packCodes: ['partiel'],
}
const EXPIRE: EtatAcces = { state: 'expired', expiredAt: new Date('2026-10-01') }
const AUCUN: EtatAcces = { state: 'none' }

const CONTEXTE: ContexteTuteur = {
  coursTitre: 'Droit constitutionnel',
  matiere: 'Droit',
  chapitreTitre: 'Le contrôle de constitutionnalité',
  chapitreTexte: 'Le contrôle a priori intervient avant la promulgation de la loi…',
}

describe('peutVerifier', () => {
  it('ouvre le tuteur à un pack actif, sans compter d’essai', () => {
    expect(peutVerifier({ acces: ACTIF, essaiUtilise: true, sessionsAujourdhui: 0 })).toEqual({
      autorise: true,
      essai: false,
    })
  })

  it('donne un essai, un seul, à qui n’a pas de pack', () => {
    expect(peutVerifier({ acces: AUCUN, essaiUtilise: false, sessionsAujourdhui: 0 })).toEqual({
      autorise: true,
      essai: true,
    })
    expect(peutVerifier({ acces: AUCUN, essaiUtilise: true, sessionsAujourdhui: 0 })).toEqual({
      autorise: false,
      raison: 'essai-utilise',
    })
  })

  it('ne rend pas l’essai quand le pack a expiré', () => {
    expect(peutVerifier({ acces: EXPIRE, essaiUtilise: true, sessionsAujourdhui: 0 })).toEqual({
      autorise: false,
      raison: 'essai-utilise',
    })
    // Mais un ancien abonné qui ne l'a jamais pris l'a encore.
    expect(peutVerifier({ acces: EXPIRE, essaiUtilise: false, sessionsAujourdhui: 0 })).toEqual({
      autorise: true,
      essai: true,
    })
  })

  it('arrête tout le monde au plafond du jour, pack compris', () => {
    expect(
      peutVerifier({ acces: ACTIF, essaiUtilise: false, sessionsAujourdhui: TUTEUR_PAR_JOUR }),
    ).toEqual({ autorise: false, raison: 'plafond-du-jour' })
    expect(
      peutVerifier({ acces: ACTIF, essaiUtilise: false, sessionsAujourdhui: TUTEUR_PAR_JOUR - 1 }),
    ).toEqual({ autorise: true, essai: false })
  })
})

describe('verdict et score', () => {
  it('compte 1 pour juste, 0,5 pour partiel', () => {
    expect(points(['juste', 'partiel', 'faux'])).toBe(1.5)
  })

  it('juge maîtrisé à partir de deux points sur trois', () => {
    expect(verdictDe(['juste', 'juste', 'faux'])).toBe('maitrise')
    expect(verdictDe(['juste', 'partiel', 'partiel'])).toBe('maitrise')
    expect(verdictDe(['juste', 'partiel', 'faux'])).toBe('a_revoir')
    expect(verdictDe(['faux', 'faux', 'faux'])).toBe('a_revoir')
  })

  it('enregistre le nombre de réponses justes', () => {
    expect(scoreDe(['juste', 'partiel', 'juste'])).toBe(2)
  })

  it('attend une question, puis le bilan après la troisième réponse', () => {
    expect(suiteAttendue(1)).toBe('question')
    expect(suiteAttendue(QUESTIONS_PAR_SESSION - 1)).toBe('question')
    expect(suiteAttendue(QUESTIONS_PAR_SESSION)).toBe('fin')
  })
})

describe('la conversation envoyée au modèle', () => {
  const historique: Echange[] = [
    { role: 'tuteur', texte: 'Quand intervient le contrôle a priori ?' },
    {
      role: 'etudiant',
      texte: 'Avant la promulgation.',
      evaluation: { niveau: 'juste', retour: 'Exact.' },
    },
    { role: 'tuteur', texte: 'Et le contrôle a posteriori ?' },
  ]

  it('garde la même consigne d’un tour à l’autre, pour le cache', () => {
    const premier = messagesTuteur({ contexte: CONTEXTE, erreurs: ['Q1 ratée'], historique: [] })
    const suivant = messagesTuteur({
      contexte: CONTEXTE,
      erreurs: ['Q1 ratée', 'Q2 ratée'],
      historique,
      reponse: 'Après, pendant un procès.',
    })
    expect(premier[0]).toEqual(suivant[0])
    expect(premier[0].role).toBe('system')
    // Les erreurs de la série vont dans le premier message de l'étudiant.
    expect(String(premier[0].content)).not.toContain('Q1 ratée')
    expect(String(premier[1].content)).toContain('Q1 ratée')
  })

  it('alterne étudiant et tuteur, et réécrit le tuteur dans son format JSON', () => {
    const m = messagesTuteur({
      contexte: CONTEXTE,
      erreurs: [],
      historique,
      reponse: 'Après, pendant un procès.',
    })
    expect(m.map((x) => x.role)).toEqual(['system', 'user', 'assistant', 'user', 'assistant', 'user'])
    expect(JSON.parse(String(m[2].content))).toEqual({
      evaluation: null,
      suite: { type: 'question', texte: 'Quand intervient le contrôle a priori ?' },
    })
    expect(JSON.parse(String(m[4].content)).evaluation).toEqual({ niveau: 'juste', retour: 'Exact.' })
    expect(String(m[5].content)).toContain('question 2 sur 3')
    expect(String(m[5].content)).toContain('pose la question 3')
  })

  it('demande le bilan après la dernière réponse', () => {
    const complet: Echange[] = [
      ...historique,
      { role: 'etudiant', texte: 'Pendant un procès.', evaluation: { niveau: 'partiel', retour: '…' } },
      { role: 'tuteur', texte: 'Qui contrôle ?' },
    ]
    const m = messagesTuteur({ contexte: CONTEXTE, erreurs: [], historique: complet, reponse: 'La Cour.' })
    expect(String(m[m.length - 1].content)).toContain('termine avec le bilan')
  })

  it('borne le texte du chapitre', () => {
    const long = consigneTuteur({ ...CONTEXTE, chapitreTexte: 'mot '.repeat(20_000) })
    expect(long.length).toBeLessThan(BUDGET_CHAPITRE + 4000)
  })
})

describe('entrées et sorties validées', () => {
  it('refuse une réponse vide ou trop longue', () => {
    const id = '5f0c6d2e-8a51-4b0f-9a6b-1c2d3e4f5a6b'
    expect(entreeRepondre.safeParse({ sessionId: id, reponse: '   ' }).success).toBe(false)
    expect(entreeRepondre.safeParse({ sessionId: id, reponse: 'x'.repeat(REPONSE_MAX + 1) }).success).toBe(false)
    expect(entreeRepondre.safeParse({ sessionId: id, reponse: 'Avant la promulgation.' }).success).toBe(true)
  })

  it('accepte une question au premier tour, sans évaluation', () => {
    const r = tuteurTourSchema.safeParse({ suite: { type: 'question', texte: 'Que dit l’article 1 ?' } })
    expect(r.success && r.data.evaluation).toBe(null)
  })

  it('accepte un bilan, et refuse un niveau inconnu', () => {
    expect(
      tuteurTourSchema.safeParse({
        evaluation: { niveau: 'juste', retour: 'Bien.' },
        suite: { type: 'fin', verdict: 'maitrise', bilan: 'Tu maîtrises.', aRevoir: [] },
      }).success,
    ).toBe(true)
    expect(
      tuteurTourSchema.safeParse({
        evaluation: { niveau: 'presque', retour: 'Bien.' },
        suite: { type: 'question', texte: 'Et ensuite ?' },
      }).success,
    ).toBe(false)
  })
})
