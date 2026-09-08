import { z } from 'zod'

/**
 * Schémas des sorties IA.
 *
 * Règle métier 7 : toute sortie IA stockée en base est du JSON validé par un
 * schéma Zod avant insertion. Un JSON invalide déclenche une bascule vers le
 * fournisseur suivant.
 *
 * Les schémas collent aux contraintes SQL : ce qui passe ici doit passer
 * l'insertion. Les écarts se paieraient en jobs qui échouent après avoir
 * consommé des jetons.
 */

/** Un QCM porte 2 à 6 propositions ; une question ouverte n'en a aucune. */
const questionBase = {
  statement: z.string().min(1).max(2000),
  answer: z.string().min(1).max(2000),
  explanation: z.string().max(4000).optional(),
  probability: z.enum(['high', 'medium', 'low']).default('medium'),
}

export const questionSchema = z.discriminatedUnion('type', [
  z.object({
    type: z.literal('mcq'),
    options: z.array(z.string().min(1).max(500)).min(2).max(6),
    ...questionBase,
  }),
  z.object({
    type: z.literal('open'),
    // Accepte `null` autant que l'absence de clé : les modèles rendent
    // volontiers `"options": null` pour une question ouverte. Refuser cette
    // forme ferait basculer toute la chaîne de secours — et donc payer trois
    // appels — pour une différence sans portée. Un tableau reste refusé,
    // conformément à la contrainte SQL questions_options_coherentes.
    options: z.null().optional(),
    ...questionBase,
  }),
])

export type Question = z.infer<typeof questionSchema>

/**
 * Plafond de 200 questions par cours (règle métier 5). Le trigger SQL
 * `questions_cap` refuserait la 201e : autant ne pas la générer.
 */
export const questionsPayloadSchema = z.object({
  questions: z.array(questionSchema).min(1).max(200),
})

export type QuestionsPayload = z.infer<typeof questionsPayloadSchema>

/** Fiches de révision. */
export const flashcardSchema = z.object({
  front: z.string().min(1).max(500),
  back: z.string().min(1).max(2000),
})

export const flashcardsPayloadSchema = z.object({
  flashcards: z.array(flashcardSchema).min(1).max(200),
})

export type FlashcardsPayload = z.infer<typeof flashcardsPayloadSchema>

/** Correction d'une copie photographiée. */
export const rubricLineSchema = z.object({
  criterion: z.string().min(1).max(300),
  points: z.number().min(0),
  maxPoints: z.number().positive(),
  comment: z.string().max(2000).optional(),
})

export const correctionPayloadSchema = z
  .object({
    grade: z.number().min(0),
    maxGrade: z.number().positive(),
    rubric: z.array(rubricLineSchema).min(1).max(30),
    feedback: z.object({
      summary: z.string().min(1).max(2000),
      strengths: z.array(z.string().max(500)).max(10).default([]),
      improvements: z.array(z.string().max(500)).max(10).default([]),
    }),
  })
  // Miroir de la contrainte SQL corrections_note_dans_le_bareme.
  .refine((c) => c.grade <= c.maxGrade, {
    message: 'La note dépasse le barème.',
    path: ['grade'],
  })
  .refine(
    (c) => c.rubric.every((l) => l.points <= l.maxPoints),
    { message: 'Une ligne de barème dépasse son maximum.', path: ['rubric'] },
  )

export type CorrectionPayload = z.infer<typeof correctionPayloadSchema>

/**
 * Lecture d'une carte étudiante.
 *
 * `isReadable` à false est une réponse valide : une photo floue doit produire
 * un rejet propre, pas un échec de validation qui ferait basculer vers un
 * autre fournisseur pour rien.
 */
export const studentCardPayloadSchema = z.object({
  isReadable: z.boolean(),
  fullName: z.string().max(200).nullable().default(null),
  university: z.string().max(200).nullable().default(null),
  faculty: z.string().max(200).nullable().default(null),
  studentId: z.string().max(100).nullable().default(null),
  /** Date de fin de validité au format ISO (AAAA-MM-JJ). */
  expiresOn: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .nullable()
    .default(null),
  confidence: z.number().min(0).max(1),
})

export type StudentCardPayload = z.infer<typeof studentCardPayloadSchema>

/** Schémas indexés par tâche, pour le routage. */
export const TASK_SCHEMAS = {
  questions: questionsPayloadSchema,
  flashcards: flashcardsPayloadSchema,
  exam_predictions: questionsPayloadSchema,
  correction: correctionPayloadSchema,
  student_card: studentCardPayloadSchema,
} as const

export type AiTask = keyof typeof TASK_SCHEMAS
