import { describe, expect, it } from 'vitest'
import {
  correctionPayloadSchema,
  flashcardsPayloadSchema,
  questionsPayloadSchema,
  studentCardPayloadSchema,
} from './schemas'

const mcq = {
  type: 'mcq',
  statement: 'Quel organe contrôle la constitutionnalité des lois ?',
  options: ['La Cour suprême', 'La Cour constitutionnelle'],
  answer: 'La Cour constitutionnelle',
}

describe('questions', () => {
  it('accepte un QCM et applique la probabilité par défaut', () => {
    const r = questionsPayloadSchema.safeParse({ questions: [mcq] })
    expect(r.success).toBe(true)
    if (r.success) expect(r.data.questions[0].probability).toBe('medium')
  })

  it('refuse un QCM à moins de deux propositions', () => {
    const r = questionsPayloadSchema.safeParse({
      questions: [{ ...mcq, options: ['seule'] }],
    })
    expect(r.success).toBe(false)
  })

  it('accepte une question ouverte sans propositions', () => {
    const r = questionsPayloadSchema.safeParse({
      questions: [
        { type: 'open', statement: 'Expose la séparation des pouvoirs.', answer: '…' },
      ],
    })
    expect(r.success).toBe(true)
  })

  it('refuse une question ouverte porteuse de propositions', () => {
    const r = questionsPayloadSchema.safeParse({
      questions: [
        { type: 'open', statement: 'Expose…', answer: '…', options: ['a', 'b'] },
      ],
    })
    // La contrainte SQL questions_options_coherentes exige options IS NULL.
    expect(r.success).toBe(false)
  })

  it('accepte une question ouverte avec options à null', () => {
    // Les modèles rendent volontiers `null` plutôt que d'omettre la clé.
    // Le comportement est verrouillé ici : une montée de version de Zod qui
    // le changerait ferait basculer de fournisseur pour rien, et le coût
    // serait invisible.
    const r = questionsPayloadSchema.safeParse({
      questions: [
        { type: 'open', statement: 'Expose…', answer: '…', options: null },
      ],
    })
    expect(r.success).toBe(true)
  })

  it('refuse un type inconnu', () => {
    const r = questionsPayloadSchema.safeParse({
      questions: [{ type: 'vrai_faux', statement: 'x', answer: 'y' }],
    })
    expect(r.success).toBe(false)
  })

  it('refuse au-delà du plafond de 200 questions par cours', () => {
    const r = questionsPayloadSchema.safeParse({
      questions: Array.from({ length: 201 }, () => mcq),
    })
    expect(r.success).toBe(false)
  })
})

describe('fiches', () => {
  it('accepte une fiche recto-verso', () => {
    expect(
      flashcardsPayloadSchema.safeParse({
        flashcards: [{ front: 'Bicaméralisme', back: 'Deux chambres.' }],
      }).success,
    ).toBe(true)
  })

  it('refuse un verso vide', () => {
    expect(
      flashcardsPayloadSchema.safeParse({
        flashcards: [{ front: 'Bicaméralisme', back: '' }],
      }).success,
    ).toBe(false)
  })
})

describe('correction', () => {
  const valide = {
    grade: 14,
    maxGrade: 20,
    rubric: [
      { criterion: 'Introduction', points: 3, maxPoints: 4 },
      { criterion: 'Développement', points: 8, maxPoints: 12 },
    ],
    feedback: { summary: 'Copie solide.', strengths: ['Plan clair'], improvements: [] },
  }

  it('accepte une correction cohérente', () => {
    expect(correctionPayloadSchema.safeParse(valide).success).toBe(true)
  })

  it('refuse une note au-dessus du barème', () => {
    const r = correctionPayloadSchema.safeParse({ ...valide, grade: 21 })
    expect(r.success).toBe(false)
  })

  it('refuse une ligne de barème dépassant son maximum', () => {
    const r = correctionPayloadSchema.safeParse({
      ...valide,
      rubric: [{ criterion: 'Introduction', points: 9, maxPoints: 4 }],
    })
    expect(r.success).toBe(false)
  })

  it('complète les listes de retour absentes', () => {
    const r = correctionPayloadSchema.safeParse({
      ...valide,
      feedback: { summary: 'Copie solide.' },
    })
    expect(r.success).toBe(true)
    if (r.success) {
      expect(r.data.feedback.strengths).toEqual([])
      expect(r.data.feedback.improvements).toEqual([])
    }
  })
})

describe('carte étudiante', () => {
  it('accepte une carte illisible : c’est un rejet propre, pas une erreur', () => {
    const r = studentCardPayloadSchema.safeParse({
      isReadable: false,
      confidence: 0.1,
    })
    expect(r.success).toBe(true)
    if (r.success) expect(r.data.fullName).toBeNull()
  })

  it('accepte une carte complète', () => {
    const r = studentCardPayloadSchema.safeParse({
      isReadable: true,
      fullName: 'Moussa Konaté',
      university: 'UAC',
      faculty: 'FADESP',
      studentId: '21A0342',
      expiresOn: '2027-09-30',
      confidence: 0.94,
    })
    expect(r.success).toBe(true)
  })

  it('refuse une date de validité mal formée', () => {
    const r = studentCardPayloadSchema.safeParse({
      isReadable: true,
      expiresOn: '30/09/2027',
      confidence: 0.9,
    })
    expect(r.success).toBe(false)
  })

  it('refuse une confiance hors bornes', () => {
    expect(
      studentCardPayloadSchema.safeParse({ isReadable: true, confidence: 1.4 })
        .success,
    ).toBe(false)
  })

  it('accepte les champs absents mis à null par le modèle', () => {
    // Les modèles rendent volontiers `null` là où le schéma attend une
    // absence : les deux doivent passer, sinon on bascule de fournisseur
    // pour une différence sans portée.
    const r = studentCardPayloadSchema.safeParse({
      isReadable: true,
      fullName: null,
      university: null,
      faculty: null,
      studentId: null,
      expiresOn: null,
      confidence: 0.5,
    })
    expect(r.success).toBe(true)
  })
})
