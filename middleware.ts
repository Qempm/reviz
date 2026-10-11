import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

/**
 * Renouvelle la session de l'espace administrateur.
 *
 * Seul `/admin` a une session de navigateur : l'application parle au serveur
 * par jeton (`lib/supabase/jeton.ts`), sans cookie. Sans ce renouvellement,
 * le cookie expire au bout d'une heure et la page renvoie vers la connexion.
 * Limité à `/admin` et `/api/admin` par `config.matcher` : le reste du site
 * n'en paie pas le coût.
 */
export async function middleware(request: NextRequest) {
  let response = NextResponse.next({ request })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll()
        },
        setAll(aPoser) {
          aPoser.forEach(({ name, value }) => request.cookies.set(name, value))
          response = NextResponse.next({ request })
          aPoser.forEach(({ name, value, options }) => response.cookies.set(name, value, options))
        },
      },
    },
  )

  // Valide et, au besoin, rafraîchit la session (et réécrit les cookies).
  await supabase.auth.getUser()
  return response
}

export const config = {
  matcher: ['/admin/:path*', '/api/admin/:path*'],
}
