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

export const handlers: Handlers = {
  notify: notifyHandler,
}
