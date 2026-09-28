import Link from 'next/link'

/**
 * Page de téléchargement de l'application.
 *
 * Réécrite sans le design system : `components/ui` a été retiré avec les
 * écrans web que Flutter remplace, et cette page n'a pas besoin de trois
 * composants pour montrer un bouton. Les classes viennent directement des
 * jetons de `tailwind.config.ts`, qui reste la source de vérité partagée avec
 * `docs/DESIGN.md` et le thème Flutter.
 *
 * Au passage, sept apostrophes échappées qui s'affichaient littéralement —
 * « Telecharger l\'APK », « Guide d\'installation » — et « signataire » pour
 * « signé ». C'était la première page que voyait un étudiant.
 */

export const metadata = {
  title: 'Installer Reviz',
  description:
    'Télécharge l’application Reviz pour réviser tes cours et faire corriger tes copies.',
}

const ETAPES = [
  'Autorise l’installation depuis ton navigateur, si Android le demande.',
  'Ouvre le fichier téléchargé depuis tes notifications ou l’application Fichiers.',
  'Appuie sur « Installer », puis ouvre Reviz.',
  'Connecte-toi avec ton adresse e-mail : un code à chiffres t’arrive par mail.',
]

export default function Telechargement() {
  return (
    <main className="mx-auto flex min-h-screen w-full max-w-[440px] flex-col gap-space-20 px-space-16 py-space-32">
      <header className="flex flex-col gap-space-8">
        <h1 className="text-headline-xl text-reviz-ink">Installer Reviz</h1>
        <p className="text-body-md text-reviz-muted">
          Reviz transforme tes cours en QCM, te prépare des fiches et corrige
          tes copies photographiées. L’application s’installe depuis un
          fichier, sans passer par le Play Store.
        </p>
      </header>

      {/* Ce que l'étudiant obtient, sans promesse que le produit ne tient pas
          encore : le dépôt de cours attend son traitement (lot IA). */}
      <section className="rounded-card bg-reviz-card p-space-16 shadow-card">
        <h2 className="text-headline-md text-reviz-ink">
          Ce que tu peux faire aujourd’hui
        </h2>
        <ul className="mt-space-12 flex flex-col gap-space-8 text-body-md text-reviz-muted">
          <li>Réviser en QCM, une question par écran, et suivre ta série.</li>
          <li>Retourner des fiches, chapitre par chapitre.</li>
          <li>Photographier une copie et recevoir une note détaillée.</li>
          <li>Voir le classement de ta faculté, et tes gains de parrainage.</li>
        </ul>
      </section>

      {/* Le fichier n'est pas encore publié : l'APK signé arrive avec le lot
          C. Annoncer un lien mort serait pire que de dire où l'on en est. */}
      <section className="rounded-card border-2 border-reviz-border bg-reviz-card p-space-16">
        <h2 className="text-headline-md text-reviz-ink">
          Le fichier arrive
        </h2>
        <p className="mt-space-8 text-body-md text-reviz-muted">
          La nouvelle version de l’application est en préparation. Le lien de
          téléchargement sera partagé ici et par WhatsApp dès qu’elle est
          signée.
        </p>
        {/* Pas de numéro en dur : l'ancienne version de cette page en portait
            un factice, et un lien mort vaut moins que pas de lien. Le contact
            réel viendra avec le lot C. */}
      </section>

      <section className="rounded-card bg-reviz-card p-space-16 shadow-card">
        <h2 className="text-headline-md text-reviz-ink">
          Comment l’installer
        </h2>
        <ol className="mt-space-12 flex flex-col gap-space-12">
          {ETAPES.map((etape, i) => (
            <li key={etape} className="flex gap-space-12">
              <span className="flex h-6 w-6 flex-shrink-0 items-center justify-center rounded-full bg-reviz-yellow text-label-md text-reviz-on-yellow">
                {i + 1}
              </span>
              <span className="text-body-md text-reviz-muted">{etape}</span>
            </li>
          ))}
        </ol>
      </section>

      <section className="rounded-card bg-reviz-surface-low p-space-16">
        <h2 className="text-label-lg text-reviz-ink">
          Si tu avais déjà une ancienne version
        </h2>
        <p className="mt-space-8 text-label-sm text-reviz-muted">
          Désinstalle-la avant d’installer celle-ci : les deux portent le même
          nom mais ne sont pas signées avec la même clé, et Android refuse alors
          de remplacer l’une par l’autre. Tes cours et ta progression sont sur
          nos serveurs, rien n’est perdu.
        </p>
      </section>

      <footer className="text-label-sm text-reviz-muted">
        <Link href="/" className="underline">
          Revenir à l’accueil
        </Link>
      </footer>
    </main>
  )
}
