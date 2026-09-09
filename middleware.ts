import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'
import type { Database } from '@/lib/supabase/database.types'

/**
 * Rafraîchit la session à chaque requête et garde les routes.
 *
 * Le jeton Supabase expire : sans ce passage, un étudiant qui laisse l'app
 * ouverte la nuit se retrouve déconnecté au pire moment. Le middleware
 * renouvelle le cookie de façon transparente.
 */

/** Préfixes accessibles sans compte. */
const PUBLIQUES = ['/connexion', '/inscription', '/app', '/kitchen-sink']

/** Préfixes réservés aux comptes connectés. */
const PROTEGEES = ['/reviser', '/corriger', '/gains', '/profil', '/cours', '/boutique']

function estDans(prefixes: string[], chemin: string): boolean {
  return prefixes.some((p) => chemin === p || chemin.startsWith(`${p}/`))
}

export async function middleware(request: NextRequest) {
  let response = NextResponse.next({ request })

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const cle = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

  // Sans configuration, on laisse passer au lieu de renvoyer 500 sur toutes
  // les routes. Un déploiement où une variable manque doit rester lisible :
  // les pages s'affichent, l'authentification ne marche pas, et le journal
  // dit pourquoi. Les routes protégées restent inaccessibles puisque
  // personne ne peut se connecter.
  if (!url || !cle) {
    console.error(
      '[middleware] NEXT_PUBLIC_SUPABASE_URL ou NEXT_PUBLIC_SUPABASE_ANON_KEY ' +
        'est absente : session et garde de routes désactivées. Voir docs/SUPABASE.md.',
    )
    return response
  }

  const supabase = createServerClient<Database>(url, cle, {
    cookies: {
      getAll() {
        return request.cookies.getAll()
      },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value))
        response = NextResponse.next({ request })
        cookiesToSet.forEach(({ name, value, options }) =>
          response.cookies.set(name, value, options),
        )
      },
    },
  })

  // getUser et non getSession : getUser revalide le jeton auprès de Supabase.
  // getSession se contente de lire le cookie, qu'un client peut forger.
  const {
    data: { user },
  } = await supabase.auth.getUser()

  const chemin = request.nextUrl.pathname

  if (!user && estDans(PROTEGEES, chemin)) {
    const url = request.nextUrl.clone()
    url.pathname = '/connexion'
    // On mémorise la destination pour y revenir après connexion.
    url.searchParams.set('suite', chemin)
    return NextResponse.redirect(url)
  }

  if (user && estDans(PUBLIQUES, chemin) && chemin.startsWith('/connexion')) {
    const url = request.nextUrl.clone()
    url.pathname = '/'
    url.search = ''
    return NextResponse.redirect(url)
  }

  return response
}

export const config = {
  matcher: [
    /*
     * Toutes les routes sauf les fichiers statiques et les images : inutile de
     * réveiller Supabase pour servir une police.
     */
    '/((?!_next/static|_next/image|favicon.ico|manifest.json|mascotte|avatars|.*\.(?:png|jpg|jpeg|gif|webp|svg|woff2?)$).*)',
  ],
}
