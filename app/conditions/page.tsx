import Link from 'next/link'

/**
 * Conditions générales d'utilisation et de vente.
 *
 * Comme `/confidentialite`, écrites d'après ce que fait le code et pas d'après
 * un modèle : les packs et leur cumul (`lib/payments/subscriptions.ts`), les
 * plafonds (CLAUDE.md, règle 5), la carte étudiante (`lib/metier/carte.ts`),
 * le cache par document (règle 4), les commissions suspendues
 * (`lib/payments/commission.ts`). Si l'un d'eux change, cette page change
 * avec, et `MISE_A_JOUR` aussi.
 *
 * `EDITEUR` est l'identité du vendeur, que des conditions de vente doivent
 * donner. Elle vient du propriétaire, jamais d'une supposition.
 */

export const metadata = {
  title: 'Conditions · Reviz',
  description: 'Ce que tu peux attendre de Reviz, ce que tu achètes avec un pack, et ce qui est interdit.',
}

const MISE_A_JOUR = '7 octobre 2026'

const EDITEUR = {
  nom: 'À COMPLÉTER',
  statut: 'À COMPLÉTER',
  siege: 'À COMPLÉTER',
  immatriculation: 'À COMPLÉTER',
  contact: 'À COMPLÉTER',
  tribunaux: 'À COMPLÉTER',
}

const SECTIONS: { titre: string; paragraphes: string[] }[] = [
  {
    titre: 'Qui édite Reviz',
    paragraphes: [
      `Reviz est édité par ${EDITEUR.nom} (${EDITEUR.statut}), ${EDITEUR.siege}, ${EDITEUR.immatriculation}. Pour nous joindre : ${EDITEUR.contact}, ou depuis l’application : Profil, Aide, puis « Nous écrire ».`,
      'En créant un compte, tu acceptes ces conditions. Elles valent pour l’application Android, l’application web et le site.',
    ],
  },
  {
    titre: 'Ce que fait Reviz',
    paragraphes: [
      'Tu déposes un cours (PDF, Word ou photos). Reviz en tire des questions à choix multiples, des fiches et les questions qui ont le plus de chances de tomber. Tu peux aussi photographier une copie pour la faire corriger et noter.',
      'Ces questions, ces fiches et ces corrections sont produites automatiquement par des outils d’intelligence artificielle, à partir de ce que tu envoies. Elles peuvent contenir des erreurs. Elles t’aident à réviser ; elles ne remplacent ni ton cours, ni tes enseignants, ni le barème officiel de ton examen. « Probable » veut dire probable : Reviz ne connaît pas les sujets à l’avance et ne promet aucune note.',
    ],
  },
  {
    titre: 'Ton compte',
    paragraphes: [
      'Un compte par personne. La photo de ta carte étudiante sert à le vérifier : une carte ne vaut que pour un seul compte. Les informations que tu donnes doivent être exactes.',
      'Tu es responsable de ce qui se fait avec ton compte. Tu peux le supprimer à tout moment depuis l’application : Profil, puis « Supprimer mon compte ».',
    ],
  },
  {
    titre: 'Tes cours et tes copies',
    paragraphes: [
      'Tu ne déposes que des documents que tu as le droit d’utiliser : tes propres notes, ou les supports que ton établissement te remet pour tes études. Ils restent à toi. Tu autorises Reviz à les lire et à les transformer pour te préparer tes révisions, et seulement pour cela.',
      'Un cours que tu choisis de partager avec ta faculté devient lisible par les étudiants de ta faculté. Quand un autre étudiant de ta faculté dépose exactement le même document, Reviz lui sert ce qui a déjà été préparé au lieu de tout refaire : seul le document identique est concerné, jamais tes réponses ni tes copies.',
    ],
  },
  {
    titre: 'Ce qui est interdit',
    paragraphes: [
      'Ouvrir plusieurs comptes, utiliser la carte d’un autre, se parrainer soi-même. Utiliser Reviz pendant une épreuve. Déposer un contenu illégal, haineux ou qui ne t’appartient pas. Revendre l’accès, copier en masse les contenus ou chercher à contourner les limites et les paiements.',
      'En cas de fraude, Reviz peut suspendre ou fermer le compte concerné, et retirer les avantages obtenus ainsi.',
    ],
  },
  {
    titre: 'Les packs',
    paragraphes: [
      'Reviz se paie par packs, d’une durée fixe : quelques jours, un mois, un semestre. Le prix, la durée, le nombre de matières et le nombre de corrections de chaque pack sont affichés dans l’application avant l’achat, en francs CFA. Le montant exact à payer s’affiche aussi sur ton téléphone avant que tu confirmes.',
      'Un pack se paie une seule fois. Il n’y a aucun abonnement, aucun prélèvement automatique et rien à résilier : à la fin de la durée, le pack s’arrête. Tes cours, tes questions, tes fiches et ton historique restent consultables ; il faut un nouveau pack pour ajouter un cours ou faire corriger une copie.',
      'Le pack commence dès que le paiement est confirmé. Acheter un pack pendant qu’un autre court ne repousse pas le premier : les deux comptent en même temps, et les corrections restantes s’additionnent.',
      'Le pack Découverte est gratuit, une seule fois par compte.',
      'Pour que le service reste rapide pour tout le monde, chaque pack a des limites : 150 pages par cours, 200 questions préparées par cours, 300 questions répondues par jour et 5 corrections par jour, même avec un pack sans limite de matières.',
    ],
  },
  {
    titre: 'Le paiement',
    paragraphes: [
      'Le paiement se fait par Mobile Money, par l’intermédiaire de FedaPay. La demande arrive sur ton téléphone, et c’est toi qui la valides avec ton code secret : Reviz ne voit jamais ce code. Le pack s’active quand FedaPay confirme le paiement.',
    ],
  },
  {
    titre: 'Remboursement',
    paragraphes: [
      'Un pack te donne accès tout de suite à un service numérique : une fois activé, il n’est pas remboursé pour un simple changement d’avis.',
      'Si ton compte Mobile Money a été débité et que ton pack ne s’est pas activé, écris-nous avec la date et le numéro utilisé : on active ton pack ou on te rembourse.',
      'Si une panne de notre côté t’empêche d’utiliser ce que ton pack prévoit, écris-nous dans les 7 jours : on prolonge ton pack d’autant, ou on te rembourse.',
    ],
  },
  {
    titre: 'Le parrainage',
    paragraphes: [
      'Ton code de parrainage te rapporte des points d’expérience (XP) quand un ami vérifié prend un pack avec ton code, une fois par ami. Les XP servent au classement et aux ligues ; ils n’ont aucune valeur en argent et ne s’échangent pas.',
      'Les commissions en argent sur les paiements de tes filleuls sont suspendues. Si elles reprennent, leurs règles seront publiées ici et annoncées dans l’application avant de s’appliquer.',
    ],
  },
  {
    titre: 'Disponibilité',
    paragraphes: [
      'Reviz fait de son mieux pour rester disponible, sans pouvoir le garantir à chaque instant : une maintenance, une panne d’un fournisseur ou une coupure du réseau peuvent l’interrompre. Ce qui est déjà préparé reste lisible sur ton téléphone sans réseau.',
      'Reviz n’est pas responsable d’une note, d’un échec à un examen ou d’une décision que tu prendrais à partir d’une question, d’une fiche ou d’une correction.',
    ],
  },
  {
    titre: 'Tes données',
    paragraphes: [
      'Ce que Reviz garde sur toi, pourquoi, et comment tout effacer est expliqué dans la page Confidentialité.',
    ],
  },
  {
    titre: 'Si ces conditions changent',
    paragraphes: [
      'Elles peuvent évoluer avec l’application. Un changement qui te concerne est annoncé dans l’application avant de s’appliquer. Un pack déjà payé reste régi par les conditions du jour de son achat.',
      `En cas de désaccord, on cherche d’abord une solution ensemble. À défaut, les tribunaux de ${EDITEUR.tribunaux} sont compétents.`,
    ],
  },
]

export default function Conditions() {
  return (
    <main className="mx-auto flex min-h-screen w-full max-w-[640px] flex-col gap-space-20 px-space-16 py-space-32">
      <header className="flex flex-col gap-space-8">
        <h1 className="text-headline-xl text-reviz-ink">Conditions d’utilisation et de vente</h1>
        <p className="text-body-md text-reviz-muted">
          Ce que tu peux attendre de Reviz, ce que tu achètes avec un pack, et
          ce qui est interdit. Mis à jour le {MISE_A_JOUR}.
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

      <footer className="flex flex-wrap gap-space-16 text-label-sm text-reviz-muted">
        <Link href="/confidentialite" className="underline">
          Confidentialité
        </Link>
        <Link href="/" className="underline">
          Revenir à l’accueil
        </Link>
      </footer>
    </main>
  )
}
