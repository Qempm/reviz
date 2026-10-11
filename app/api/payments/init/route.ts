import { z } from 'zod'
import { authentifier, refusSession } from '@/lib/supabase/jeton'
import { createAdminClient } from '@/lib/supabase/admin'
import {
  createPaymentProvider,
  type PaymentProvider,
} from '@/lib/payments/provider'
import { normaliserTelephone } from '@/lib/auth/phone'
import { MOYEN_CARTE, modeFedaPay, OPERATEURS } from '@/lib/metier/operateurs'

/**
 * POST /api/payments/init
 *
 * Ouvre un paiement, de deux façons.
 *
 * **Mobile Money (`moyen: 'mobile'`, par défaut), entièrement dans
 * l'application** : la route crée la transaction FedaPay, puis envoie la
 * demande directement au téléphone de l'étudiant (`POST /v1/{mode}`). Il la
 * valide avec son code secret ; l'application suit l'issue par
 * `/api/payments/status?id=…`. Seuls les opérateurs payables « sans
 * redirection » sont acceptés (`lib/metier/operateurs.ts`).
 *
 * **Carte bancaire (`moyen: 'carte'`, 11 octobre 2026), pour tout le monde**,
 * même hors des pays où Reviz a un opérateur : FedaPay n'accepte la carte
 * que sur sa page de paiement hébergée. La route rend son adresse (`url`),
 * que l'application ouvre dans le navigateur ; FedaPay y renvoie l'étudiant
 * à la fin (`/paiement/retour`). Le statut de ce retour ne décide rien :
 * l'issue arrive par le webhook ou par `/api/payments/status`, comme pour le
 * Mobile Money. Ni opérateur ni numéro n'est exigé.
 *
 * **Le client ne dit que son moyen, son numéro et son opérateur.** Le prix
 * vient de la base, le prénom du profil, l'e-mail de la session : un appel
 * bricolé ne choisit ni combien payer, ni au nom de qui.
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
  // Absent : Mobile Money, comme avant la 2.10.0.
  moyen: z.enum(['mobile', MOYEN_CARTE]).optional(),
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
  const carte = analyse.data.moyen === MOYEN_CARTE
  const userId = appelant.user.id

  if (!carte && (!operateur || !telephone)) {
    return refus(
      426,
      'mise-a-jour',
      'Mets Reviz à jour pour payer : le paiement se fait maintenant sans quitter l’application.',
    )
  }

  // Le numéro : exigé pour le Mobile Money, facultatif pour la carte (il
  // aide FedaPay à reconnaître le client, rien de plus).
  const numero = telephone ? normaliserTelephone(telephone) : null
  if (!carte && !numero?.ok) {
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
      'Le paiement n’est pas encore disponible.',
    )
  }

  let mode: string | null = null
  if (!carte) {
    if (!numero?.ok || !operateur) return refus(400, 'entree-invalide', 'Vérifie le numéro.')
    mode = modeFedaPay(operateur, numero.pays.code, fournisseur.sandbox)
    if (!mode) {
      return refus(
        400,
        'operateur-indisponible',
        `Cet opérateur ne se paie pas encore dans Reviz pour ce pays (${numero.pays.nom}).`,
      )
    }
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
        .select('first_name, phone')
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

  // Pour la carte sans numéro saisi, celui du profil s'il est valable.
  const numeroClient =
    numero?.ok
      ? numero
      : profil?.phone
        ? normaliserTelephone(profil.phone)
        : null
  const telephoneFedaPay = numeroClient?.ok
    ? { national: numeroClient.national, pays: numeroClient.pays.code }
    : null

  const admin = createAdminClient()

  const { data: paiement, error: erreurPaiement } = await admin
    .from('payments')
    .insert({
      user_id: userId,
      provider: 'fedapay',
      amount_fcfa: pack.price_fcfa,
      operator: carte ? MOYEN_CARTE : operateur,
      phone: carte ? null : numero?.ok ? numero.e164 : null,
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

  // 1. La transaction et son jeton. Pour la carte, FedaPay renvoie
  //    l'étudiant sur notre page de retour, servie par ce même domaine.
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
    ...(carte
      ? {
          callbackUrl: `${new URL(request.url).origin}/paiement/retour?paiement=${paiement.id}`,
        }
      : {}),
  })

  if (!transaction.ok) {
    return echouer(
      'fournisseur',
      'Le paiement n’a pas pu s’ouvrir. Réessaie dans un instant.',
      transaction.error,
    )
  }

  if (carte && !transaction.url) {
    return echouer(
      'fournisseur',
      'La page de paiement par carte n’a pas pu s’ouvrir. Réessaie dans un instant.',
      'jeton sans url',
    )
  }

  // `provider_ref` avant la demande : si le webhook arrive très vite, il
  // doit déjà pouvoir rattacher la transaction à ce paiement.
  await admin
    .from('payments')
    .update({
      provider_ref: transaction.transactionId,
      raw: carte ? { moyen: MOYEN_CARTE } : { mode },
    })
    .eq('id', paiement.id)

  // 2. Mobile Money : la demande, envoyée au téléphone. La carte se paie
  //    sur la page FedaPay, que l'application ouvre.
  if (!carte && mode && telephoneFedaPay) {
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
  }

  return Response.json({
    ok: true,
    data: {
      paiementId: paiement.id,
      transactionId: transaction.transactionId,
      montantFcfa: pack.price_fcfa,
      ...(carte ? { url: transaction.url } : {}),
    },
  })
}
