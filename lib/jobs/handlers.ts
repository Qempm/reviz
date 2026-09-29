import { z } from 'zod'
import type {
  CorrectionPayload,
  StudentCardPayload,
  FlashcardsPayload,
  QuestionsPayload,
  TranscriptionPayload,
} from '@/lib/ai/schemas'
import type { Handlers } from './runner'
import { PermanentJobError, type Job, type JobContext } from './types'

/**
 * Traitements enregistrés.
 *
 * Un type absent de ce registre échoue en PermanentJobError : c'est
 * volontaire. Les traitements arrivent avec la fonctionnalité qu'ils servent,
 * et un job orphelin doit se voir tout de suite plutôt que d'être réessayé
 * cinq fois.
 *
 * Les cinq types de la file ont désormais leur traitement.
 */

/**
 * Durée de validité des URL signées de copie.
 *
 * Assez longue pour couvrir un appel de vision lent et un réessai, assez
 * courte pour qu'une URL qui fuirait dans un journal ne vaille plus rien.
 */
const DUREE_URL_SIGNEE_S = 600

const notifySchema = z.object({
  /** Numéro au format international, sans espaces. */
  phone: z.string().regex(/^\+?[0-9]{8,15}$/),
  template: z.string().min(1).max(100),
  variables: z.record(z.string(), z.union([z.string(), z.number()])).default({}),
})

/**
 * Notification WhatsApp via le webhook n8n.
 *
 * Reviz n'appelle jamais l'API WhatsApp directement (CLAUDE.md, section
 * Stack) : n8n porte le compte, les gabarits et la file d'envoi.
 */
export const notifyHandler = async (job: Job, ctx: JobContext): Promise<void> => {
  const url = process.env.N8N_WHATSAPP_WEBHOOK_URL
  if (!url) {
    throw new PermanentJobError('N8N_WHATSAPP_WEBHOOK_URL n’est pas configurée.')
  }

  const parsed = notifySchema.safeParse(job.payload)
  if (!parsed.success) {
    // Une charge utile malformée ne se répare pas toute seule.
    throw new PermanentJobError(
      `Charge utile invalide : ${parsed.error.issues
        .map((i) => `${i.path.join('.') || '(racine)'} ${i.message}`)
        .join(' ; ')}`,
    )
  }

  const res = await fetch(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(parsed.data),
    signal: ctx.signal,
  })

  if (!res.ok) {
    // Erreur transitoire : la politique de reprise réessaiera.
    throw new Error(
      `n8n a répondu ${res.status} : ${(await res.text().catch(() => '')).slice(0, 200)}`,
    )
  }

  ctx.log('notification envoyée', { template: parsed.data.template })
}

/**
 * Correction d'une copie photographiée.
 *
 * Réécrit : la version précédente appelait `api.deepseek.com` en direct, avec
 * son prompt en dur, son `JSON.parse` suivi d'un repli par expression
 * régulière, une vérification de note écrite à la main, aucune chaîne de
 * secours, aucun réessai sur 429 et aucun enregistrement dans `ai_usage` —
 * alors que `lib/ai/` fait tout cela, et n'était appelé que par ses propres
 * tests.
 *
 * Trois autres défauts sont corrigés ici :
 *
 *  * la sortie n'était **pas validée** : `correctionPayloadSchema` existait et
 *    n'était jamais appelé, alors que la règle métier 7 exige qu'aucune sortie
 *    IA n'entre en base sans son schéma. Le JSON produit ne correspondait
 *    d'ailleurs pas au schéma — rubrique en objet contre tableau attendu ;
 *  * la ligne `corrections` ne passait **jamais** à `processing` ni à
 *    `failed` : en cas d'échec elle restait `pending` pour toujours, et un
 *    écran qui l'interroge attendrait sans fin ;
 *  * le `catch` final transformait **toute** erreur en `PermanentJobError`, y
 *    compris un 500 passager, ce qui annulait la politique de reprise de
 *    `lib/jobs/policy.ts`.
 */
const correctCopySchema = z.object({
  correction_id: z.string().uuid(),
  user_id: z.string().uuid(),
  storage_paths: z.array(z.string()),
})

/**
 * Consigne de correction.
 *
 * Décrit le schéma Zod, et non plus une forme inventée : c'est le même
 * contrat des deux côtés. La branche « illisible » est annoncée au modèle,
 * sans quoi il inventerait une note sur une photo floue — le cas d'échec le
 * plus fréquent chez un étudiant qui photographie sa copie à 23 h.
 */
const CONSIGNE_CORRECTION = `Tu es un professeur d'université qui corrige la copie d'un étudiant.

La copie t'est donnée en photo. Un sujet peut l'accompagner.

Si tu n'arrives pas à lire la copie — photo floue, trop sombre, cadrage qui
coupe le texte, page blanche — ne devine pas de note. Réponds :
{"isReadable": false, "reason": "<ce que l'étudiant doit corriger, en une phrase, en le tutoyant>"}

Sinon, corrige et réponds :
{
  "isReadable": true,
  "grade": 14,
  "maxGrade": 20,
  "rubric": [
    {"criterion": "Compréhension du sujet", "points": 4, "maxPoints": 5, "comment": "..."},
    {"criterion": "Argumentation", "points": 6, "maxPoints": 9, "comment": "..."}
  ],
  "feedback": {
    "summary": "...",
    "strengths": ["...", "..."],
    "improvements": ["...", "..."]
  }
}

Règles :
- note sur 20, et la somme des points de la rubrique doit valoir la note ;
- chaque "points" reste inférieur ou égal à son "maxPoints" ;
- entre 2 et 8 critères, nommés en français ;
- tu t'adresses à l'étudiant en le tutoyant, tu es exigeant et encourageant ;
- rien que du JSON, sans texte avant ni après.`

export const correctCopyHandler = async (
  job: Job,
  ctx: JobContext,
): Promise<void> => {
  const parsed = correctCopySchema.safeParse(job.payload)
  if (!parsed.success) {
    throw new PermanentJobError(
      `Charge utile invalide : ${parsed.error.issues
        .map((i) => `${i.path.join('.') || '(racine)'} ${i.message}`)
        .join(' ; ')}`,
    )
  }

  const { correction_id, user_id, storage_paths } = parsed.data

  const { createAdminClient } = await import('@/lib/supabase/admin')
  const { runAiTask } = await import('@/lib/ai/routing')
  const { recordAiUsage } = await import('@/lib/ai/usage')
  const { AiError } = await import('@/lib/ai/types')
  const admin = createAdminClient()

  /**
   * Clôt la correction côté table.
   *
   * Toujours appelée avant de relancer : une ligne laissée en `pending` fait
   * attendre l'étudiant indéfiniment, ce qui est pire qu'un échec annoncé.
   */
  const marquerEchec = async (motif: string) => {
    const { error } = await admin
      .from('corrections')
      .update({ status: 'failed', feedback: { motif } })
      .eq('id', correction_id)

    if (error) {
      ctx.log('échec non consigné sur la correction', { erreur: error.message })
    }
  }

  // 1. Les images, par URL signée.
  const images: string[] = []

  for (const path of storage_paths) {
    // URL signée, et non `getPublicUrl` : le seau `copies` est privé, et
    // `getPublicUrl` ne fait que fabriquer une chaîne — il n'échoue jamais,
    // ce qui rendait le garde-fou « aucune image » incapable de se
    // déclencher alors que le fournisseur recevait des URL en 404.
    const { data, error } = await admin.storage
      .from('copies')
      .createSignedUrl(path, DUREE_URL_SIGNEE_S)

    if (error || !data?.signedUrl) {
      ctx.log('URL de copie introuvable', { path, erreur: error?.message })
      continue
    }

    images.push(data.signedUrl)
  }

  if (images.length === 0) {
    await marquerEchec(
      'Les fichiers de ta copie sont introuvables. Reprends la photo.',
    )
    throw new PermanentJobError(
      'Aucune image de copie lisible : le dépôt a échoué ou les fichiers ' +
        'ont été retirés du stockage.',
    )
  }

  // 2. La correction passe en traitement. L'écran cesse alors d'afficher
  //    « en attente » et annonce que ça tourne.
  await admin
    .from('corrections')
    .update({ status: 'processing' })
    .eq('id', correction_id)

  // 3. L'appel, par la chaîne de secours.
  let resultat
  try {
    // Le type ne se déduit pas de `task` : `runAiTask` est générique et
    // retomberait sur `unknown`. C'est bien le schéma de la tâche qui
    // valide — on ne fait ici que nommer ce qu'il rend.
    resultat = await runAiTask<CorrectionPayload>({
      task: 'correction',
      messages: [
        {
          role: 'user',
          content: [
            { type: 'text', text: CONSIGNE_CORRECTION },
            ...images.map((url) => ({
              type: 'image_url' as const,
              image_url: { url },
            })),
          ],
        },
      ],
      jobId: job.id,
      // Isolation du cache DeepSeek par étudiant. Un UUID ne porte aucune
      // donnée personnelle et respecte le format attendu.
      userId: user_id,
      recordUsage: recordAiUsage,
      signal: ctx.signal,
    })
  } catch (e) {
    if (e instanceof AiError) {
      // Aucun fournisseur n'a produit de réponse valide : réessayer plus tard
      // ne changera rien, et l'étudiant doit pouvoir reprendre sa photo.
      ctx.log('aucun fournisseur n’a corrigé la copie', {
        tentatives: e.attempts.map((a) => `${a.model}:${a.outcome}`).join(', '),
      })
      await marquerEchec(
        'La correction n’a pas abouti. Reprends la photo, ou réessaie plus tard.',
      )
      throw new PermanentJobError(e.message)
    }

    // Tout le reste — coupure réseau, échéance de l'invocation — est
    // passager : on laisse remonter pour que la politique de reprise décide.
    throw e
  }

  const correction = resultat.data

  // 4. Copie illisible : une réponse valide, pas une panne. L'étudiant n'a
  //    qu'à reprendre la photo, et on ne lui décompte rien.
  if (!correction.isReadable) {
    const { error } = await admin
      .from('corrections')
      .update({
        status: 'failed',
        model_used: resultat.model,
        feedback: { illisible: true, motif: correction.reason },
      })
      .eq('id', correction_id)

    if (error) {
      throw new Error(`Correction non consignée : ${error.message}`)
    }

    ctx.log('copie illisible', { correction_id, motif: correction.reason })
    return
  }

  // 5. La note, la rubrique et le retour.
  const { error: erreurEcriture } = await admin
    .from('corrections')
    .update({
      status: 'ready',
      grade: correction.grade,
      // Le barème vient du modèle et non d'un 20 en dur : le schéma a déjà
      // vérifié que la note ne le dépasse pas.
      max_grade: correction.maxGrade,
      rubric: correction.rubric,
      feedback: correction.feedback,
      model_used: resultat.model,
    })
    .eq('id', correction_id)

  if (erreurEcriture) {
    // Passager : la correction est faite, c'est l'écriture qui a échoué. La
    // relancer reprendra l'appel IA, mais mieux vaut payer un appel de plus
    // que perdre une correction déjà due.
    throw new Error(`Correction non consignée : ${erreurEcriture.message}`)
  }

  // 6. Le décompte, **au succès seulement**. Facturer une correction que
  //    l'IA n'a pas produite serait facturer du vide ; le plafond de cinq par
  //    jour suffit à empêcher qu'on relance sans fin.
  const { data: restant, error: erreurCredit } = await admin.rpc(
    'consommer_correction',
    { p_user: user_id },
  )

  if (erreurCredit) {
    // La correction est rendue : on ne la retire pas parce que le décompte a
    // échoué. L'écart part en journal pour être rattrapé.
    ctx.log('crédit de correction non décompté', {
      correction_id,
      erreur: erreurCredit.message,
    })
  }

  ctx.log('copie corrigée', {
    correction_id,
    note: correction.grade,
    bareme: correction.maxGrade,
    modele: resultat.model,
    correctionsRestantes: restant ?? null,
  })
}

// ------------------------------------------------- Ingestion d'un cours

/**
 * Découper un cours déposé en chapitres.
 *
 * Première moitié de la chaîne : ce traitement ne génère **aucune** question.
 * Il extrait le texte, découpe, insère les chapitres, puis enfile
 * `generate_questions`. La raison est le budget d'une fonction serverless :
 * une fonction Vercel a soixante secondes, et un cours de trente chapitres
 * demande trente appels de modèle. Tout faire ici garantissait de se faire
 * couper au milieu.
 *
 * Avant d'extraire quoi que ce soit, il regarde si **quelqu'un de la même
 * faculté a déjà fait traiter ce document** (règle métier 4). `file_hash` et
 * l'index qui va avec attendaient cet appelant depuis le premier jour. Un
 * polycopié de licence 1 circule entre des centaines d'étudiants : le premier
 * dépôt paie les appels, les suivants n'en paient aucun.
 */
const ingestCourseSchema = z.object({
  course_id: z.string().uuid(),
})

/** Consigne de transcription d'une page photographiée. */
const CONSIGNE_TRANSCRIPTION = `Tu transcris une page de cours photographiée.

Recopie le texte **tel qu'il est**. Tu ne résumes pas, tu ne reformules pas, tu
n'ajoutes rien. Garde les titres, les numérotations et les paragraphes.

Si la photo est illisible — floue, trop sombre, cadrage qui coupe le texte,
page blanche — réponds :
{"isReadable": false, "reason": "<ce que l'étudiant doit corriger, en une phrase, en le tutoyant>"}

Sinon :
{"isReadable": true, "text": "<le texte de la page>"}

Rien que du JSON, sans texte avant ni après.`

export const ingestCourseHandler = async (
  job: Job,
  ctx: JobContext,
): Promise<void> => {
  const parsed = ingestCourseSchema.safeParse(job.payload)
  if (!parsed.success) {
    throw new PermanentJobError(
      `Charge utile invalide : ${parsed.error.issues
        .map((i) => `${i.path.join('.') || '(racine)'} ${i.message}`)
        .join(' ; ')}`,
    )
  }

  const { course_id } = parsed.data

  const { createAdminClient } = await import('@/lib/supabase/admin')
  const { extraireTexte } = await import('@/lib/ai/extraction')
  const { decouperEnChapitres } = await import('@/lib/ai/decoupage')
  const admin = createAdminClient()

  /**
   * Clôt le cours en échec.
   *
   * Toujours appelée avant de relancer : un cours laissé en `processing` fait
   * attendre l'étudiant indéfiniment, ce qui est pire qu'un échec annoncé.
   * Le motif part dans `last_error` du job, que l'écran ne lit pas encore —
   * il lit le statut, qui suffit à dire « ça n'a pas marché ».
   */
  const marquerEchec = async () => {
    const { error } = await admin
      .from('courses')
      .update({ status: 'failed' })
      .eq('id', course_id)

    if (error) {
      ctx.log('échec non consigné sur le cours', { erreur: error.message })
    }
  }

  const { data: cours, error: erreurCours } = await admin
    .from('courses')
    .select('id, owner_id, title, storage_path, file_hash, status')
    .eq('id', course_id)
    .maybeSingle()

  if (erreurCours) {
    // Passager : la base a hoqueté, le job sera repris.
    throw new Error(`Lecture du cours impossible : ${erreurCours.message}`)
  }

  if (!cours) {
    throw new PermanentJobError(`Cours ${course_id} introuvable.`)
  }

  // Déjà traité — reprise d'un job, ou double mise en file.
  if (cours.status === 'ready') {
    ctx.log('cours déjà prêt, rien à faire', { course_id })
    return
  }

  // 1. Le cache par empreinte, avant tout appel payant.
  const { data: source } = await admin.rpc('cours_deja_traite', {
    p_cours: course_id,
  })

  if (source) {
    const { data: copie, error: erreurCopie } = await admin.rpc(
      'copier_contenu_cours',
      { p_source: source, p_cible: course_id },
    )

    if (erreurCopie) {
      throw new Error(`Copie du cours impossible : ${erreurCopie.message}`)
    }

    const issue = (copie as { resultat?: string } | null)?.resultat

    if (issue === 'copie') {
      ctx.log('cours repris du cache, aucun appel de modèle', {
        course_id,
        source,
        ...(copie as Record<string, unknown>),
      })
      return
    }

    // `cible-non-vide` ou `source-non-prete` : on continue par le chemin
    // normal plutôt que d'échouer sur une optimisation.
    ctx.log('cache inutilisable, traitement normal', { course_id, issue })
  }

  // 2. Le fichier.
  const { data: fichier, error: erreurFichier } = await admin.storage
    .from('cours')
    .download(cours.storage_path)

  if (erreurFichier || !fichier) {
    await marquerEchec()
    throw new PermanentJobError(
      `Fichier du cours introuvable dans le stockage : ${cours.storage_path}.`,
    )
  }

  // 3. Le texte. Une photo passe par le modèle de vision ; un PDF et un
  //    document Word, non — les lire coûte zéro appel.
  const { data: signature } = await admin.storage
    .from('cours')
    .createSignedUrl(cours.storage_path, DUREE_URL_SIGNEE_S)

  const extraction = await extraireTexte({
    octets: await fichier.arrayBuffer(),
    mime: fichier.type,
    urlSignee: signature?.signedUrl,
    transcrire: async (url) => {
      const { runAiTask } = await import('@/lib/ai/routing')
      const { recordAiUsage } = await import('@/lib/ai/usage')
      const { AiError } = await import('@/lib/ai/types')

      try {
        const resultat = await runAiTask<TranscriptionPayload>({
          task: 'transcription',
          messages: [
            {
              role: 'user',
              content: [
                { type: 'text', text: CONSIGNE_TRANSCRIPTION },
                { type: 'image_url', image_url: { url } },
              ],
            },
          ],
          jobId: job.id,
          userId: cours.owner_id ?? undefined,
          recordUsage: recordAiUsage,
          signal: ctx.signal,
        })

        return resultat.data.isReadable ? resultat.data.text : null
      } catch (e) {
        if (e instanceof AiError) {
          ctx.log('aucun fournisseur n’a transcrit la page', {
            tentatives: e.attempts
              .map((a) => `${a.model}:${a.outcome}`)
              .join(', '),
          })
          return null
        }
        throw e
      }
    },
  })

  if (!extraction.ok) {
    await marquerEchec()
    ctx.log('extraction impossible', {
      course_id,
      motif: extraction.error,
      detail: extraction.detail,
    })
    throw new PermanentJobError(
      `${extraction.error} : ${extraction.detail ?? 'sans détail'}`,
    )
  }

  // 4. Le découpage, sans réseau.
  const chapitres = decouperEnChapitres(extraction.texte, cours.title)

  if (chapitres.length === 0) {
    await marquerEchec()
    throw new PermanentJobError('Le découpage n’a produit aucun chapitre.')
  }

  const { error: erreurChapitres } = await admin.from('chapters').insert(
    chapitres.map((c) => ({
      course_id,
      index: c.index,
      title: c.title,
      text: c.text,
      token_count: c.tokenCount,
      // `embedding` reste nul : aucun fournisseur de la pile n'expose
      // d'embeddings dans docs/STACK-IA.md, et la colonne ne sert qu'à la
      // recherche sémantique — pas à la boucle de révision.
    })),
  )

  if (erreurChapitres) {
    throw new Error(`Insertion des chapitres impossible : ${erreurChapitres.message}`)
  }

  // Le nombre de pages vient du document. Le plafond SQL est de 150 : au-delà,
  // on garde le contenu déjà découpé et on n'écrit pas une valeur que la
  // contrainte refuserait.
  if (extraction.pages !== null && extraction.pages <= 150) {
    await admin
      .from('courses')
      .update({ page_count: extraction.pages })
      .eq('id', course_id)
  }

  // 5. La génération, dans un job à part.
  const { error: erreurJob } = await admin.from('jobs').insert({
    type: 'generate_questions',
    payload: { course_id },
  })

  if (erreurJob) {
    throw new Error(`Mise en file de la génération impossible : ${erreurJob.message}`)
  }

  ctx.log('cours découpé', {
    course_id,
    chapitres: chapitres.length,
    pages: extraction.pages,
    parVision: extraction.parVision,
  })
}

// --------------------------------------------- Génération des questions

/**
 * Générer les questions et les fiches d'un cours, **un lot de chapitres à la
 * fois** (`CHAPITRES_PAR_PASSAGE`, en parallèle).
 *
 * Le traitement prend les premiers chapitres sans question, les traite, et se
 * remet en file s'il en reste. C'est ce découpage qui tient dans les soixante
 * secondes d'une fonction serverless, et une coupure ne perd que le lot en
 * cours.
 *
 * Le plafond de 200 questions par cours est tenu par le trigger SQL
 * `questions_cap`. On le vérifie aussi ici, pour arrêter de générer — et donc
 * de payer — avant de se faire refuser l'insertion.
 */
const generateQuestionsSchema = z.object({
  course_id: z.string().uuid(),
})

/** Questions par chapitre. */
const QUESTIONS_PAR_CHAPITRE = 4

/** Fiches par chapitre. */
const FICHES_PAR_CHAPITRE = 4

/** Plafond SQL, répété ici pour arrêter avant le refus (règle métier 5). */
const PLAFOND_QUESTIONS = 200

function consigneQuestions(titre: string, texte: string): string {
  return `Tu prépares des questions de révision pour un étudiant d'université d'Afrique francophone.

Voici un chapitre du cours « ${titre} » :

---
${texte}
---

Écris ${QUESTIONS_PAR_CHAPITRE} questions à choix multiple sur **ce chapitre seulement**.

Règles :
- chaque question a 4 propositions, dont une seule est juste ;
- la réponse juste doit figurer mot pour mot dans les propositions ;
- tu ne poses de question que sur ce qui est écrit dans le chapitre — tu n'ajoutes rien ;
- l'explication dit pourquoi la réponse est juste, en une ou deux phrases ;
- \`probability\` vaut "high" si la notion a toutes les chances de tomber à l'examen, "medium" sinon, "low" pour un détail ;
- tu t'adresses à l'étudiant en le tutoyant.

Réponds en JSON :
{"questions": [{"type": "mcq", "statement": "…", "options": ["…", "…", "…", "…"], "answer": "…", "explanation": "…", "probability": "high"}]}

Rien que du JSON, sans texte avant ni après.`
}

function consigneFiches(titre: string, texte: string): string {
  return `Tu prépares des fiches de révision pour un étudiant d'université d'Afrique francophone.

Voici un chapitre du cours « ${titre} » :

---
${texte}
---

Écris ${FICHES_PAR_CHAPITRE} fiches sur **ce chapitre seulement**.

Une fiche, c'est une question courte au recto et sa réponse au verso. Le recto
tient en une ligne ; le verso en deux ou trois phrases. Tu ne fiches que ce qui
est écrit dans le chapitre.

Réponds en JSON :
{"flashcards": [{"front": "…", "back": "…"}]}

Rien que du JSON, sans texte avant ni après.`
}

/**
 * Chapitres traités dans une même invocation, **en parallèle**.
 *
 * Avant : un chapitre par invocation, ses deux appels l'un après l'autre, et
 * chaque invocation déclenchée par un sondage de l'écran — qui s'arrêtait au
 * bout de deux minutes. Un cours de vingt chapitres restait en plan. Cinq
 * chapitres, soit dix appels simultanés, tiennent dans le temps d'un seul
 * (DeepSeek en admet 2 500 à la fois, docs/STACK-IA.md § 1.3), et restent
 * sous les 60 s d'une fonction grâce au délai par appel de `runAiTask`.
 */
export const CHAPITRES_PAR_PASSAGE = 5

type ChapitreAGenerer = { id: string; index: number; title: string; text: string }

export const generateQuestionsHandler = async (
  job: Job,
  ctx: JobContext,
): Promise<void> => {
  const parsed = generateQuestionsSchema.safeParse(job.payload)
  if (!parsed.success) {
    throw new PermanentJobError(
      `Charge utile invalide : ${parsed.error.issues
        .map((i) => `${i.path.join('.') || '(racine)'} ${i.message}`)
        .join(' ; ')}`,
    )
  }

  const { course_id } = parsed.data

  const { createAdminClient } = await import('@/lib/supabase/admin')
  const { runAiTask } = await import('@/lib/ai/routing')
  const { recordAiUsage } = await import('@/lib/ai/usage')
  const { AiError } = await import('@/lib/ai/types')
  const admin = createAdminClient()

  const { data: cours } = await admin
    .from('courses')
    .select('id, owner_id, title, status')
    .eq('id', course_id)
    .maybeSingle()

  if (!cours) throw new PermanentJobError(`Cours ${course_id} introuvable.`)
  if (cours.status === 'ready') {
    ctx.log('cours déjà prêt, rien à générer', { course_id })
    return
  }

  // Sans le texte : on ne relit que celui des chapitres de ce passage.
  const { data: chapitres, error: erreurChapitres } = await admin
    .from('chapters')
    .select('id, index, title, questions(id)')
    .eq('course_id', course_id)
    .order('index')

  if (erreurChapitres) {
    throw new Error(`Lecture des chapitres impossible : ${erreurChapitres.message}`)
  }

  if (!chapitres || chapitres.length === 0) {
    await admin.from('courses').update({ status: 'failed' }).eq('id', course_id)
    throw new PermanentJobError(
      'Aucun chapitre : l’ingestion n’a pas abouti ou a été contournée.',
    )
  }

  const nbQuestions = (c: { questions: unknown }) =>
    (c.questions as unknown[] | null)?.length ?? 0

  const dejaGenerees = chapitres.reduce((t, c) => t + nbQuestions(c), 0)
  const restants = chapitres.filter((c) => nbQuestions(c) === 0)

  const marquerPret = async () => {
    const { error } = await admin
      .from('courses')
      .update({ status: 'ready' })
      .eq('id', course_id)
    if (error) throw new Error(`Passage en « prêt » impossible : ${error.message}`)
  }

  // Tous les chapitres ont leurs questions : le cours est prêt.
  if (restants.length === 0 || dejaGenerees >= PLAFOND_QUESTIONS) {
    await marquerPret()
    ctx.log('cours prêt', {
      course_id,
      questions: dejaGenerees,
      chapitres: chapitres.length,
      plafondAtteint: dejaGenerees >= PLAFOND_QUESTIONS,
    })
    return
  }

  const lotIds = restants.slice(0, CHAPITRES_PAR_PASSAGE).map((c) => c.id)
  const { data: textes, error: erreurTextes } = await admin
    .from('chapters')
    .select('id, index, title, text')
    .in('id', lotIds)
    .order('index')

  if (erreurTextes || !textes) {
    throw new Error(
      `Lecture du texte des chapitres impossible : ${erreurTextes?.message}`,
    )
  }

  const commun = {
    jobId: job.id,
    userId: cours.owner_id ?? undefined,
    recordUsage: recordAiUsage,
    signal: ctx.signal,
  }

  // Un chapitre, deux appels : les questions et les fiches, **en même
  // temps**. Deux appels séparés plutôt qu'un seul JSON qui porte les deux —
  // un JSON de 8 000 jetons se fait tronquer, et on perdrait les deux à la
  // fois. `allSettled` : un chapitre qui échoue ne fait pas perdre les autres.
  const genererChapitre = async (ch: ChapitreAGenerer) => {
    const [q, f] = await Promise.allSettled([
      runAiTask<QuestionsPayload>({
        task: 'questions',
        messages: [{ role: 'user', content: consigneQuestions(ch.title, ch.text) }],
        ...commun,
      }),
      runAiTask<FlashcardsPayload>({
        task: 'flashcards',
        messages: [{ role: 'user', content: consigneFiches(ch.title, ch.text) }],
        ...commun,
      }),
    ])
    return { ch, q, f }
  }

  const resultats = await Promise.all(textes.map(genererChapitre))

  // Les écritures, elles, restent en ordre : le plafond porte sur le cours
  // entier, et on n'insère que ce qui rentre.
  let place = PLAFOND_QUESTIONS - dejaGenerees
  let inserees = 0

  for (const { ch, q, f } of resultats) {
    if (q.status === 'rejected') {
      if (!(q.reason instanceof AiError)) throw q.reason
      // Aucun fournisseur n'a produit de JSON valide pour ce chapitre. On
      // n'échoue pas tout le cours pour un chapitre : on le marque d'une
      // question de secours, qui le fait sortir de la file.
      ctx.log('chapitre non généré, on passe au suivant', {
        chapitre: ch.index,
        tentatives: q.reason.attempts
          .map((a) => `${a.model}:${a.outcome}`)
          .join(', '),
      })
      await admin.from('questions').insert({
        chapter_id: ch.id,
        type: 'open',
        statement: `Relis « ${ch.title} » et résume-le en cinq lignes.`,
        answer:
          'Ta réponse t’appartient : ce chapitre n’a pas pu être découpé en ' +
          'questions automatiquement.',
        probability: 'low',
      })
      continue
    }

    const aInserer = q.value.data.questions.slice(0, Math.max(place, 0))
    if (aInserer.length > 0) {
      const { error } = await admin.from('questions').insert(
        aInserer.map((qq) => ({
          chapter_id: ch.id,
          type: qq.type,
          statement: qq.statement,
          // La contrainte SQL exige un tableau pour un QCM et NULL pour une
          // question ouverte.
          options: qq.type === 'mcq' ? qq.options : null,
          answer: qq.answer,
          explanation: qq.explanation ?? null,
          probability: qq.probability,
        })),
      )
      if (error) {
        throw new Error(`Insertion des questions impossible : ${error.message}`)
      }
      place -= aInserer.length
      inserees += aInserer.length
    }

    if (f.status === 'fulfilled') {
      const { error } = await admin.from('flashcards').insert(
        f.value.data.flashcards.slice(0, FICHES_PAR_CHAPITRE).map((fc) => ({
          chapter_id: ch.id,
          front: fc.front,
          back: fc.back,
        })),
      )
      // Les questions sont écrites : perdre les fiches d'un chapitre ne
      // justifie pas de refaire les appels.
      if (error) {
        ctx.log('fiches non insérées', { chapitre: ch.index, erreur: error.message })
      }
    } else {
      ctx.log('fiches non générées', { chapitre: ch.index })
    }
  }

  const resteApres = restants.length - textes.length
  ctx.log('lot généré', {
    course_id,
    chapitres: textes.map((c) => c.index),
    questions: inserees,
    restants: resteApres,
  })

  // Fini, ou plafond atteint : prêt tout de suite, sans un passage de plus.
  if (resteApres <= 0 || place <= 0) {
    await marquerPret()
    ctx.log('cours prêt', { course_id, questions: dejaGenerees + inserees })
    return
  }

  // Il reste des chapitres : le passage suivant les prendra. C'est
  // `lancerJobMaintenant` qui l'enchaîne, sans attendre l'écran.
  const { error: erreurJob } = await admin.from('jobs').insert({
    type: 'generate_questions',
    payload: { course_id },
  })
  if (erreurJob) throw new Error(`Remise en file impossible : ${erreurJob.message}`)
}

// --------------------------------------------- Vérification de la carte

/**
 * Lire une carte étudiante, et trancher.
 *
 * **C'est la seule barrière « un compte par personne. »** Depuis que le
 * téléphone est facultatif et non vérifié, rien d'autre n'empêche une
 * personne d'ouvrir dix comptes, de se parrainer elle-même et d'encaisser
 * 25 % de ses propres paiements (règle métier 3). Le traitement n'existait
 * pas : l'index unique sur `student_card_hash` attendait depuis le premier
 * jour qu'on l'alimente.
 *
 * La décision est dans `lib/metier/carte.ts`, testée sans réseau ; l'écriture
 * dans `enregistrer_verification_carte()`, qui transforme une violation
 * d'unicité en refus motivé plutôt qu'en job en échec.
 *
 * Ce traitement **ne supprime pas la photo**. Elle reste dans le seau
 * `cartes`, que seul son propriétaire peut lire : une vérification qu'on ne
 * peut plus revoir ne se conteste pas.
 */
const verifyCardSchema = z.object({
  profile_id: z.string().uuid(),
  storage_path: z.string().min(1),
})

/** Consigne de lecture d'une carte étudiante. */
const CONSIGNE_CARTE = `Tu lis la photo d'une carte d'étudiant d'une université d'Afrique francophone.

Tu ne devines rien. Ce que tu ne lis pas clairement, tu le rends à null.

Si la photo est inexploitable — floue, trop sombre, reflet sur le plastique,
cadrage qui coupe la carte, ce n'est pas une carte d'étudiant — réponds :
{"isReadable": false, "reason": "<ce que l'étudiant doit corriger, en une phrase, en le tutoyant>"}

Sinon :
{
  "isReadable": true,
  "fullName": "<nom et prénom tels qu'écrits, ou null>",
  "university": "<nom de l'université, ou null>",
  "faculty": "<faculté ou école, ou null>",
  "studentId": "<numéro d'étudiant ou matricule, tel qu'écrit, ou null>",
  "expiresOn": "<AAAA-MM-JJ de fin de validité, ou null>",
  "confidence": <0 à 1 : ta certitude d'avoir bien lu le numéro d'étudiant>
}

Le numéro d'étudiant est le champ qui compte : recopie-le caractère par
caractère, sans corriger ce qui te semble bizarre. Si tu n'en es pas sûr,
baisse "confidence" au lieu de deviner.

Rien que du JSON, sans texte avant ni après.`

export const verifyCardHandler = async (
  job: Job,
  ctx: JobContext,
): Promise<void> => {
  const parsed = verifyCardSchema.safeParse(job.payload)
  if (!parsed.success) {
    throw new PermanentJobError(
      `Charge utile invalide : ${parsed.error.issues
        .map((i) => `${i.path.join('.') || '(racine)'} ${i.message}`)
        .join(' ; ')}`,
    )
  }

  const { profile_id, storage_path } = parsed.data

  const { createAdminClient } = await import('@/lib/supabase/admin')
  const { runAiTask } = await import('@/lib/ai/routing')
  const { recordAiUsage } = await import('@/lib/ai/usage')
  const { AiError } = await import('@/lib/ai/types')
  const { deciderVerification } = await import('@/lib/metier/carte')
  const admin = createAdminClient()

  /** Écrit l'issue. Toujours, même en échec : sans cela le profil reste en
   * `pending` pour toujours et l'étudiant attend sans rien savoir. */
  const enregistrer = async (
    statut: 'verified' | 'pending' | 'rejected',
    empreinte?: string | null,
    valideJusqua?: Date | null,
  ) => {
    const { data, error } = await admin.rpc('enregistrer_verification_carte', {
      p_user: profile_id,
      p_statut: statut,
      p_empreinte: empreinte ?? undefined,
      p_valide_jusqua: valideJusqua?.toISOString() ?? undefined,
    })

    if (error) {
      throw new Error(`Vérification non consignée : ${error.message}`)
    }

    return (data as { resultat?: string } | null)?.resultat
  }

  const { data: signature, error: erreurUrl } = await admin.storage
    .from('cartes')
    .createSignedUrl(storage_path, DUREE_URL_SIGNEE_S)

  if (erreurUrl || !signature?.signedUrl) {
    await enregistrer('rejected')
    throw new PermanentJobError(
      `Photo de carte introuvable dans le stockage : ${storage_path}.`,
    )
  }

  let resultat
  try {
    resultat = await runAiTask<StudentCardPayload>({
      task: 'student_card',
      messages: [
        {
          role: 'user',
          content: [
            { type: 'text', text: CONSIGNE_CARTE },
            { type: 'image_url', image_url: { url: signature.signedUrl } },
          ],
        },
      ],
      jobId: job.id,
      userId: profile_id,
      recordUsage: recordAiUsage,
      signal: ctx.signal,
    })
  } catch (e) {
    if (e instanceof AiError) {
      // Aucun fournisseur n'a rendu de JSON valide. On ne refuse pas — ce
      // n'est pas la faute de l'étudiant : on laisse en attente, et le
      // message de l'écran l'invite à reprendre la photo.
      ctx.log('aucun fournisseur n’a lu la carte', {
        tentatives: e.attempts.map((a) => `${a.model}:${a.outcome}`).join(', '),
      })
      await enregistrer('pending')
      throw new PermanentJobError(e.message)
    }
    throw e
  }

  const decision = deciderVerification({ payload: resultat.data })

  switch (decision.issue) {
    case 'refusee':
      await enregistrer('rejected')
      ctx.log('carte refusée', {
        profile_id,
        motif: decision.motif,
        modele: resultat.model,
      })
      return

    case 'a_revoir':
      await enregistrer('pending', decision.empreinte)
      ctx.log('carte à revoir', {
        profile_id,
        raison: decision.raison,
        confiance: decision.lecture.confiance,
        modele: resultat.model,
      })
      return

    case 'verifiee': {
      const issue = await enregistrer(
        'verified',
        decision.empreinte,
        decision.valideJusqua,
      )

      if (issue === 'deja-utilisee') {
        // La carte appartient déjà à un autre compte : c'est exactement ce
        // que la barrière existe pour attraper. Le profil a été refusé par la
        // fonction, pas par nous.
        ctx.log('carte déjà rattachée à un autre compte', { profile_id })
        return
      }

      ctx.log('carte vérifiée', {
        profile_id,
        // Ce que le modèle a lu, pour qu'une contestation puisse se relire.
        // Jamais l'empreinte : elle **est** le secret de la barrière.
        universite: decision.lecture.universite,
        faculte: decision.lecture.faculte,
        confiance: decision.lecture.confiance,
        valideJusqua: decision.valideJusqua.toISOString(),
        modele: resultat.model,
      })
      return
    }
  }
}

export const handlers: Handlers = {
  notify: notifyHandler,
  correct_copy: correctCopyHandler,
  ingest_course: ingestCourseHandler,
  generate_questions: generateQuestionsHandler,
  verify_card: verifyCardHandler,
}
