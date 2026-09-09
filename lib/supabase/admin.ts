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
export class ConfigurationManquante extends Error {
  constructor(variable: string) {
    super(
      `${variable} n'est pas configurée. Les opérations à privilèges — ` +
        'parrainage, paiements, file de jobs — ne peuvent pas aboutir. ' +
        'Voir docs/SUPABASE.md § 2.',
    )
    this.name = 'ConfigurationManquante'
  }
}

export function createAdminClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const cle = process.env.SUPABASE_SERVICE_ROLE_KEY

  // Le message natif de supabase-js est « supabaseKey is required. » : il ne
  // dit ni laquelle, ni où la mettre. Celui-ci se lit dans un journal.
  if (!url) throw new ConfigurationManquante('NEXT_PUBLIC_SUPABASE_URL')
  if (!cle) throw new ConfigurationManquante('SUPABASE_SERVICE_ROLE_KEY')

  return createClient<Database>(url, cle, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
}
