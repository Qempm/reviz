import { after } from 'next/server'
import { APK } from '@/lib/metier/publication'
import { appareilDepuis, sourceDepuis } from '@/lib/admin/regles'
import { createAdminClient } from '@/lib/supabase/admin'

/**
 * GET /telecharger?depuis=accueil|app
 *
 * Compte un clic sur « Télécharger », puis renvoie vers l'APK. On ne garde
 * que le jour, la page d'où vient le clic et la famille d'appareil : ni
 * adresse IP, ni identifiant. Le compte s'écrit après la réponse (`after`) :
 * la redirection ne l'attend pas, et une écriture ratée ne bloque jamais un
 * téléchargement.
 */
export const dynamic = 'force-dynamic'

export function GET(request: Request) {
  const url = new URL(request.url)
  const source = sourceDepuis(url.searchParams.get('depuis'))
  const appareil = appareilDepuis(request.headers.get('user-agent'))

  after(async () => {
    try {
      const { error } = await createAdminClient().from('telechargements').insert({ source, appareil })
      if (error) console.error('[telecharger] non compté', error.message)
    } catch (e) {
      console.error('[telecharger] non compté', e instanceof Error ? e.message : e)
    }
  })

  // Pas d'APK publié : la page d'installation explique quoi faire.
  return Response.redirect(APK.publie ? APK.url : new URL('/app', url).toString(), 302)
}
