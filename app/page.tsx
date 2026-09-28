import Link from 'next/link'

/**
 * La page d'accueil publique.
 *
 * Elle n'existait pas : la racine était servie par `app/(app)/page.tsx`, le
 * tableau de bord de l'étudiant connecté. En retirant les écrans web que
 * Flutter remplace, `/` se serait retrouvée en 404 — c'est-à-dire la première
 * adresse qu'ouvre quelqu'un à qui on partage le lien.
 *
 * Elle dit ce qu'est Reviz et où prendre l'application. Rien de plus : le
 * produit est dans l'application, pas ici.
 */

export const metadata = {
  title: 'Reviz — réviser et faire corriger ses copies',
  description:
    'Reviz transforme tes cours en QCM, te prépare des fiches et corrige tes copies photographiées. Pour les étudiants du Bénin.',
}

export default function Accueil() {
  return (
    <main className="mx-auto flex min-h-screen w-full max-w-[440px] flex-col justify-center gap-space-24 px-space-16 py-space-32">
      <header className="flex flex-col gap-space-12">
        <p className="text-caption uppercase tracking-[0.04em] text-reviz-muted">
          Pour les étudiants du Bénin
        </p>
        <h1 className="text-display-hero-mobile text-reviz-ink">Reviz</h1>
        <p className="text-body-lg text-reviz-muted">
          Tes cours deviennent des QCM et des fiches. Tu photographies une
          copie, tu reçois une note et ce qu’il faut retravailler.
        </p>
      </header>

      <ul className="flex flex-col gap-space-8 text-body-md text-reviz-muted">
        <li>Des QCM, une question par écran, même sans réseau.</li>
        <li>Des fiches à retourner, chapitre par chapitre.</li>
        <li>Une correction de copie en une à deux minutes.</li>
        <li>Le classement de ta faculté, et un parrainage qui paie.</li>
      </ul>

      <Link
        href="/app"
        className="flex h-cta items-center justify-center rounded-xl bg-reviz-yellow text-headline-md text-reviz-on-yellow shadow-tactile active:translate-y-[2px] active:shadow-[0_2px_0_#d9a400]"
      >
        Installer l’application
      </Link>

      <p className="text-label-sm text-reviz-muted">
        Paiement par pack en Mobile Money, à durée limitée. Aucun prélèvement
        automatique : à la fin de la période, l’accès s’arrête, tout
        simplement.
      </p>
    </main>
  )
}
