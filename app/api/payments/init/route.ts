import { z } from 'zod'
import { authentifier, refusSession } from '@/lib/supabase/jeton'
import { createAdminClient } from '@/lib/supabase/admin'
import {
  createPaymentProvider,
  type PaymentProvider,
} from '@/lib/payments/provider'
import { normaliserTelephone } from '@/lib/auth/phone'
import { modeFedaPay, OPERATEURS } from '@/lib/metier/operateurs'

/**
 * POST /api/payments/init
 *
 * Ouvre un paiement Mobile Money **qui se fait entièrement dans
 * l'application** : la route crée la transaction FedaPay, puis envoie la
 * demande directement au téléphone de l'étudiant (`POST /v1/{mode}`). Il la
 * valide avec son code secret ; l'application suit l'issue par
 * `/api/payments/status?id=…`.
 *
 * Avant le 29 septembre 2026, la route rendait le lien de la page hébergée
 * FedaPay, que l'application ouvrait dans un navigateur. Le propriétaire a
 * voulu que rien ne fasse sortir de Reviz : seuls les opérateurs payables
 * « sans redirection » sont acceptés (`lib/metier/operateurs.ts`).
 *
 * **Le client ne dit que son numéro et son opérateur.** Le prix vient de la
 * base, le prénom du profil, l'e-mail de la session : un appel bricolé ne
 * choisit ni combien payer, ni au nom de qui.
 *
 * Historique : convertie au lot D (cookies seuls, enveloppe à plat, réponses
 * en anglais) ; seule voie d'initiation depuis le retrait de la Server Action
 * `initiatePayment`, qui n'avait pas le garde-fou « Découverte une fois ».
 */

const corpsSchema = z.object({
  packCode: z.enum([
    'decouverte',
    'controle',
    'partiel',
    'semestre',
    'rattrapage',
  ]),
  // Facultatifs **pour le schéma seulement** : la 2.2.0 n'envoyait que le
  // pack (elle ouvrait la page FedaPay). On la reconnaît à leur absence, pour
  // lui dire de se mettre à jour plutôt que « vérifie le numéro ».
  operateur: z.enum(OPERATEURS).optional(),
  telephone: z.string().min(6).max(24).optional(),
})

const refus = (status: number, motif: string, error: string) =>
  Response.json({ ok: false, error, motif }, { status })

export async function POST(request: Request) {
  const appelant = await authentifier(request)
  if (!appelant) return refusSession()

  const analyse = corpsSchema.safeParse(await request.json().catch(() => null))
  if (!analyse.success) {
    return refus(
      400,
      'entree-invalide',
      'Vérifie le pack, l’opérateur et le numéro.',
    )
  }

  const { packCode, operateur, telephone } = analyse.data
  const userId = appelant.user.id

  if (!operateur || !telephone) {
    return refus(
      426,
      'mise-a-jour',
      'Mets Reviz à jour pour payer : le paiement se fait maintenant sans quitter l’application.',
    )
  }

  const numero = normaliserTelephone(telephone)
  if (!numero.ok) {
    return refus(
      400,
      'telephone-invalide',
      'Ce numéro ne ressemble pas à un numéro Mobile Money.',
    )
  }

  // Le fournisseur d'abord : sans clé, inutile d'écrire quoi que ce soit.
  let fournisseur: PaymentProvider
  try {
    fournisseur = createPaymentProvider('fedapay')
  } catch (e) {
    // Clé absente, ou qui n'est pas une clé secrète (`sk_live_` / `sk_sandbox_`).
    console.error('[paiement] fournisseur indisponible', e)
    return refus(
      503,
      'fournisseur-absent',
      'Le paiement Mobile Money n’est pas encore disponible.',
    )
  }

  const mode = modeFedaPay(operateur, numero.pays.code, fournisseur.sandbox)
  if (!mode) {
    return refus(
      400,
      'operateur-indisponible',
      `Cet opérateur ne se paie pas encore dans Reviz pour ce pays (${numero.pays.nom}).`,
    )
  }

  // Le prix vient de la base, jamais du client.
  const [{ data: pack }, { count: decouverteDejaLa }, { data: profil }] =
    await Promise.all([
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
      appelant.supabase
        .from('profiles')
        .select('first_name')
        .eq('id', userId)
        .maybeSingle(),
    ])

  if (!pack) return refus(404, 'pack-inconnu', 'Ce pack n’existe pas.')

  if (packCode === 'decouverte' && (decouverteDejaLa ?? 0) > 0) {
    return refus(409, 'deja-utilise', 'Tu as déjà utilisé le pack Découverte.')
  }

  if (pack.price_fcfa === 0) {
    // Un pack gratuit n'a pas de transaction : il s'active directement.
    return refus(
      400,
      'pack-gratuit',
      'Ce pack est gratuit : active-le depuis la boutique.',
    )
  }

  const admin = createAdminClient()

  const { data: paiement, error: erreurPaiement } = await admin
    .from('payments')
    .insert({
      user_id: userId,
      provider: 'fedapay',
      amount_fcfa: pack.price_fcfa,
      operator: operateur,
      phone: numero.e164,
      status: 'pending',
      pack_code: packCode,
    })
    .select('id')
    .single()

  if (erreurPaiement || !paiement) {
    console.error('[paiement] création impossible', erreurPaiement)
    return refus(
      500,
      'serveur',
      'On n’a pas pu ouvrir le paiement. Réessaie dans un instant.',
    )
  }

  const echouer = async (motif: string, message: string, detail: unknown) => {
    await admin.from('payments').update({ status: 'failed' }).eq('id', paiement.id)
    console.error(`[paiement] ${motif}`, detail)
    return refus(502, motif, message)
  }

  const telephoneFedaPay = { national: numero.national, pays: numero.pays.code }

  // 1. La transaction et son jeton.
  const transaction = await fournisseur.initPayment({
    userId,
    paiementId: paiement.id,
    amount: pack.price_fcfa,
    packCode,
    client: {
      prenom: profil?.first_name ?? null,
      email: appelant.user.email ?? null,
      telephone: telephoneFedaPay,
    },
  })

  if (!transaction.ok) {
    return echouer(
      'fournisseur',
      'Le paiement n’a pas pu s’ouvrir. Réessaie dans un instant.',
      transaction.error,
    )
  }

  // `provider_ref` avant la demande : si le webhook arrive très vite, il
  // doit déjà pouvoir rattacher la transaction à ce paiement.
  await admin
    .from('payments')
    .update({
      provider_ref: transaction.transactionId,
      raw: { mode },
    })
    .eq('id', paiement.id)

  // 2. La demande, envoyée au téléphone.
  const demande = await fournisseur.envoyerDemande({
    token: transaction.token,
    mode,
    telephone: telephoneFedaPay,
  })

  if (!demande.ok) {
    return echouer(
      'demande-refusee',
      'La demande n’a pas pu partir vers ton téléphone. Vérifie le numéro et l’opérateur, puis réessaie.',
      demande.error,
    )
  }

  return Response.json({
    ok: true,
    data: {
      paiementId: paiement.id,
      transactionId: transaction.transactionId,
      montantFcfa: pack.price_fcfa,
    },
  })
}
