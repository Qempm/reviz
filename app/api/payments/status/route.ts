import { z } from 'zod'
import { authentifier, refusSession } from '@/lib/supabase/jeton'
import { createAdminClient } from '@/lib/supabase/admin'
import { createPaymentProvider } from '@/lib/payments/provider'
import { traiterTransaction } from '@/lib/payments/traiter'
import { statutDepuisFedaPay } from '@/lib/metier/paiement'

/**
 * GET /api/payments/status[?id=<paiement>]
 *
 * L'issue d'un paiement de l'appelant — celui dont on donne l'identifiant, ou
 * à défaut le dernier. L'écran qui attend le retour de FedaPay l'interroge
 * jusqu'à ce qu'elle soit tranchée.
 *
 * **Le filet du webhook.** Tant qu'un paiement reste `pending`, cette route
 * relit la transaction chez FedaPay, avec la clé secrète, et applique
 * l'issue par `traiterTransaction()` — la même fonction que le webhook. Sans
 * cela, un étudiant qui a payé resterait sans accès chaque fois que la
 * notification se perd, tarde, ou arrive signée d'un secret mal recopié. La
 * source n'est pas moins sûre que le webhook : c'est FedaPay qui répond, à
 * une requête que nous avons authentifiée.
 *
 * La lecture du paiement passe par le client de l'appelant : la politique de
 * `payments` ne laisse voir que ses propres lignes. Seule l'écriture de
 * l'issue prend le rôle de service, comme au webhook.
 */

/** Pas avant : la page FedaPay vient à peine de s'ouvrir. */
const DELAI_AVANT_VERIFICATION_MS = 15_000

export async function GET(request: Request) {
  const appelant = await authentifier(request)
  if (!appelant) return refusSession()

  const id = new URL(request.url).searchParams.get('id')

  // Un identifiant mal formé ferait lever Postgres (`invalid input syntax
  // for type uuid`) : le refuser ici, avec un message, plutôt qu'un 500.
  if (id !== null && !z.string().uuid().safeParse(id).success) {
    return Response.json(
      { ok: false, error: 'Paiement inconnu.', motif: 'entree-invalide' },
      { status: 400 },
    )
  }

  const lire = () => {
    const requete = appelant.supabase
      .from('payments')
      .select('id, status, amount_fcfa, pack_code, provider_ref, created_at')
    return (
      id
        ? requete.eq('id', id)
        : requete.order('created_at', { ascending: false }).limit(1)
    ).maybeSingle()
  }

  const premiere = await lire()
  let paiement = premiere.data

  if (premiere.error) {
    console.error(
      '[paiement] lecture du statut impossible',
      premiere.error.message,
    )
    return Response.json(
      {
        ok: false,
        error: 'On n’a pas pu lire ton paiement. Réessaie dans un instant.',
        motif: 'serveur',
      },
      { status: 500 },
    )
  }

  if (!paiement) {
    // Pas un problème : simplement rien à suivre. Le 404 dit « rien à
    // regarder », et l'écran n'a pas à insister.
    return Response.json(
      {
        ok: false,
        error: 'Aucun paiement à suivre.',
        motif: 'aucun-paiement',
      },
      { status: 404 },
    )
  }

  const age = Date.now() - new Date(paiement.created_at).getTime()

  if (
    paiement.status === 'pending' &&
    paiement.provider_ref &&
    age >= DELAI_AVANT_VERIFICATION_MS
  ) {
    try {
      const transaction = await createPaymentProvider().checkStatus(
        paiement.provider_ref,
      )
      const statut = transaction ? statutDepuisFedaPay(transaction.status) : null

      if (transaction && statut !== 'pending') {
        await traiterTransaction(createAdminClient(), {
          reference: paiement.provider_ref,
          statut: statut!,
          brut: { source: 'suivi', transaction },
        })
        paiement = (await lire()).data
      }
    } catch (e) {
      // Fournisseur injoignable ou mal configuré : on rend le statut connu,
      // et l'écran réessaiera. Le webhook reste l'autre chemin.
      console.error('[paiement] vérification auprès de FedaPay impossible', e)
    }
  }

  if (!paiement) {
    return Response.json(
      { ok: false, error: 'Aucun paiement à suivre.', motif: 'aucun-paiement' },
      { status: 404 },
    )
  }

  const { provider_ref: _ref, ...visible } = paiement
  return Response.json({ ok: true, data: visible })
}
