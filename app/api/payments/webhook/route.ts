/**
 * POST /api/payments/webhook
 *
 * Webhook du fournisseur de paiement. Quatre défauts de la première version
 * sont corrigés ici, tous relevés dans l'audit :
 *
 *  1. **Il payait deux fois.** Le code lisait `payment.status` et ne le
 *     testait jamais. Tout émetteur de webhook réémet : à la deuxième
 *     livraison de `approved`, l'étudiant recevait un second abonnement et
 *     le parrain une seconde commission — dans un journal immuable que seule
 *     une ligne `adjustment` peut corriger. La décision est désormais prise
 *     par `deciderPaiement()`, qui écarte une relivraison avant toute autre
 *     considération, et l'écriture passe par `enregistrer_paiement()`, qui
 *     reprend la ligne de paiement `for update` — deux livraisons simultanées
 *     ne peuvent donc pas se croiser.
 *  2. **Le taux était lu sur le payeur**, pas sur le parrain. Un parrain
 *     ambassadeur touchait 25 % si son filleul ne l'était pas.
 *  3. **Trois règles de commission sur quatre étaient contournées** :
 *     `calculerCommission()` porte la vérification du filleul, la fenêtre de
 *     douze mois et le garde-fou anti-auto-parrainage, et n'était appelée que
 *     par ses propres tests. Elle l'est maintenant.
 *  4. **La notification était conditionnée à `referred_by`** : un étudiant
 *     sans parrain n'était jamais prévenu de son propre paiement.
 *
 * La route ne fait plus que trois choses : vérifier la signature, charger le
 * contexte, et appliquer la décision. La règle est dans
 * `lib/metier/paiement.ts`, testée sans base.
 */

import { NextRequest, NextResponse } from 'next/server'
import { z } from 'zod'
import { createAdminClient } from '@/lib/supabase/admin'
import type { Json } from '@/lib/supabase/database.types'
import { validateWebhookSignature } from '@/lib/payments/provider'
import { deciderPaiement, type StatutPaiement } from '@/lib/metier/paiement'
import type { PackCode } from '@/lib/payments/subscriptions'
import type { StatutVerification } from '@/lib/payments/commission'

const EvenementSchema = z.object({
  event: z.string(),
  data: z.object({
    id: z.union([z.string(), z.number()]),
    status: z.enum(['approved', 'declined', 'pending']),
    amount: z.number(),
    customer: z.object({ phone: z.string() }).optional(),
    metadata: z
      .object({
        user_id: z.string().uuid().optional(),
        pack_code: z.string().optional(),
      })
      .optional(),
  }),
})

/** 200 systématique sur les cas sans effet : sinon le fournisseur réessaie. */
function accuseReception(detail?: Record<string, unknown>) {
  return NextResponse.json({ ok: true, ...detail })
}

export async function POST(request: NextRequest) {
  const admin = createAdminClient()

  try {
    // 1. Signature, sur la charge utile brute.
    const charge = await request.text()
    const signature = request.headers.get('X-Fedapay-Signature') ?? ''
    const secret = process.env.FEDAPAY_WEBHOOK_SECRET ?? ''

    if (!secret) {
      console.error('Webhook paiement : FEDAPAY_WEBHOOK_SECRET absent.')
      return NextResponse.json(
        { ok: false, error: 'Configuration incomplète.' },
        { status: 500 },
      )
    }

    if (!validateWebhookSignature(charge, signature, secret)) {
      console.warn('Webhook paiement : signature invalide.')
      return NextResponse.json(
        { ok: false, error: 'Signature invalide.' },
        { status: 401 },
      )
    }

    const analyse = EvenementSchema.safeParse(JSON.parse(charge))
    if (!analyse.success) {
      console.warn('Webhook paiement : charge utile inattendue.')
      return NextResponse.json(
        { ok: false, error: 'Charge utile invalide.' },
        { status: 400 },
      )
    }

    const evenement = analyse.data
    const reference = String(evenement.data.id)

    // 2. Le paiement, avec son statut actuel — c'est lui qui dit si cet
    //    événement a déjà été traité.
    const { data: paiement, error: erreurPaiement } = await admin
      .from('payments')
      .select('id, user_id, pack_code, amount_fcfa, status')
      .eq('provider', 'fedapay')
      .eq('provider_ref', reference)
      .maybeSingle()

    if (erreurPaiement) {
      console.error('Webhook paiement : lecture impossible', erreurPaiement)
      return NextResponse.json(
        { ok: false, error: 'Erreur de base.' },
        { status: 500 },
      )
    }

    if (!paiement) {
      // Transaction qui ne nous concerne pas : accuser réception, sans quoi
      // le fournisseur la réessaierait indéfiniment.
      console.warn(`Webhook paiement : transaction ${reference} inconnue.`)
      return accuseReception({ motif: 'paiement-inconnu' })
    }

    // 3. Le pack, tel que la base le décrit — pas tel que le client l'annonce.
    const { data: pack, error: erreurPack } = await admin
      .from('packs')
      .select('code, duration_days, corrections_included, subjects_limit')
      .eq('code', paiement.pack_code)
      .maybeSingle()

    if (erreurPack || !pack) {
      console.error('Webhook paiement : pack introuvable', erreurPack)
      return NextResponse.json(
        { ok: false, error: 'Pack introuvable.' },
        { status: 500 },
      )
    }

    // 4. Le payeur, puis — si et seulement s'il a un parrain — le parrainage
    //    et le profil du **parrain**.
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

    // 5. La décision, sans base.
    const decision = deciderPaiement(evenement.data.status, {
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
      return accuseReception({ motif: decision.motif })
    }

    // 6. Une seule écriture, en une seule transaction.
    const { data: resultat, error: erreurEcriture } = await admin.rpc(
      'enregistrer_paiement',
      {
        p_provider: 'fedapay',
        p_provider_ref: reference,
        p_statut: decision.action === 'echec' ? 'failed' : 'success',
        // La charge utile telle que reçue, pour l'audit. `Json` est le type
        // que la base expose ; un objet analysé par Zod lui est structurellement
        // conforme, sans que TypeScript puisse l'établir seul.
        p_brut: evenement as unknown as Json,
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
      console.error('Webhook paiement : enregistrement refusé', erreurEcriture)
      return NextResponse.json(
        { ok: false, error: 'Enregistrement impossible.' },
        { status: 500 },
      )
    }

    const issue = (resultat as { resultat?: string } | null)?.resultat

    if (decision.action === 'echec') {
      return accuseReception({ motif: 'echec-enregistre' })
    }

    if (issue === 'deja-traite') {
      // La fonction a vu ce que la lecture de l'étape 2 n'avait pas encore vu :
      // deux livraisons arrivées en même temps. Rien n'a été écrit deux fois.
      return accuseReception({ motif: 'deja-traite' })
    }

    if (decision.motifSansCommission && decision.motifSansCommission !== 'aucun-parrainage') {
      // Utile au support : « pourquoi mon parrain n'a rien touché ? » a une
      // réponse, et elle est dans les journaux.
      console.info(
        `Paiement ${paiement.id} : aucune commission — ${decision.motifSansCommission}.`,
      )
    }

    // 7. Notifier l'étudiant de **son** paiement.
    //
    // Inconditionnel : la version précédente exigeait `referred_by`, si bien
    // qu'un étudiant sans parrain n'était jamais prévenu. Envoi direct et non
    // par un job `notify` : sur l'offre Vercel Hobby le cron ne tourne
    // qu'une fois par jour, et une confirmation de paiement ne peut pas
    // attendre demain.
    const n8n = process.env.N8N_WHATSAPP_WEBHOOK_URL
    if (n8n) {
      fetch(n8n, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          type: 'payment_success',
          user_id: paiement.user_id,
          pack_code: paiement.pack_code,
          amount: paiement.amount_fcfa,
        }),
      }).catch((e) =>
        console.error('Webhook paiement : notification non partie', e),
      )
    }

    return accuseReception({ motif: 'traite' })
  } catch (erreur) {
    console.error('POST /api/payments/webhook :', erreur)
    return NextResponse.json(
      { ok: false, error: 'Erreur interne.' },
      { status: 500 },
    )
  }
}
