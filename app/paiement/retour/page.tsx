/**
 * Où FedaPay renvoie l'étudiant après la page de paiement.
 *
 * Troisième page publique, et la seule qui n'est pas une vitrine : FedaPay
 * ramène le navigateur sur le `callback_url` de la transaction, avec
 * `?id=…&status=…`. Avant, cette adresse était celle du webhook — une route
 * qui ne répond qu'en POST : l'étudiant qui venait de payer tombait sur une
 * erreur 405.
 *
 * **Cette page ne décide de rien.** Le `status` de l'adresse est lisible et
 * modifiable par n'importe qui ; il ne sert qu'à choisir la phrase. L'accès
 * s'active par le webhook ou par le suivi de l'application
 * (`/api/payments/status`), qui interrogent FedaPay eux-mêmes.
 */

export const metadata = {
  title: 'Paiement Reviz',
  robots: { index: false },
}

type Issue = 'reussi' | 'echoue' | 'inconnu'

function issueDepuis(statut: string | undefined): Issue {
  if (statut === 'approved' || statut === 'transferred') return 'reussi'
  if (statut === 'declined' || statut === 'canceled' || statut === 'expired')
    return 'echoue'
  return 'inconnu'
}

const TEXTES: Record<Issue, { titre: string; corps: string }> = {
  reussi: {
    titre: 'Paiement reçu',
    corps:
      'Retourne dans Reviz : ton pack s’active dans quelques secondes. Tu peux fermer cette page.',
  },
  echoue: {
    titre: 'Le paiement n’est pas passé',
    corps:
      'Aucun montant n’a été prélevé. Retourne dans Reviz pour réessayer quand tu veux.',
  },
  inconnu: {
    titre: 'C’est noté',
    corps:
      'Retourne dans Reviz : l’application te dira dès que ton paiement est confirmé.',
  },
}

export default async function RetourPaiement({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>
}) {
  const params = await searchParams
  const statut = Array.isArray(params.status) ? params.status[0] : params.status
  const { titre, corps } = TEXTES[issueDepuis(statut)]

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-[440px] flex-col justify-center gap-space-12 px-space-16 py-space-32">
      <h1 className="text-headline-xl text-reviz-ink">{titre}</h1>
      <p className="text-body-md text-reviz-muted">{corps}</p>
    </main>
  )
}
