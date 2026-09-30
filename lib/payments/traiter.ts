/**
 * Applique l'issue d'une transaction à la base : accès, commission, avis.
 *
 * Sorti de la route du webhook quand une seconde porte d'entrée est apparue.
 * FedaPay notifie par webhook, mais une notification peut se perdre, être
 * désactivée après dix échecs, ou arriver signée d'un secret mal recopié :
 * l'étudiant aurait payé sans rien recevoir. `/api/payments/status` relit
 * donc la transaction chez FedaPay quand l'attente se prolonge, et passe par
 * **la même** fonction. Deux copies de ce traitement auraient fini par
 * diverger — c'est exactement ce qui avait fait payer deux fois la première
 * version.
 *
 * Rejouer n'est pas un risque : `deciderPaiement` écarte un paiement déjà
 * tranché, et `enregistrer_paiement()` reprend la ligne `for update`, si
 * bien que le webhook et le suivi arrivant ensemble n'écrivent qu'une fois.
 */

import type { createAdminClient } from '@/lib/supabase/admin'
import type { Json } from '@/lib/supabase/database.types'
import {
  deciderPaiement,
  type StatutFournisseur,
  type StatutPaiement,
} from '@/lib/metier/paiement'
import type { PackCode } from '@/lib/payments/subscriptions'
import type { StatutVerification } from '@/lib/payments/commission'

type Admin = ReturnType<typeof createAdminClient>

export type IssueTraitement =
  | { ok: true; motif: string }
  | { ok: false; motif: string }

export async function traiterTransaction(
  admin: Admin,
  opts: {
    /** L'identifiant FedaPay de la transaction (`payments.provider_ref`). */
    reference: string
    statut: StatutFournisseur
    /** Ce qui a été reçu, gardé pour l'audit. */
    brut: unknown
  },
): Promise<IssueTraitement> {
  const { reference, statut } = opts

  // 1. Le paiement, avec son statut actuel — c'est lui qui dit si cette
  //    issue a déjà été appliquée.
  const { data: paiement, error: erreurPaiement } = await admin
    .from('payments')
    .select('id, user_id, pack_code, amount_fcfa, status')
    .eq('provider', 'fedapay')
    .eq('provider_ref', reference)
    .maybeSingle()

  if (erreurPaiement) {
    console.error('Paiement : lecture impossible', erreurPaiement)
    return { ok: false, motif: 'lecture' }
  }

  if (!paiement) {
    // Transaction qui ne nous concerne pas (créée à la main dans le tableau
    // de bord, par exemple) : rien à faire, et surtout rien à réessayer.
    console.warn(`Paiement : transaction ${reference} inconnue.`)
    return { ok: true, motif: 'paiement-inconnu' }
  }

  // 2. Le pack, tel que la base le décrit — pas tel que le client l'annonce.
  const { data: pack, error: erreurPack } = await admin
    .from('packs')
    .select('code, duration_days, corrections_included, subjects_limit')
    .eq('code', paiement.pack_code)
    .maybeSingle()

  if (erreurPack || !pack) {
    console.error('Paiement : pack introuvable', erreurPack)
    return { ok: false, motif: 'pack-introuvable' }
  }

  // 3. Le payeur, puis — si et seulement s'il a un parrain — le parrainage
  //    et le profil du **parrain** : le taux se lit sur lui, pas sur le
  //    payeur.
  const { data: payeur } = await admin
    .from('profiles')
    .select('id, referred_by, verification_status')
    .eq('id', paiement.user_id)
    .maybeSingle()

  let parrainage = null as
    | null
    | { referrerId: string; referredId: string; firstPaymentAt: Date | null }
  let parrain = null as null | { id: string; isAmbassador: boolean }

  if (payeur?.referred_by) {
    const [{ data: ligne }, { data: profilParrain }] = await Promise.all([
      admin
        .from('referrals')
        .select('referrer_id, referred_id, first_payment_at')
        .eq('referrer_id', payeur.referred_by)
        .eq('referred_id', paiement.user_id)
        .maybeSingle(),
      admin
        .from('profiles')
        .select('id, is_ambassador')
        .eq('id', payeur.referred_by)
        .maybeSingle(),
    ])

    if (ligne) {
      parrainage = {
        referrerId: ligne.referrer_id,
        referredId: ligne.referred_id,
        firstPaymentAt: ligne.first_payment_at
          ? new Date(ligne.first_payment_at)
          : null,
      }
    }

    if (profilParrain) {
      parrain = {
        id: profilParrain.id,
        isAmbassador: profilParrain.is_ambassador ?? false,
      }
    }
  }

  // 4. La décision, sans base.
  const decision = deciderPaiement(statut, {
    paiement: {
      id: paiement.id,
      userId: paiement.user_id,
      packCode: paiement.pack_code as PackCode,
      amountFcfa: paiement.amount_fcfa,
      status: paiement.status as StatutPaiement,
    },
    pack: {
      code: pack.code as PackCode,
      durationDays: pack.duration_days,
      correctionsIncluded: pack.corrections_included,
      subjectsLimit: pack.subjects_limit,
    },
    payeur: {
      id: paiement.user_id,
      verificationStatus: (payeur?.verification_status ??
        'none') as StatutVerification,
    },
    parrainage,
    parrain,
  })

  if (decision.action === 'ignorer') {
    return { ok: true, motif: decision.motif }
  }

  // 5. Une seule écriture, en une seule transaction.
  const { data: resultat, error: erreurEcriture } = await admin.rpc(
    'enregistrer_paiement',
    {
      p_provider: 'fedapay',
      p_provider_ref: reference,
      p_statut: decision.action === 'echec' ? 'failed' : 'success',
      // `Json` est le type que la base expose ; ce qui a été reçu lui est
      // structurellement conforme, sans que TypeScript puisse l'établir seul.
      p_brut: opts.brut as Json,
      ...(decision.action === 'activer'
        ? {
            p_debut: decision.abonnement.startsAt.toISOString(),
            p_fin: decision.abonnement.endsAt.toISOString(),
            p_corrections: decision.abonnement.correctionsLeft,
            p_parrain: decision.commission?.parrainId,
            p_commission_fcfa: decision.commission?.montantFcfa,
            p_taux: decision.commission?.taux,
          }
        : {}),
    },
  )

  if (erreurEcriture) {
    console.error('Paiement : enregistrement refusé', erreurEcriture)
    return { ok: false, motif: 'ecriture' }
  }

  if (decision.action === 'echec') {
    return { ok: true, motif: 'echec-enregistre' }
  }

  if ((resultat as { resultat?: string } | null)?.resultat === 'deja-traite') {
    // Le webhook et le suivi sont arrivés ensemble : la fonction a vu ce que
    // la lecture de l'étape 1 n'avait pas encore vu. Rien n'est écrit deux
    // fois, et personne n'est notifié deux fois.
    return { ok: true, motif: 'deja-traite' }
  }

  // Le premier paiement d'un filleul vaut 500 XP à son parrain : au barème
  // depuis le début, jamais attribués. Le premier seulement — ensuite, la
  // commission suffit.
  if (decision.commission && parrainage && parrainage.firstPaymentAt === null) {
    const { attribuerXp } = await import('@/lib/xp/attribuer')
    const { BAREME } = await import('@/lib/xp/attribution')
    await attribuerXp({
      userId: decision.commission.parrainId,
      gains: [{ reason: 'referral', amount: BAREME.referral }],
      referenceId: paiement.id,
    })
  }

  if (
    decision.motifSansCommission &&
    decision.motifSansCommission !== 'aucun-parrainage'
  ) {
    // Utile au support : « pourquoi mon parrain n'a rien touché ? » a une
    // réponse, et elle est dans les journaux.
    console.info(
      `Paiement ${paiement.id} : aucune commission — ${decision.motifSansCommission}.`,
    )
  }

  // L'étudiant est prévenu dans l'application : l'écran de paiement suit
  // l'issue (`/api/payments/status`). Plus de message WhatsApp depuis le
  // 30 septembre 2026.

  return { ok: true, motif: 'traite' }
}
