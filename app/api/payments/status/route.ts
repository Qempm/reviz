import { authentifier, refusSession } from '@/lib/supabase/jeton'

/**
 * GET /api/payments/status
 *
 * L'issue du dernier paiement de l'appelant. L'écran qui attend le retour de
 * FedaPay l'interroge jusqu'à ce que le webhook ait tranché.
 *
 * Convertie au lot D : elle lisait les cookies uniquement — donc 401 à tout
 * appel Flutter —, rendait `{ ok, status }` à plat au lieu de l'enveloppe
 * commune, et répondait `Unauthorized` / `Database error` en anglais.
 *
 * La lecture passe par le client de l'appelant : la politique de `payments`
 * ne laisse voir que ses propres lignes, ce qui suffit — aucun besoin du rôle
 * de service pour lire son propre paiement.
 */
export async function GET(request: Request) {
  const appelant = await authentifier(request)
  if (!appelant) return refusSession()

  const { data: paiement, error } = await appelant.supabase
    .from('payments')
    .select('id, status, amount_fcfa, pack_code, created_at')
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle()

  if (error) {
    console.error('[paiement] lecture du statut impossible', error.message)
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
    // Pas un problème : simplement personne n'a encore payé. Le 404 dit
    // « rien à regarder », et l'écran n'a pas à insister.
    return Response.json(
      {
        ok: false,
        error: 'Aucun paiement à suivre.',
        motif: 'aucun-paiement',
      },
      { status: 404 },
    )
  }

  return Response.json({ ok: true, data: paiement })
}
