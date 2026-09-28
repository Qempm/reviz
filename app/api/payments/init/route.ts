import { z } from 'zod'
import { authentifier, refusSession } from '@/lib/supabase/jeton'
import { createAdminClient } from '@/lib/supabase/admin'
import { createPaymentProvider } from '@/lib/payments/provider'

/**
 * POST /api/payments/init
 *
 * Ouvre une transaction Mobile Money et rend l'URL où l'étudiant paie.
 *
 * Convertie au lot D : elle construisait son client depuis les cookies
 * uniquement — donc 401 à tout appel Flutter —, rendait `{ ok, redirectUrl }`
 * à plat au lieu de l'enveloppe commune, et répondait en anglais
 * (`Unauthorized`, `Invalid input`, `Pack not found`).
 *
 * Elle était aussi la **deuxième** voie d'initiation de paiement : la Server
 * Action `initiatePayment` de l'écran boutique faisait presque la même chose,
 * en divergeant — elle n'avait ni le garde-fou « Découverte une seule fois »
 * ni le passage de l'opérateur. Cette Action est partie avec `app/(app)/` ;
 * il ne reste que cette route, celle que Flutter appellera.
 *
 * Le paiement lui-même n'est pas branché : `FEDAPAY_SECRET_KEY` manque, et
 * `createPaymentProvider()` refuse de se construire sans. La boutique Flutter
 * le dit à l'écran plutôt que d'ouvrir une page vide.
 */

const corpsSchema = z.object({
  packCode: z.enum([
    'decouverte',
    'controle',
    'partiel',
    'semestre',
    'rattrapage',
  ]),
  operator: z.enum(['mtn', 'moov', 'wave']).optional(),
  phone: z
    .string()
    .regex(/^\+?[0-9]{8,15}$/)
    .optional(),
})

export async function POST(request: Request) {
  const appelant = await authentifier(request)
  if (!appelant) return refusSession()

  const analyse = corpsSchema.safeParse(await request.json().catch(() => null))
  if (!analyse.success) {
    return Response.json(
      {
        ok: false,
        error: 'Vérifie le pack, l’opérateur et le numéro.',
        motif: 'entree-invalide',
      },
      { status: 400 },
    )
  }

  const { packCode, operator, phone } = analyse.data
  const userId = appelant.user.id

  // Le prix vient de la base, jamais du client : sans cela, un appel bricolé
  // choisirait combien payer.
  const [{ data: pack }, { count: decouverteDejaLa }] = await Promise.all([
    appelant.supabase
      .from('packs')
      .select('code, price_fcfa')
      .eq('code', packCode)
      .maybeSingle(),
    appelant.supabase
      .from('subscriptions')
      .select('pack_code', { count: 'exact', head: true })
      .eq('user_id', userId)
      .eq('pack_code', 'decouverte'),
  ])

  if (!pack) {
    return Response.json(
      { ok: false, error: 'Ce pack n’existe pas.', motif: 'pack-inconnu' },
      { status: 404 },
    )
  }

  if (packCode === 'decouverte' && (decouverteDejaLa ?? 0) > 0) {
    return Response.json(
      {
        ok: false,
        error: 'Tu as déjà utilisé le pack Découverte.',
        motif: 'deja-utilise',
      },
      { status: 409 },
    )
  }

  if (pack.price_fcfa === 0) {
    // Un pack gratuit n'a pas de transaction : il s'active directement.
    return Response.json(
      {
        ok: false,
        error: 'Ce pack est gratuit : active-le depuis la boutique.',
        motif: 'pack-gratuit',
      },
      { status: 400 },
    )
  }

  const admin = createAdminClient()

  const { data: paiement, error: erreurPaiement } = await admin
    .from('payments')
    .insert({
      user_id: userId,
      provider: 'fedapay',
      amount_fcfa: pack.price_fcfa,
      operator: operator ?? null,
      phone: phone ?? null,
      status: 'pending',
      pack_code: packCode,
    })
    .select('id')
    .single()

  if (erreurPaiement || !paiement) {
    console.error('[paiement] création impossible', erreurPaiement)
    return Response.json(
      {
        ok: false,
        error: 'On n’a pas pu ouvrir le paiement. Réessaie dans un instant.',
        motif: 'serveur',
      },
      { status: 500 },
    )
  }

  let resultat
  try {
    resultat = await createPaymentProvider('fedapay').initPayment({
      userId,
      amount: pack.price_fcfa,
      packCode,
      operator,
      phone,
    })
  } catch (e) {
    // `createPaymentProvider` lève quand la clé manque de l'environnement.
    console.error('[paiement] fournisseur indisponible', e)
    await admin.from('payments').update({ status: 'failed' }).eq('id', paiement.id)
    return Response.json(
      {
        ok: false,
        error: 'Le paiement Mobile Money n’est pas encore disponible.',
        motif: 'fournisseur-absent',
      },
      { status: 503 },
    )
  }

  if (!resultat.ok) {
    await admin.from('payments').update({ status: 'failed' }).eq('id', paiement.id)
    console.error('[paiement] ouverture refusée', resultat.error)
    return Response.json(
      {
        ok: false,
        error: 'Le paiement n’a pas pu s’ouvrir. Réessaie dans un instant.',
        motif: 'fournisseur',
      },
      { status: 502 },
    )
  }

  // `provider_ref` est ce que le webhook retrouvera : sans lui, un paiement
  // réussi ne pourrait être rattaché à personne.
  await admin
    .from('payments')
    .update({
      provider_ref: resultat.transactionId,
      raw: { redirectUrl: resultat.redirectUrl },
    })
    .eq('id', paiement.id)

  return Response.json({
    ok: true,
    data: {
      paiementId: paiement.id,
      transactionId: resultat.transactionId,
      redirectUrl: resultat.redirectUrl,
      montantFcfa: pack.price_fcfa,
    },
  })
}
