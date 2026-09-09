import 'server-only'
import { createClient } from '@supabase/supabase-js'
import type { Database } from './database.types'

/**
 * Client Supabase à privilèges service — contourne les politiques RLS.
 *
 * Réservé aux traitements serveur qui écrivent dans les tables financières
 * et à la file de jobs (webhook de paiement, /api/jobs/run, vérification de
 * carte étudiante). Ne jamais l'importer depuis un composant client :
 * `server-only` fait échouer le build si cela arrive.
 */
export function createAdminClient() {
  return createClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  )
}
