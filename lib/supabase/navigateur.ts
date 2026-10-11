import { createBrowserClient } from '@supabase/ssr'
import type { Database } from './database.types'

/**
 * Client Supabase pour le navigateur : la page de connexion de `/admin`.
 * La session vit dans des cookies, que `middleware.ts` renouvelle et que
 * les composants serveur relisent (`lib/supabase/server.ts`).
 */
export function createClientNavigateur() {
  return createBrowserClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
  )
}
