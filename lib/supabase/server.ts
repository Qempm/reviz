import { cookies } from 'next/headers'
import { createServerClient } from '@supabase/ssr'

/**
 * Client Supabase pour les Server Components, Server Actions et routes API.
 * Agit au nom de l'utilisateur connecté, donc soumis aux politiques RLS.
 */
export async function createClient() {
  const cookieStore = await cookies()

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll()
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options),
            )
          } catch {
            // Appelé depuis un Server Component : le rafraîchissement de
            // session est pris en charge par le middleware.
          }
        },
      },
    },
  )
}
