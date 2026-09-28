import 'server-only'
import { createClient as createSupabaseClient } from '@supabase/supabase-js'
import type { SupabaseClient, User } from '@supabase/supabase-js'
import { createClient as createClientCookies } from './server'
import type { Database } from './database.types'

/**
 * Authentification d'une requête HTTP, par jeton ou par cookie.
 *
 * Toute la couche serveur n'acceptait que des cookies : `lib/supabase/server.ts`
 * lit `cookies()` et rien, nulle part, ne regardait l'en-tête
 * `Authorization`. Une application Flutter détient un JWT, pas un bocal à
 * cookies — les routes API lui auraient toutes répondu 401.
 *
 * Le repli sur les cookies n'est pas une commodité : il permet au web de
 * continuer à fonctionner sans être touché pendant tout le portage. Les deux
 * clients agissent au nom de l'utilisateur, donc sous RLS.
 */

export type ClientReviz = SupabaseClient<Database>

/** Un appelant identifié, et le client qui parle en son nom. */
export type Appelant = {
  supabase: ClientReviz
  user: User
  /** Par quelle porte il est entré — utile aux journaux. */
  porte: 'jeton' | 'cookie'
}

/**
 * Client agissant au nom du porteur d'un jeton d'accès.
 *
 * Le jeton part dans l'en-tête `Authorization` de chaque requête PostgREST :
 * `auth.uid()` vaut donc l'identifiant du porteur et les politiques RLS
 * s'appliquent exactement comme pour une session par cookie. Aucune session
 * n'est persistée ni rafraîchie — la requête est sans lendemain, c'est au
 * client mobile de renouveler son jeton.
 */
export function createClientDepuisJeton(jeton: string): ClientReviz {
  return createSupabaseClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      global: { headers: { Authorization: `Bearer ${jeton}` } },
      auth: { persistSession: false, autoRefreshToken: false },
    },
  )
}

/** Extrait le jeton d'un en-tête `Authorization: Bearer …`. */
export function jetonDeLEnTete(request: Request): string | null {
  const brut = request.headers.get('authorization')
  if (!brut) return null

  const [schema, valeur] = brut.split(/\s+/, 2)
  if (!schema || schema.toLowerCase() !== 'bearer') return null
  if (!valeur || valeur.length < 20) return null

  return valeur
}

/**
 * Identifie l'appelant, ou renvoie `null`.
 *
 * Le jeton l'emporte sur le cookie : un appel mobile n'a pas de cookie, et un
 * appel web n'a pas d'en-tête, donc les deux ne se croisent en pratique
 * jamais. Si les deux sont présents, c'est le jeton explicite qui exprime
 * l'intention.
 *
 * `getUser(jeton)` valide la signature et l'expiration **auprès du serveur
 * d'authentification**, il ne se contente pas de décoder la charge utile. Un
 * JWT fabriqué ou périmé ne passe donc pas.
 */
/**
 * Depuis le lot D, **la porte cookie n'a plus d'appelant** : les écrans web
 * que Flutter remplace ont été retirés, et `middleware.ts` — qui renouvelait
 * le cookie à chaque requête — avec eux, puisqu'il gardait des routes qui
 * n'existent plus et redirigeait vers un `/connexion` supprimé.
 *
 * Le repli reste écrit pour deux raisons : il ne coûte rien quand il n'y a pas
 * de cookie (il rend `null`), et il documente le contrat à deux canaux que
 * décrit `docs/API.md`. Si un écran web revient un jour, il faudra remettre le
 * renouvellement du cookie avec lui — sans middleware, une session de
 * navigateur expire sans se renouveler.
 */
export async function authentifier(request: Request): Promise<Appelant | null> {
  const jeton = jetonDeLEnTete(request)

  if (jeton) {
    const supabase = createClientDepuisJeton(jeton)
    const { data, error } = await supabase.auth.getUser(jeton)
    if (error || !data.user) return null
    return { supabase, user: data.user, porte: 'jeton' }
  }

  const supabase = await createClientCookies()
  const { data, error } = await supabase.auth.getUser()
  if (error || !data.user) return null
  return { supabase, user: data.user, porte: 'cookie' }
}

/** Enveloppe de réponse commune à toutes les routes (CLAUDE.md, conventions). */
export type Enveloppe<T> = { ok: true; data: T } | { ok: false; error: string }

/** 401 uniforme, en français : ces messages atteignent l'étudiant. */
export function refusSession(): Response {
  return Response.json(
    { ok: false, error: 'Ta session a expiré. Reconnecte-toi.' },
    { status: 401 },
  )
}
