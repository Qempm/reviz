/**
 * Le tuteur de maîtrise : les règles, sans base ni réseau.
 *
 * Après une série de QCM sur un chapitre, Claude pose trois questions
 * ouvertes ; l'étudiant tape ses réponses ; chacune est jugée, puis un bilan
 * conclut « maîtrisé » ou « à revoir ». Le QCM vérifie qu'on reconnaît la
 * bonne réponse ; le tuteur, qu'on sait l'expliquer.
 *
 * Arbitrage du propriétaire (11 octobre 2026) : **réservé aux packs**, avec
 * **un seul essai gratuit par compte**. La base le garantit aussi (index
 * unique partiel, déclencheur de 20 par jour), migration `20261011120000`.
 *
 * Portées en Dart dans `apps/mobile/lib/metier/tuteur.dart`, pour que l'écran
 * dise « essai gratuit » ou « réservé aux packs » sans aller-retour.
 */
import { z } from 'zod'
import type { ChatMessage } from '@/lib/ai/types'
import type { EtatAcces } from '@/lib/payments/subscriptions'

/** Questions par session. */
export const QUESTIONS_PAR_SESSION = 3

/** Sessions par jour, même avec un pack : une borne de coût. */
export const TUTEUR_PAR_JOUR = 20

/** Longueur maximale d'une réponse tapée. */
export const REPONSE_MAX = 1500

/** Place laissée au texte du chapitre dans la consigne, en caractères. */
export const BUDGET_CHAPITRE = 24_000

export const entreeDemarrer = z.object({
  courseId: z.string().uuid(),
  chapterId: z.string().uuid(),
})

export const entreeRepondre = z.object({
  sessionId: z.string().uuid(),
  reponse: z.string().trim().min(1).max(REPONSE_MAX),
})

export type RefusTuteur = 'essai-utilise' | 'plafond-du-jour'

export type DroitTuteur =
  | { autorise: true; essai: boolean }
  | { autorise: false; raison: RefusTuteur }

/**
 * L'étudiant peut-il ouvrir une session ?
 *
 * Le plafond du jour passe avant tout : même un pack ne l'ouvre pas. Avec un
 * pack actif, c'est oui. Sans pack actif (jamais eu, ou expiré), c'est l'essai
 * gratuit, une seule fois : un pack expiré ne rend pas l'essai.
 */
export function peutVerifier(opts: {
  acces: EtatAcces
  essaiUtilise: boolean
  sessionsAujourdhui: number
}): DroitTuteur {
  if (opts.sessionsAujourdhui >= TUTEUR_PAR_JOUR) {
    return { autorise: false, raison: 'plafond-du-jour' }
  }
  if (opts.acces.state === 'active') return { autorise: true, essai: false }
  if (!opts.essaiUtilise) return { autorise: true, essai: true }
  return { autorise: false, raison: 'essai-utilise' }
}

export type Niveau = 'juste' | 'partiel' | 'faux'

/** Les points d'une session : une réponse juste vaut 1, une partielle 0,5. */
export function points(niveaux: Niveau[]): number {
  return niveaux.reduce((s, n) => s + (n === 'juste' ? 1 : n === 'partiel' ? 0.5 : 0), 0)
}

/**
 * Le verdict se calcule, il ne se demande pas au modèle : deux points sur
 * trois, c'est maîtrisé. Le modèle écrit le bilan ; le seuil reste le même
 * pour tous, quel que soit le fournisseur qui a répondu.
 */
export function verdictDe(niveaux: Niveau[]): 'maitrise' | 'a_revoir' {
  return points(niveaux) >= 2 ? 'maitrise' : 'a_revoir'
}

/** Le score enregistré : le nombre de réponses justes, de 0 à 3. */
export function scoreDe(niveaux: Niveau[]): number {
  return niveaux.filter((n) => n === 'juste').length
}

export interface ContexteTuteur {
  coursTitre: string
  matiere?: string | null
  chapitreTitre: string
  chapitreTexte: string
}

/**
 * La consigne : stable d'un tour à l'autre, pour que le cache de Claude la
 * relise à 0,1 fois le prix. Rien de ce qui change pendant la session (les
 * erreurs du QCM, les réponses) ne doit y entrer.
 */
export function consigneTuteur(c: ContexteTuteur): string {
  const texte = c.chapitreTexte.replace(/\s+/g, ' ').trim()
  const extrait =
    texte.length > BUDGET_CHAPITRE ? `${texte.slice(0, BUDGET_CHAPITRE).trimEnd()}…` : texte
  return [
    'Tu es le tuteur de Reviz, une application de révision pour les élèves et les étudiants.',
    `Ton rôle : vérifier qu’un étudiant maîtrise vraiment UN chapitre, en lui posant ${QUESTIONS_PAR_SESSION} questions ouvertes, une à la fois.`,
    '',
    'Règles :',
    '- Tu tutoies l’étudiant. Tu écris en français, simplement, sans jargon inutile.',
    '- Tes questions portent UNIQUEMENT sur le chapitre ci-dessous. Rien qui n’y figure.',
    '- Une question est courte (une ou deux phrases), ouverte, et demande d’expliquer, de distinguer ou d’appliquer — pas de réciter une liste ni de répondre par oui ou non.',
    '- Les trois questions couvrent des notions différentes du chapitre, de la plus centrale à la plus fine.',
    '- Tu juges une réponse sur le fond, jamais sur l’orthographe ni le style. « juste » si l’idée essentielle y est ; « partiel » s’il en manque une partie ; « faux » sinon.',
    '- Ton retour fait deux phrases au plus : ce qui est juste, puis ce qui manque, avec la bonne réponse en peu de mots.',
    '- Tu ne donnes jamais la réponse avant que l’étudiant ait essayé.',
    '- Si l’étudiant écrit autre chose qu’une réponse (une question, une plaisanterie, un message vide de sens), tu le comptes « faux » avec bienveillance et tu continues.',
    '',
    'Tu réponds UNIQUEMENT par un objet JSON, sans texte autour :',
    '{"evaluation": null | {"niveau": "juste" | "partiel" | "faux", "retour": "…"},',
    ' "suite": {"type": "question", "texte": "…"} | {"type": "fin", "verdict": "maitrise" | "a_revoir", "bilan": "…", "aRevoir": ["notion…"]}}',
    '- `evaluation` est null au premier tour, puis juge la réponse que l’étudiant vient de donner.',
    `- Après la ${QUESTIONS_PAR_SESSION}e réponse, \`suite\` est {"type": "fin", …} : un bilan de deux ou trois phrases, encourageant, et au plus trois notions à revoir (vide si tout est juste).`,
    '',
    `Cours : ${c.coursTitre}${c.matiere ? ` (${c.matiere})` : ''}`,
    `Chapitre : ${c.chapitreTitre}`,
    '',
    '<chapitre>',
    extrait,
    '</chapitre>',
  ].join('\n')
}

/** Un échange enregistré : une question du tuteur, ou une réponse jugée. */
export type Echange =
  | { role: 'tuteur'; texte: string }
  | { role: 'etudiant'; texte: string; evaluation: { niveau: Niveau; retour: string } }

/**
 * La conversation à envoyer au modèle.
 *
 * Le premier message de l'étudiant porte les erreurs de sa dernière série,
 * pour que la première question vise ce qu'il a raté. Les tours du tuteur
 * sont réécrits dans le format JSON qu'il a produit, pour qu'il garde le fil
 * de son propre format.
 */
export function messagesTuteur(opts: {
  contexte: ContexteTuteur
  erreurs: string[]
  historique: Echange[]
  /** La réponse que l'étudiant vient de taper, s'il y en a une. */
  reponse?: string
}): ChatMessage[] {
  const intro =
    opts.erreurs.length > 0
      ? `Je viens de faire une série de QCM sur ce chapitre. J’ai raté ces questions :\n${opts.erreurs
          .map((e) => `- ${e}`)
          .join('\n')}\nCommence : pose-moi la question 1 sur ${QUESTIONS_PAR_SESSION}.`
      : `Je viens de faire une série de QCM sur ce chapitre. Commence : pose-moi la question 1 sur ${QUESTIONS_PAR_SESSION}.`

  const messages: ChatMessage[] = [
    { role: 'system', content: consigneTuteur(opts.contexte) },
    { role: 'user', content: intro },
  ]

  // L'historique alterne : question du tuteur, réponse de l'étudiant…
  let evaluationPrecedente: { niveau: Niveau; retour: string } | null = null
  for (const e of opts.historique) {
    if (e.role === 'tuteur') {
      messages.push({
        role: 'assistant',
        content: JSON.stringify({
          evaluation: evaluationPrecedente,
          suite: { type: 'question', texte: e.texte },
        }),
      })
    } else {
      evaluationPrecedente = e.evaluation
      messages.push({ role: 'user', content: e.texte })
    }
  }

  if (opts.reponse !== undefined) {
    const repondues = opts.historique.filter((e) => e.role === 'etudiant').length + 1
    const consigne =
      repondues >= QUESTIONS_PAR_SESSION
        ? `(Réponse à la question ${repondues} sur ${QUESTIONS_PAR_SESSION}. Juge-la, puis termine avec le bilan.)`
        : `(Réponse à la question ${repondues} sur ${QUESTIONS_PAR_SESSION}. Juge-la, puis pose la question ${repondues + 1}.)`
    messages.push({ role: 'user', content: `${opts.reponse}\n\n${consigne}` })
  }

  return messages
}

/** Ce qu'on attend du modèle à ce tour : une question, ou le bilan. */
export function suiteAttendue(reponsesDonnees: number): 'question' | 'fin' {
  return reponsesDonnees >= QUESTIONS_PAR_SESSION ? 'fin' : 'question'
}
