import { z } from 'zod'
import type { CorrectionPayload } from '@/lib/ai/schemas'
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
 * Restent à écrire : `ingest_course`, `generate_questions` et `verify_card`,
 * qui dépendent des écrans correspondants.
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

export const handlers: Handlers = {
  notify: notifyHandler,
  correct_copy: correctCopyHandler,
}
