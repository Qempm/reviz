import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

/**
 * Retour de Google : échange le code d'autorisation contre une session.
 *
 * Route et non page : rien à afficher, on pose le cookie de session et on
 * redirige. Un écran intermédiaire ne ferait qu'ajouter un clignotement.
 */
export async function GET(request: Request) {
  const url = new URL(request.url)
  const code = url.searchParams.get('code')
  const suite = url.searchParams.get('suite')

  // Google renvoie ces deux paramètres quand l'étudiant refuse l'accès.
  const erreurGoogle = url.searchParams.get('error_description') ?? url.searchParams.get('error')
  if (erreurGoogle) {
    const echec = new URL('/connexion', url.origin)
    echec.searchParams.set('erreur', 'Connexion Google annulée.')
    return NextResponse.redirect(echec)
  }

  if (!code) {
    const echec = new URL('/connexion', url.origin)
    echec.searchParams.set('erreur', 'Lien de connexion incomplet. Réessaie.')
    return NextResponse.redirect(echec)
  }

  const supabase = await createClient()
  const { data, error } = await supabase.auth.exchangeCodeForSession(code)

  if (error || !data.user) {
    const echec = new URL('/connexion', url.origin)
    echec.searchParams.set('erreur', 'On n’a pas pu terminer la connexion. Réessaie.')
    return NextResponse.redirect(echec)
  }

  // Première connexion : on part construire le profil. Sinon on reprend là où
  // l'étudiant voulait aller.
  const { data: profil } = await supabase
    .from('profiles')
    .select('id')
    .eq('id', data.user.id)
    .maybeSingle()

  const destination = profil === null ? '/inscription' : (suite ?? '/')
  return NextResponse.redirect(new URL(destination, url.origin))
}
