import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

/**
 * Retour de Google : échange le code d'autorisation contre une session.
 *
 * Route et non page : rien à afficher, on pose le cookie de session et on
 * redirige. Un écran intermédiaire ne ferait qu'ajouter un clignotement.
 */
/**
 * Traduit le motif d'échec renvoyé par Supabase ou par Google.
 *
 * Un lien expiré est le cas le plus fréquent — l'étudiant ouvre ses mails
 * plus tard, ou clique deux fois. Le message doit dire quoi faire, pas
 * constater une panne.
 */
function messageErreur(codeErreur: string | null, erreur: string | null): string {
  const c = `${codeErreur ?? ''} ${erreur ?? ''}`.toLowerCase()

  if (c.includes('expired')) {
    return 'Ce lien a expiré. Demandes-en un nouveau.'
  }
  if (c.includes('access_denied')) {
    return 'Connexion annulée.'
  }
  if (c.includes('otp') || c.includes('invalid')) {
    return 'Ce lien a déjà servi. Demandes-en un nouveau.'
  }
  return 'On n’a pas pu terminer la connexion. Réessaie.'
}

export async function GET(request: Request) {
  const url = new URL(request.url)
  const code = url.searchParams.get('code')
  const suite = url.searchParams.get('suite')

  // Cette route sert deux entrées : le retour Google et le lien de connexion
  // reçu par email. Les motifs d'échec diffèrent, le message aussi.
  const codeErreur = url.searchParams.get('error_code')
  const erreur = url.searchParams.get('error')

  if (codeErreur || erreur) {
    const echec = new URL('/connexion', url.origin)
    echec.searchParams.set('erreur', messageErreur(codeErreur, erreur))
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
