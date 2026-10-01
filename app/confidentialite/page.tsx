import Link from 'next/link'

/**
 * Politique de confidentialité.
 *
 * Exigée par l'App Store (une adresse publique, saisie dans App Store
 * Connect) et par le Play Store. Écrite d'après ce que fait le code, pas
 * d'après un modèle : les seaux de `20260909180000_stockage.sql`, les
 * fournisseurs d'IA de `docs/STACK-IA.md`, l'anonymisation de
 * `/api/profile/delete`. Si l'un d'eux change, cette page change avec.
 */

export const metadata = {
  title: 'Confidentialité · Reviz',
  description: 'Ce que Reviz garde, pourquoi, et comment tout effacer.',
}

const MISE_A_JOUR = '1er octobre 2026'

const SECTIONS: { titre: string; paragraphes: string[] }[] = [
  {
    titre: 'Ce que Reviz garde',
    paragraphes: [
      'Ton compte : ton adresse e-mail, ton prénom, ton université, ta filière et ton année, ton avatar, ton code de parrainage.',
      'Ton numéro Mobile Money, seulement si tu le donnes : il sert à préremplir tes paiements, personne d’autre ne le voit.',
      'La photo de ta carte étudiante, si tu l’envoies : elle sert à vérifier qu’un compte correspond à une personne.',
      'Les cours que tu déposes, les copies que tu photographies, et ce que Reviz en tire : chapitres, questions, fiches, notes et corrections.',
      'Ta progression : tes réponses, tes points, ta série, ta ligue.',
      'Tes paiements et tes gains de parrainage : montant, opérateur, numéro utilisé, date.',
    ],
  },
  {
    titre: 'Pourquoi',
    paragraphes: [
      'Pour faire marcher l’application et rien d’autre : préparer tes révisions, corriger tes copies, tenir ta progression, activer ce que tu as payé et verser tes commissions. Reviz ne vend pas tes données, n’affiche pas de publicité et ne te suit pas d’une application à l’autre.',
    ],
  },
  {
    titre: 'Qui les voit',
    paragraphes: [
      'Les étudiants de ta faculté voient ton prénom, ton avatar et tes points dans le classement et la ligue. Un cours que tu choisis de partager avec ta faculté devient lisible par elle ; les autres restent à toi.',
      'Pour lire un cours ou une copie, Reviz envoie le texte ou la photo à un fournisseur d’intelligence artificielle : DeepSeek, et en secours Alibaba Cloud (Qwen) ou Zhipu (GLM). Leurs serveurs peuvent se trouver hors de ton pays, notamment en Chine et à Singapour. Ils traitent la demande et renvoient le résultat ; Reviz ne leur donne ni ton nom ni ton adresse.',
      'Les paiements passent par FedaPay, qui reçoit ton numéro, ton nom et ton adresse e-mail pour envoyer la demande de paiement sur ton téléphone.',
      'La base de données et les fichiers sont hébergés par Supabase, le site et le serveur par Vercel.',
    ],
  },
  {
    titre: 'Combien de temps',
    paragraphes: [
      'Tant que ton compte existe. Quand tu le supprimes — Profil, puis « Supprimer mon compte » —, ton nom, ton numéro, ta carte, tes cours, tes copies et tes fichiers sont effacés. Tes paiements restent en comptabilité, sans ton nom dessus : un registre financier ne se réécrit pas.',
    ],
  },
  {
    titre: 'Tes droits',
    paragraphes: [
      'Tu peux consulter et corriger ton profil dans l’application, et tout effacer depuis l’application, sans rien demander à personne. Pour toute autre question, écris-nous depuis l’application : Profil, Aide, puis « Nous écrire ».',
    ],
  },
]

export default function Confidentialite() {
  return (
    <main className="mx-auto flex min-h-screen w-full max-w-[640px] flex-col gap-space-20 px-space-16 py-space-32">
      <header className="flex flex-col gap-space-8">
        <h1 className="text-headline-xl text-reviz-ink">Confidentialité</h1>
        <p className="text-body-md text-reviz-muted">
          Ce que Reviz garde sur toi, pourquoi, et comment tout effacer. Mis à
          jour le {MISE_A_JOUR}.
        </p>
      </header>

      {SECTIONS.map(({ titre, paragraphes }) => (
        <section key={titre} className="flex flex-col gap-space-8">
          <h2 className="text-headline-md text-reviz-ink">{titre}</h2>
          {paragraphes.map((p) => (
            <p key={p} className="text-body-md text-reviz-muted">
              {p}
            </p>
          ))}
        </section>
      ))}

      <footer className="text-label-sm text-reviz-muted">
        <Link href="/" className="underline">
          Revenir à l’accueil
        </Link>
      </footer>
    </main>
  )
}
