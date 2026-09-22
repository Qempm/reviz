import { z } from 'zod'
import { authentifier, refusSession } from '@/lib/supabase/jeton'
import { createAdminClient } from '@/lib/supabase/admin'
import {
  SEUIL_RETRAIT_FCFA,
  verifierRetrait,
} from '@/lib/payments/commission'

/**
 * POST /api/wallet/withdrawal
 *
 * Crée une demande de retrait si le solde le permet.
 *
 * Trois changements par rapport à la première version, tous constatés dans
 * l'audit :
 *
 *  1. `authentifier()` au lieu du client à cookies — sans quoi tout appel
 *     depuis l'application Flutter recevait 401 (rapport § 3.2).
 *  2. L'enveloppe `{ ok, data | error }` des conventions, avec un `motif`
 *     en kebab-case : le client dépliait `data` et ne trouvait rien.
 *  3. Les messages sont en français. L'écran web affichait
 *     `insufficient_balance` tel quel à l'étudiant (rapport § 4.14).
 *
 * Et la vérification passe par `verifierRetrait()`, couverte par ses tests,
 * plutôt que par une comparaison réécrite ici : elle distingue « encore
 * 1 200 F avant de pouvoir retirer » de « solde insuffisant », ce que la
 * version précédente confondait.
 */

const corpsSchema = z.object({
  // Le plancher est vérifié par `verifierRetrait()`, pas par le schéma : un
  // montant de 500 F doit répondre « le minimum est de 3 000 F » et non
  // « entrée invalide ».
  amount_fcfa: z.number().int().positive(),
  operator: z.enum(['mtn', 'moov', 'wave']),
  phone: z.string().regex(/^\+?[0-9]{8,15}$/),
})

export async function POST(request: Request) {
  const appelant = await authentifier(request)
  if (!appelant) return refusSession()

  let brut: unknown
  try {
    brut = await request.json()
  } catch {
    return Response.json(
      { ok: false, error: 'Requête illisible.', motif: 'corps-invalide' },
      { status: 400 },
    )
  }

  const analyse = corpsSchema.safeParse(brut)
  if (!analyse.success) {
    return Response.json(
      {
        ok: false,
        error: 'Vérifie le montant, l’opérateur et le numéro.',
        motif: 'entree-invalide',
      },
      { status: 400 },
    )
  }

  const { amount_fcfa, operator, phone } = analyse.data

  // Le solde est la somme du grand livre, lue côté serveur : un montant
  // proposé par le client ne décide de rien.
  const { data: balance } = await appelant.supabase.rpc('wallet_balance')
  const solde = typeof balance === 'number' ? balance : 0

  const verdict = verifierRetrait({ soldeFcfa: solde, amountFcfa: amount_fcfa })

  if (!verdict.autorise) {
    const messages: Record<typeof verdict.reason, string> = {
      montant_invalide: 'Indique un montant en chiffres.',
      sous_le_seuil: `Le retrait minimum est de ${SEUIL_RETRAIT_FCFA} F.`,
      solde_insuffisant: `Ton solde est de ${solde} F.`,
    }
    const motifs: Record<typeof verdict.reason, string> = {
      montant_invalide: 'montant-invalide',
      sous_le_seuil: 'sous-le-seuil',
      solde_insuffisant: 'solde-insuffisant',
    }

    return Response.json(
      {
        ok: false,
        error: messages[verdict.reason],
        motif: motifs[verdict.reason],
      },
      { status: verdict.reason === 'solde_insuffisant' ? 402 : 400 },
    )
  }

  // `withdrawals` et `wallet_ledger` ne sont écrites que par le rôle de
  // service : ce sont des tables financières.
  const admin = createAdminClient()

  const { data: demande, error: erreurDemande } = await admin
    .from('withdrawals')
    .insert({
      user_id: appelant.user.id,
      amount_fcfa,
      operator,
      phone,
      status: 'requested',
      requested_at: new Date().toISOString(),
    })
    .select('id')
    .single()

  if (erreurDemande || !demande) {
    console.error('Retrait — insertion refusée :', erreurDemande)
    return Response.json(
      {
        ok: false,
        error: 'La demande n’a pas abouti. Réessaie dans un instant.',
        motif: 'serveur',
      },
      { status: 500 },
    )
  }

  const { error: erreurLivre } = await admin.from('wallet_ledger').insert({
    user_id: appelant.user.id,
    type: 'withdrawal',
    amount_fcfa: -amount_fcfa,
    reference_id: demande.id,
    created_at: new Date().toISOString(),
  })

  if (erreurLivre) {
    console.error('Retrait — grand livre refusé :', erreurLivre)
    // Le grand livre est immuable : mieux vaut retirer la demande que
    // laisser un retrait sans débit.
    await admin.from('withdrawals').delete().eq('id', demande.id)
    return Response.json(
      {
        ok: false,
        error: 'La demande n’a pas abouti. Réessaie dans un instant.',
        motif: 'serveur',
      },
      { status: 500 },
    )
  }

  const { error: erreurJob } = await admin.from('jobs').insert({
    type: 'notify',
    payload: {
      phone,
      template: 'withdrawal_requested',
      variables: { amount_fcfa: amount_fcfa.toString(), operator },
    },
    status: 'queued',
    attempts: 0,
    run_after: new Date().toISOString(),
    created_at: new Date().toISOString(),
  })

  if (erreurJob) {
    // La notification n'est pas la demande : on la journalise et on rend la
    // demande, qui est bien enregistrée.
    console.error('Retrait — notification non enfilée :', erreurJob)
  }

  return Response.json({ ok: true, data: { id: demande.id } })
}
