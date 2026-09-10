import { z } from 'zod'
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
 * Restent à écrire : `ingest_course`, `generate_questions`, `correct_copy` et
 * `verify_card`, qui dépendent des écrans correspondants.
 */

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
 * Correction automatique de copie par DeepSeek vision.
 *
 * 1. Récupère les images depuis Supabase Storage
 * 2. Envoie à DeepSeek vision pour analyse
 * 3. Parse le résultat (note, rubrique, feedback)
 * 4. Met à jour la table corrections
 */
const correctCopySchema = z.object({
  correction_id: z.string().uuid(),
  user_id: z.string().uuid(),
  storage_paths: z.array(z.string()),
})

export const correctCopyHandler = async (job: Job, ctx: JobContext): Promise<void> => {
  const parsed = correctCopySchema.safeParse(job.payload)
  if (!parsed.success) {
    throw new PermanentJobError(
      `Charge utile invalide : ${parsed.error.issues
        .map((i) => `${i.path.join('.') || '(racine)'} ${i.message}`)
        .join(' ; ')}`,
    )
  }

  const { correction_id, storage_paths } = parsed.data

  try {
    // 1. Récupère les images
    const { createClient } = await import('@/lib/supabase/server')
    const { createAdminClient } = await import('@/lib/supabase/admin')

    const admin = createAdminClient()
    const images: Array<{ url: string; mediaType: 'image/jpeg' | 'image/png' }> = []

    for (const path of storage_paths) {
      try {
        const { data } = admin.storage
          .from('corrections')
          .getPublicUrl(path)

        if (data?.publicUrl) {
          images.push({
            url: data.publicUrl,
            mediaType: path.includes('jpg') || path.includes('jpeg') ? 'image/jpeg' : 'image/png',
          })
        }
      } catch (e) {
        ctx.log(`Cannot get public URL for ${path}`, { error: String(e) })
      }
    }

    if (images.length === 0) {
      throw new Error('No images retrieved from storage')
    }

    // 2. Prépare le prompt pour l'IA
    const prompt = `Tu es un professeur expert chargé de corriger une copie d'examen.

Tâches :
1. Analyser la/les image(s) fournie(s)
2. Évaluer les réponses en fonction du sujet (si fourni)
3. Attribuer une note sur 20
4. Fournir une rubrique d'évaluation détaillée
5. Donner un retour constructif

IMPORTANT: Réponds UNIQUEMENT en JSON valide, sans texte avant ou après. Format:
{
  "grade": 15,
  "rubric": {
    "comprehension": {"score": 8, "comment": "..."},
    "expression": {"score": 7, "comment": "..."},
    "organisation": {"score": 9, "comment": "..."}
  },
  "feedback": {
    "strengths": "...",
    "improvements": "...",
    "overall": "..."
  }
}

Sois juste, objectif, et constructif.`

    // 3. Appelle DeepSeek vision
    const response = await fetch('https://api.deepseek.com/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${process.env.DEEPSEEK_API_KEY}`,
      },
      body: JSON.stringify({
        model: 'deepseek-v4-flash-vision-exp',
        messages: [
          {
            role: 'user',
            content: [
              { type: 'text', text: prompt },
              ...images.map((img) => ({
                type: 'image_url',
                image_url: { url: img.url, detail: 'high' },
              })),
            ],
          },
        ],
        temperature: 0.3,
        max_tokens: 2000,
      }),
      signal: ctx.signal,
    })

    if (!response.ok) {
      throw new Error(`DeepSeek returned ${response.status}`)
    }

    const data = (await response.json()) as {
      choices?: Array<{ message?: { content?: string } }>
    }
    const content = data.choices?.[0]?.message?.content

    if (!content) {
      throw new Error('No response from DeepSeek')
    }

    // 4. Parse le JSON
    let correction_data: {
      grade: number
      rubric: Record<string, { score: number; comment: string }>
      feedback: Record<string, string>
    }

    try {
      correction_data = JSON.parse(content)
    } catch (e) {
      // Essaie d'extraire JSON du texte
      const jsonMatch = content.match(/\{[\s\S]*\}/)
      if (!jsonMatch) {
        throw new Error('Invalid JSON in response')
      }
      correction_data = JSON.parse(jsonMatch[0])
    }

    // Valide
    if (
      typeof correction_data.grade !== 'number' ||
      correction_data.grade < 0 ||
      correction_data.grade > 20
    ) {
      throw new Error('Invalid grade')
    }

    // 5. Met à jour la table corrections
    const { error: updateError } = await admin
      .from('corrections')
      .update({
        status: 'ready',
        grade: Math.round(correction_data.grade),
        rubric: correction_data.rubric,
        feedback: correction_data.feedback,
        model_used: 'deepseek-v4-flash-vision-exp',
      })
      .eq('id', correction_id)

    if (updateError) {
      throw new Error(`Failed to update correction: ${updateError.message}`)
    }

    ctx.log('correction completed', { correction_id, grade: correction_data.grade })
  } catch (e) {
    if (e instanceof Error && e.message.includes('signal')) {
      // Aborted, retry
      throw e
    }
    // Log mais ne retry pas les erreurs irrécupérables
    ctx.log('correction failed', { error: String(e) })
    throw new PermanentJobError(`Correction failed: ${String(e)}`)
  }
}

export const handlers: Handlers = {
  notify: notifyHandler,
  correct_copy: correctCopyHandler,
}
