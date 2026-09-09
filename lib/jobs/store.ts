import { createAdminClient } from '@/lib/supabase/admin'
import type { Database } from '@/lib/supabase/database.types'
import type { JobStore } from './runner'
import type { Job, JobPayload, JobType } from './types'

/**
 * Magasin Supabase de la file.
 *
 * Écrit avec le rôle de service : `jobs` n'a aucune politique RLS, elle est
 * fermée au client (supabase/migrations/20260908120600_rls.sql).
 */

/**
 * La ligne telle que la base la définit, et non une copie écrite à la main :
 * un écart entre le schéma et ce fichier devient une erreur de compilation.
 */
type LigneJob = Database['public']['Tables']['jobs']['Row']

export function versJob(ligne: LigneJob): Job {
  return {
    id: ligne.id,
    type: ligne.type,
    payload: (ligne.payload ?? {}) as JobPayload,
    status: ligne.status,
    attempts: ligne.attempts,
    lastError: ligne.last_error,
    runAfter: new Date(ligne.run_after),
    createdAt: new Date(ligne.created_at),
    startedAt: ligne.started_at ? new Date(ligne.started_at) : null,
    finishedAt: ligne.finished_at ? new Date(ligne.finished_at) : null,
  }
}

export function createSupabaseJobStore(): JobStore {
  const supabase = createAdminClient()

  return {
    async claim(batchSize, staleAfterMinutes) {
      // La prise passe par une fonction SQL : `for update skip locked` évite
      // qu'un job parte deux fois si deux passages du cron se chevauchent.
      const { data, error } = await supabase.rpc('claim_jobs', {
        batch_size: batchSize,
        stale_after: `${staleAfterMinutes} minutes`,
      })

      if (error) throw new Error(`Prise de jobs impossible : ${error.message}`)
      return (data ?? []).map(versJob)
    },

    async markDone(id) {
      const { error } = await supabase
        .from('jobs')
        .update({ status: 'done', finished_at: new Date().toISOString(), last_error: null })
        .eq('id', id)

      if (error) throw new Error(`Clôture du job ${id} impossible : ${error.message}`)
    },

    async markFailed(id, lastError) {
      const { error } = await supabase
        .from('jobs')
        .update({
          status: 'failed',
          finished_at: new Date().toISOString(),
          last_error: lastError,
        })
        .eq('id', id)

      if (error) throw new Error(`Abandon du job ${id} impossible : ${error.message}`)
    },

    async requeue(id, runAfter, lastError) {
      const { error } = await supabase
        .from('jobs')
        .update({
          status: 'queued',
          run_after: runAfter.toISOString(),
          last_error: lastError,
          started_at: null,
        })
        .eq('id', id)

      if (error) throw new Error(`Remise en file du job ${id} impossible : ${error.message}`)
    },
  }
}

/** Met un job en file. À appeler depuis les Server Actions et les webhooks. */
export async function enqueueJob(opts: {
  type: JobType
  payload?: JobPayload
  runAfter?: Date
}): Promise<string> {
  const supabase = createAdminClient()

  const { data, error } = await supabase
    .from('jobs')
    .insert({
      type: opts.type,
      payload: opts.payload ?? {},
      run_after: (opts.runAfter ?? new Date()).toISOString(),
    })
    .select('id')
    .single()

  if (error) throw new Error(`Mise en file impossible : ${error.message}`)
  return data.id
}
