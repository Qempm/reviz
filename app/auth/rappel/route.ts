import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

/**
 * Retour de Google : échange le code d'autorisation contre une session.
 *
 * Route et non page : rien à afficher, on pose le cookie de session et on
 * redirige. Un écran intermédiaire ne ferait qu'ajouter un clignotement.
 *
 * **Sauf depuis la coquille Android** (`?coquille=1`). L'écran Google y est
 * affiché dans un onglet personnalisé, qui ne partage pas les cookies de la
 * WebView : le vérificateur PKCE lui manque, et l'échange échouerait ici. La
 * route rend donc la main à l'application par `reviz://auth?code=...`, et
 * c'est la WebView qui rejoue ce même rappel — sans `coquille`, cette fois.
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

/**
 * Page minimale qui rend la main à l'application Android.
 *
 * Une redirection HTTP vers un schéma applicatif n'est pas suivie de façon
 * fiable par tous les navigateurs : une navigation en JavaScript, doublée
 * d'un lien à toucher si elle est bloquée, l'est.
 */
function retourVersLApp(parametres: Record<string, string | null>): Response {
  // Query assemblée à la main, et non par `URLSearchParams` : celui-ci code
  // les espaces en « + », et `Uri.getQueryParameter` d'Android ne les
  // retraduit pas — le message d'erreur arriverait truffé de « + ».
  const query = Object.entries(parametres)
    .filter((e): e is [string, string] => e[1] !== null && e[1] !== '')
    .map(([c, v]) => `${encodeURIComponent(c)}=${encodeURIComponent(v)}`)
    .join('&')

  const url = query === '' ? 'reviz://auth' : `reviz://auth?${query}`
  const echappe = url.replace(/&/g, '&amp;').replace(/"/g, '&quot;')

  return new Response(
    `<!doctype html><html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Reviz</title>
<style>html,body{margin:0;height:100%;background:#fcf9f8;color:#1c1b1b;
font-family:system-ui,-apple-system,sans-serif}
div{height:100%;display:flex;flex-direction:column;align-items:center;
justify-content:center;gap:16px;padding:24px;text-align:center}
p{font-size:15px;font-weight:500;color:#4f4632;margin:0}
a{display:inline-flex;align-items:center;height:56px;padding:0 24px;
border-radius:12px;background:#ffc300;color:#311300;font-size:18px;
font-weight:800;text-decoration:none;box-shadow:0 4px 0 #d9a400}</style>
</head><body><div>
<p>Connexion réussie. Retour à Reviz…</p>
<a href="${echappe}">Ouvrir Reviz</a>
</div>
<script>location.replace(${JSON.stringify(url)})</script>
</body></html>`,
    {
      headers: {
        'content-type': 'text/html; charset=utf-8',
        // Ce document porte un code à usage unique : il ne doit rester ni
        // dans le cache du navigateur ni dans celui d'un intermédiaire.
        'cache-control': 'no-store',
      },
    },
  )
}

export async function GET(request: Request) {
  const url = new URL(request.url)
  const code = url.searchParams.get('code')
  const suite = url.searchParams.get('suite')
  const coquille = url.searchParams.get('coquille') === '1'

  // Cette route sert deux entrées : le retour Google et le lien de connexion
  // reçu par email. Les motifs d'échec diffèrent, le message aussi.
  const codeErreur = url.searchParams.get('error_code')
  const erreur = url.searchParams.get('error')

  if (codeErreur || erreur) {
    const message = messageErreur(codeErreur, erreur)

    if (coquille) return retourVersLApp({ erreur: message })

    const echec = new URL('/connexion', url.origin)
    echec.searchParams.set('erreur', message)
    return NextResponse.redirect(echec)
  }

  if (!code) {
    if (coquille) {
      return retourVersLApp({ erreur: 'Lien de connexion incomplet. Réessaie.' })
    }

    const echec = new URL('/connexion', url.origin)
    echec.searchParams.set('erreur', 'Lien de connexion incomplet. Réessaie.')
    return NextResponse.redirect(echec)
  }

  // Le code n'est pas échangé ici : il repart intact vers l'application, qui
  // le rejouera depuis la WebView. L'échange est à usage unique, il ne doit
  // donc être tenté qu'une fois — et du bon côté.
  if (coquille) return retourVersLApp({ code, suite })

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
