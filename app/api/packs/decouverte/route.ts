import { authentifier, refusSession } from '@/lib/supabase/jeton'
import { activerDecouverte } from '@/lib/metier/packs'

/**
 * POST /api/packs/decouverte
 *
 * Active le pack gratuit. Seul pack à 0 F, donc sans fournisseur de paiement.
 * Une fois pour toutes par étudiant.
 */
export async function POST(request: Request) {
  const appelant = await authentifier(request)
  if (!appelant) return refusSession()

  const resultat = await activerDecouverte(appelant.supabase, appelant.user.id)

  if (!resultat.ok) {
    const messages = {
      'deja-utilise': 'Tu as déjà utilisé le pack Découverte.',
      indisponible: 'Le pack Découverte n’est pas disponible en ce moment.',
      session: 'Ta session a expiré. Reconnecte-toi.',
      serveur: 'L’activation n’a pas abouti. Réessaie dans un instant.',
    }
    const statut = resultat.error === 'deja-utilise' ? 409 : resultat.error === 'session' ? 401 : 500
    return Response.json(
      { ok: false, error: messages[resultat.error], motif: resultat.error },
      { status: statut },
    )
  }

  return Response.json({ ok: true, data: { active: true } })
}
