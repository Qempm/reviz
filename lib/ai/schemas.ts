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

/**
 * Une copie corrigée.
 *
 * Les clés sont en anglais comme celles des autres sorties IA : ce sont les
 * noms que le modèle doit écrire, pas des identifiants de notre code.
 */
const copieCorrigeeSchema = z.object({
  isReadable: z.literal(true),
  grade: z.number().min(0),
  maxGrade: z.number().positive(),
  rubric: z.array(rubricLineSchema).min(1).max(30),
  feedback: z.object({
    summary: z.string().min(1).max(2000),
    strengths: z.array(z.string().max(500)).max(10).default([]),
    improvements: z.array(z.string().max(500)).max(10).default([]),
  }),
  /**
   * Les numéros des chapitres du cours à revoir, d'après la copie. Rendu
   * seulement quand la consigne porte le cours (`lib/ai/consignes.ts`) ; un
   * numéro inconnu est écarté au rattachement, pas ici.
   */
  chapters: z.array(z.number().int().min(0)).max(10).default([]),
  /** Les notions manquées ou confondues, en quelques mots. */
  missedNotions: z.array(z.string().max(200)).max(10).default([]),
})

/**
 * Une copie qu'on n'arrive pas à lire.
 *
 * Même raisonnement que `studentCardPayloadSchema.isReadable` plus bas : une
 * photo floue prise à 23 h est le cas d'échec le plus fréquent, et c'est une
 * **réponse valide**, pas un échec de validation. Sans cette branche, une
 * mauvaise photo brûle toute la chaîne de secours — trois appels payés — puis
 * laisse la correction en échec permanent, alors que l'étudiant n'a qu'à
 * reprendre la photo à la lumière.
 */
const copieIllisibleSchema = z.object({
  isReadable: z.literal(false),
  /** Ce qu'on dira à l'étudiant : flou, cadrage, obscurité, page blanche. */
  reason: z.string().min(1).max(500),
})

export const correctionPayloadSchema = z.preprocess(
  (brut) => {
    // Un modèle qui rend une note sans se prononcer sur la lisibilité l'a de
    // fait jugée lisible. Faire basculer toute la chaîne pour un booléen
    // absent coûterait trois appels pour rien — même arbitrage que le
    // `"options": null` des questions ouvertes.
    if (
      brut !== null &&
      typeof brut === 'object' &&
      !('isReadable' in brut) &&
      'grade' in brut
    ) {
      return { ...brut, isReadable: true }
    }
    return brut
  },
  z
    .discriminatedUnion('isReadable', [
      copieCorrigeeSchema,
      copieIllisibleSchema,
    ])
    .superRefine((c, ctx) => {
      if (!c.isReadable) return

      // Miroir de la contrainte SQL corrections_note_dans_le_bareme : ce qui
      // passe ici doit passer l'insertion.
      if (c.grade > c.maxGrade) {
        ctx.addIssue({
          code: 'custom',
          message: 'La note dépasse le barème.',
          path: ['grade'],
        })
      }

      if (c.rubric.some((l) => l.points > l.maxPoints)) {
        ctx.addIssue({
          code: 'custom',
          message: 'Une ligne de barème dépasse son maximum.',
          path: ['rubric'],
        })
      }
    }),
)

export type CorrectionPayload = z.infer<typeof correctionPayloadSchema>

/** La branche lisible, quand l'appelant a déjà écarté l'autre. */
export type CopieCorrigee = z.infer<typeof copieCorrigeeSchema>

/**
 * Transcription d'une page photographiée.
 *
 * Le public visé photographie le tableau ou le polycopié d'un camarade : c'est
 * le format de dépôt le plus courant, et le seul que ni `unpdf` ni `mammoth`
 * ne savent lire. Même forme que la correction et la carte étudiante : une
 * photo floue est une **réponse valide**, pas un échec de validation qui
 * brûlerait toute la chaîne de secours.
 */
const pageLisibleSchema = z.object({
  isReadable: z.literal(true),
  /**
   * Le texte, tel qu'il est sur la page.
   *
   * Plafonné à 40 000 caractères, ce qui laisse largement de quoi transcrire
   * une page dense et borne ce qui entre en base.
   */
  text: z.string().min(1).max(40000),
})

const pageIllisibleSchema = z.object({
  isReadable: z.literal(false),
  reason: z.string().min(1).max(500),
})

export const transcriptionPayloadSchema = z.preprocess(
  (brut) => {
    // Un modèle qui rend du texte sans se prononcer l'a de fait jugée
    // lisible — même arbitrage que pour la correction.
    if (
      brut !== null &&
      typeof brut === 'object' &&
      !('isReadable' in brut) &&
      'text' in brut
    ) {
      return { ...brut, isReadable: true }
    }
    return brut
  },
  z.discriminatedUnion('isReadable', [pageLisibleSchema, pageIllisibleSchema]),
)

export type TranscriptionPayload = z.infer<typeof transcriptionPayloadSchema>

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
  /**
   * Ce que le modèle dit de sa propre lecture du numéro d'étudiant.
   *
   * **Défaut à zéro**, et c'est le point : la consigne demande à un modèle qui
   * ne lit rien de répondre `{"isReadable": false, "reason": "…"}` — sans
   * confiance, puisqu'il n'a rien lu. Exiger le champ faisait échouer la
   * validation sur cette réponse-là, donc basculer sur les deux fournisseurs
   * suivants, donc payer trois appels pour une photo floue, avant de finir en
   * échec permanent. C'est exactement ce que `isReadable` existe pour éviter.
   */
  confidence: z.number().min(0).max(1).default(0),
  /** Ce qu'on dira à l'étudiant quand la photo est inexploitable. */
  reason: z.string().max(500).nullable().default(null),
})

export type StudentCardPayload = z.infer<typeof studentCardPayloadSchema>

/** Schémas indexés par tâche, pour le routage. */
export const TASK_SCHEMAS = {
  questions: questionsPayloadSchema,
  flashcards: flashcardsPayloadSchema,
  exam_predictions: questionsPayloadSchema,
  correction: correctionPayloadSchema,
  transcription: transcriptionPayloadSchema,
  student_card: studentCardPayloadSchema,
} as const

export type AiTask = keyof typeof TASK_SCHEMAS
