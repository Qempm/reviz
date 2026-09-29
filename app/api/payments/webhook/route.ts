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
 * **Puis, le 29 septembre 2026, elle a été remise d'équerre avec la doc
 * FedaPay** : la signature arrive sous la forme `t=…,s=…` et porte sur
 * « horodatage.corps » (voir `validateWebhookSignature`), et l'événement a
 * la forme `{ name, entity }` — pas `{ event, data }` comme le supposait la
 * première version. Aucune vraie notification n'aurait passé la vérification.
 *
 * La route ne fait plus que vérifier la signature, lire l'événement et
 * déléguer à `traiterTransaction()`, que partage `/api/payments/status`. La
 * règle est dans `lib/metier/paiement.ts`, testée sans base.
 */

import { NextRequest, NextResponse } from 'next/server'
import { z } from 'zod'
import { createAdminClient } from '@/lib/supabase/admin'
import { validateWebhookSignature } from '@/lib/payments/provider'
import { traiterTransaction } from '@/lib/payments/traiter'
import { statutDepuisFedaPay } from '@/lib/metier/paiement'

/**
 * Un événement FedaPay : `name` (`transaction.approved`…) et `entity`, l'objet
 * concerné. Forme relevée dans la doc (`event.name`) et confirmée par une
 * bibliothèque tierce qui les traite (`WebhookTransaction`).
 */
const EvenementSchema = z.object({
  name: z.string(),
  entity: z
    .object({
      id: z.union([z.string(), z.number()]),
      status: z.string(),
    })
    .passthrough(),
})

/** 200 sur les cas sans effet : sinon FedaPay réessaie, jusqu'à désactiver. */
function accuseReception(detail?: Record<string, unknown>) {
  return NextResponse.json({ ok: true, ...detail })
}

export async function POST(request: NextRequest) {
  try {
    // 1. Signature, sur le corps **brut** : le relire après `JSON.parse`
    //    changerait les espaces, et la signature ne correspondrait plus.
    const charge = await request.text()
    const entete = request.headers.get('X-FEDAPAY-SIGNATURE') ?? ''
    const secret = process.env.FEDAPAY_WEBHOOK_SECRET ?? ''

    if (!secret.startsWith('wh_')) {
      // Un secret absent, ou autre chose qu'un secret de webhook — une URL
      // recopiée dans la mauvaise case, par exemple. Le dire dans les
      // journaux plutôt que refuser chaque notification sans explication.
      console.error(
        'Webhook paiement : FEDAPAY_WEBHOOK_SECRET absent ou invalide ' +
          '(attendu : wh_live_… ou wh_sandbox_…).',
      )
      return NextResponse.json(
        { ok: false, error: 'Configuration incomplète.' },
        { status: 500 },
      )
    }

    if (!validateWebhookSignature(charge, entete, secret)) {
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

    // 2. Seules les transactions nous intéressent. Un client créé, un
    //    virement : accuser réception et s'arrêter.
    if (!evenement.name.startsWith('transaction.')) {
      return accuseReception({ motif: 'evenement-ignore' })
    }

    // 3. L'issue.
    const issue = await traiterTransaction(createAdminClient(), {
      reference: String(evenement.entity.id),
      statut: statutDepuisFedaPay(evenement.entity.status),
      brut: evenement,
    })

    // Une erreur de base mérite un nouvel essai de FedaPay : un 500 le
    // déclenche. Tout le reste est accusé.
    if (!issue.ok) {
      return NextResponse.json(
        { ok: false, error: 'Traitement impossible.', motif: issue.motif },
        { status: 500 },
      )
    }
    return accuseReception({ motif: issue.motif })
  } catch (erreur) {
    console.error('POST /api/payments/webhook :', erreur)
    return NextResponse.json(
      { ok: false, error: 'Erreur interne.' },
      { status: 500 },
    )
  }
}
