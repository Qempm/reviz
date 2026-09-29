import Link from 'next/link'
import {
  APK,
  tailleLisible,
  VERSION,
} from '@/lib/metier/publication'

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
  'Connecte-toi avec ton adresse e-mail : un code à 6 chiffres t’arrive par mail.',
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

      {/* Ce que l'étudiant obtient. Le dépôt de cours y est entré quand les
          traitements `ingest_course` et `generate_questions` ont existé : cette
          liste ne promet que ce qui marche. */}
      <section className="rounded-card bg-reviz-card p-space-16 shadow-card">
        <h2 className="text-headline-md text-reviz-ink">
          Ce que tu peux faire aujourd’hui
        </h2>
        <ul className="mt-space-12 flex flex-col gap-space-8 text-body-md text-reviz-muted">
          <li>
            Déposer un cours en PDF, Word ou photo : Reviz en tire des QCM et
            des fiches.
          </li>
          <li>Réviser en QCM, une question par écran, et suivre ta série.</li>
          <li>Retourner des fiches, chapitre par chapitre.</li>
          <li>Photographier une copie et recevoir une note détaillée.</li>
          <li>Voir le classement de ta faculté, et tes gains de parrainage.</li>
        </ul>
      </section>

      {/* Le bouton n'apparaît que quand le fichier existe vraiment. Annoncer
          un lien mort vaut moins que dire où l'on en est — et un APK signé
          avec la clé de débogage ne serait pas un APK publiable : Android
          refuserait plus tard de le remplacer par le vrai. */}
      {APK.publie ? (
        <section className="rounded-card bg-reviz-card p-space-16 shadow-card">
          <h2 className="text-headline-md text-reviz-ink">Télécharger</h2>
          <a
            href={APK.url}
            className="mt-space-12 flex h-14 items-center justify-center rounded-xl bg-reviz-yellow text-headline-md text-reviz-on-yellow shadow-tactile active:translate-y-[2px]"
          >
            Télécharger Reviz {VERSION}
          </a>
          <dl className="mt-space-12 flex flex-col gap-space-8 text-label-sm text-reviz-muted">
            <div className="flex justify-between gap-space-8">
              <dt>Taille</dt>
              <dd>{tailleLisible(APK.tailleOctets)}</dd>
            </div>
            <div className="flex flex-col gap-space-4">
              <dt>Empreinte SHA-256</dt>
              {/* Pour qui veut vérifier que le fichier reçu par WhatsApp est
                  bien le nôtre : `sha256sum reviz.apk`. Le lien se partage de
                  main en main, donc il peut être remplacé en route. */}
              <dd className="break-all font-mono text-reviz-ink">
                {APK.sha256}
              </dd>
            </div>
          </dl>
        </section>
      ) : (
        <section className="rounded-card border-2 border-reviz-border bg-reviz-card p-space-16">
          <h2 className="text-headline-md text-reviz-ink">Le fichier arrive</h2>
          <p className="mt-space-8 text-body-md text-reviz-muted">
            La version {VERSION} est prête, mais pas encore signée : sans clé
            de signature, Android l’installerait puis refuserait toute mise à
            jour. Le lien sera partagé ici et par WhatsApp dès que c’est fait.
          </p>
        </section>
      )}

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
        {/* Deux cas, et ils appellent deux gestes opposés. Depuis la 2.0.0,
            toutes les versions sont signées avec la même clé : Android les
            installe par-dessus, sans rien perdre. Seule l'ancienne version 1
            — une coquille web signée d'une autre clé — doit partir d'abord.
            Le texte précédent disait à tout le monde de désinstaller, ce
            qui, une fois la 2.0.1 sortie, aurait fait désinstaller pour rien
            tous ceux qui avaient la 2.0.0. */}
        <h2 className="text-label-lg text-reviz-ink">
          Si tu avais déjà Reviz
        </h2>
        <p className="mt-space-8 text-label-sm text-reviz-muted">
          Depuis la version 2, installe simplement par-dessus : la mise à jour
          remplace l’ancienne sans rien perdre.
        </p>
        <p className="mt-space-8 text-label-sm text-reviz-muted">
          Si tu as encore la toute première version (la 1), désinstalle-la
          d’abord : elle n’est pas signée avec la même clé, et Android refuse de
          la remplacer. Tes cours et ta progression sont sur nos serveurs, rien
          n’est perdu.
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
