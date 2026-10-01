import Image from 'next/image'
import Link from 'next/link'
import { APK, tailleLisible, VERSION } from '@/lib/metier/publication'
import {
  chargerPacks,
  dureeLisible,
  FAQ,
  PACK_CONSEILLE,
  prixLisible,
} from '@/lib/metier/offre'

/**
 * La page d'accueil publique : pourquoi Reviz plutôt que ChatGPT, et où la
 * prendre.
 *
 * Mobile d'abord — le lien arrive par WhatsApp sur un Android milieu de
 * gamme —, légère (captures en WebP de 20 à 30 ko, chargées à la demande
 * sous le héros), et sans un mot technique. Les captures sont de vrais
 * écrans de l'application (bancs d'aperçu et émulateur), le panthéreau est
 * celui de l'application.
 *
 * Les prix viennent de la table `packs` (`lib/metier/offre.ts`), relus toutes
 * les heures ; le bouton de téléchargement de `lib/metier/publication.ts`,
 * comme `/app`.
 */

export const revalidate = 3600

export const metadata = {
  title: 'Reviz — ton cours, ton niveau, ta note',
  description:
    'Reviz transforme ton propre cours en QCM et en fiches, se souvient de tes erreurs et corrige tes copies d’après ton cours et ton année. Gratuit pour commencer, sans abonnement, paiement Mobile Money.',
  openGraph: {
    title: 'Reviz — ton cours, ton niveau, ta note',
    description:
      'Des QCM tirés de ton propre cours, des copies corrigées d’après ton année. Gratuit pour commencer.',
    locale: 'fr_FR',
    type: 'website',
  },
}

function BoutonTelecharger({ discret = false }: { discret?: boolean }) {
  const cible = APK.publie ? APK.url : '/app'
  return (
    <a
      href={cible}
      className={
        discret
          ? 'inline-flex h-11 items-center justify-center rounded-full bg-reviz-ink px-space-16 text-label-md text-white transition-transform active:scale-95'
          : 'flex h-14 w-full items-center justify-center gap-space-8 rounded-2xl bg-reviz-yellow px-space-20 text-headline-md text-reviz-on-yellow shadow-tactile transition-transform active:scale-[0.98] sm:w-auto'
      }
    >
      {discret ? 'Télécharger' : 'Télécharger l’application'}
    </a>
  )
}

function Telephone({
  src,
  alt,
  priorite = false,
  className = '',
}: {
  src: string
  alt: string
  priorite?: boolean
  className?: string
}) {
  return (
    <div
      className={`relative w-full max-w-[260px] rounded-[40px] bg-reviz-ink p-[10px] shadow-[0_24px_60px_-20px_rgba(29,29,31,0.45)] ${className}`}
    >
      <div className="overflow-hidden rounded-[30px] bg-surface">
        <Image
          src={src}
          alt={alt}
          width={390}
          height={844}
          priority={priorite}
          sizes="260px"
          className="h-auto w-full"
        />
      </div>
    </div>
  )
}

function Panthere({
  pose,
  taille = 96,
  alt = '',
  className = '',
}: {
  pose: string
  taille?: number
  alt?: string
  className?: string
}) {
  return (
    <Image
      src={`/landing/panthereau-${pose}.webp`}
      alt={alt}
      width={taille}
      height={taille}
      className={className}
    />
  )
}

const CONTRASTES = [
  {
    eux: 'Un assistant ne connaît pas ton cours : il répond avec ce qu’il sait, pas avec ce que ton professeur a enseigné.',
    nous: 'Reviz lit ton propre cours — PDF, Word ou photo — et en tire des QCM et des fiches, chapitre par chapitre.',
  },
  {
    eux: 'Il corrige « dans l’absolu » : il sanctionne ce qui n’était pas au programme et attend d’un L1 la rigueur d’un master.',
    nous: 'Reviz corrige ta copie d’après ton cours, ton année et ta filière, et te dit quels chapitres revoir.',
  },
  {
    eux: 'Il oublie tout d’une conversation à l’autre.',
    nous: 'Reviz se souvient de tes erreurs : tes séries reviennent sur ce que tu rates, jusqu’à ce que ce soit acquis.',
  },
]

const ETAPES = [
  {
    pose: 'envoi',
    titre: 'Dépose ton cours',
    texte: 'Un PDF, un Word ou des photos. En une à deux minutes, il devient un chemin de chapitres avec leurs QCM et leurs fiches.',
  },
  {
    pose: 'enRoute',
    titre: 'Avance sur ton chemin',
    texte: 'Dix questions par série, les plus probables à l’examen d’abord. Chaque chapitre se gagne en trois couronnes.',
  },
  {
    pose: 'stylo',
    titre: 'Fais corriger ta copie',
    texte: 'Photographie jusqu’à quatre pages. Tu reçois une note détaillée, les notions manquées et les chapitres à revoir.',
  },
]

const RAISONS = [
  { pose: 'niveau', titre: 'Des niveaux', texte: 'Chaque bonne réponse te rapproche du niveau suivant.' },
  { pose: 'medaille', titre: 'Ta ligue de la semaine', texte: 'Trente étudiants, les sept premiers montent. De Bronze à Diamant.' },
  { pose: 'flamme', titre: 'Ta série', texte: 'Dix questions par jour, et ta flamme ne s’éteint pas.' },
  { pose: 'reveil', titre: 'Des rappels', texte: 'Ta série le soir, ton examen à J-3 et à J-1.' },
  { pose: 'reflexion', titre: 'Même sans réseau', texte: 'Tes séries sont gardées et partent au retour de la connexion.' },
  { pose: 'telephone', titre: 'Léger', texte: 'Une application de 60 Mo, pensée pour un forfait data limité.' },
]

export default async function Accueil() {
  const packs = await chargerPacks()

  return (
    <div className="min-h-screen bg-surface text-reviz-ink">
      {/* --- Barre du haut */}
      <header className="sticky top-0 z-20 border-b border-black/5 bg-surface/85 pt-safe backdrop-blur-md">
        <div className="mx-auto flex h-16 max-w-5xl items-center justify-between px-space-16">
          <Link href="/" className="flex items-center gap-space-8">
            <Image src="/landing/logo.png" alt="" width={32} height={32} />
            <span className="text-headline-lg">Reviz</span>
          </Link>
          <BoutonTelecharger discret />
        </div>
      </header>

      <main>
        {/* --- Héros */}
        <section className="mx-auto grid max-w-5xl items-center gap-space-40 px-space-16 pb-space-48 pt-space-32 md:grid-cols-[1.1fr_0.9fr] md:pt-space-48">
          <div className="flex flex-col gap-space-20">
            <p className="text-caption uppercase text-reviz-muted">
              Pour les étudiants du Bénin, du Togo et de Côte d’Ivoire
            </p>
            <h1 className="text-[44px] font-extrabold leading-[1.02] tracking-[-0.03em] sm:text-[60px]">
              Ton cours.
              <br />
              Ton niveau.
              <br />
              <span className="bg-reviz-yellow px-2 box-decoration-clone">Ta note.</span>
            </h1>
            <p className="max-w-[34ch] text-body-lg text-reviz-muted">
              Reviz transforme ton propre cours en QCM, se souvient de tes
              erreurs et corrige tes copies d’après ce que ton professeur a
              enseigné.
            </p>
            <div className="flex flex-col gap-space-12 sm:flex-row sm:items-center">
              <BoutonTelecharger />
              <a
                href="#comment"
                className="flex h-14 items-center justify-center rounded-2xl px-space-20 text-label-lg text-reviz-ink underline-offset-4 hover:underline"
              >
                Voir comment ça marche
              </a>
            </div>
            <ul className="flex flex-wrap gap-x-space-16 gap-y-space-8 text-label-sm text-reviz-muted">
              <li>✓ Gratuit pour commencer</li>
              <li>✓ Sans abonnement</li>
              <li>✓ Paiement Mobile Money</li>
            </ul>
            {APK.publie && (
              <p className="text-label-sm text-reviz-muted">
                Android · version {VERSION} · {tailleLisible(APK.tailleOctets)}
              </p>
            )}
          </div>
          <div className="relative mx-auto w-full max-w-[300px]">
            <Telephone
              src="/landing/ecran-chemin.webp"
              alt="Le chemin des chapitres d’un cours, avec ses couronnes"
              priorite
            />
            <Panthere
              pose="salut"
              taille={120}
              alt="Le panthéreau Reviz te fait signe"
              className="absolute -bottom-6 -left-10 w-28 drop-shadow-xl sm:-left-16 sm:w-32"
            />
          </div>
        </section>

        {/* --- Pourquoi pas ChatGPT */}
        <section className="bg-white">
          <div className="mx-auto max-w-5xl px-space-16 py-space-48">
            <h2 className="text-headline-xl sm:text-[34px] sm:leading-[40px]">
              Pourquoi pas simplement ChatGPT ?
            </h2>
            <p className="mt-space-8 max-w-[60ch] text-body-lg text-reviz-muted">
              Un assistant généraliste répond bien. Mais il ne révise pas avec
              toi, et il ne sait pas ce qui tombera à <em>ton</em> examen.
            </p>
            <div className="mt-space-32 grid gap-space-16 md:grid-cols-3">
              {CONTRASTES.map((c) => (
                <article
                  key={c.nous}
                  className="flex flex-col gap-space-12 rounded-card bg-surface p-space-20"
                >
                  <div className="flex flex-col gap-space-4">
                    <p className="text-caption uppercase text-reviz-muted">
                      ✕ Un assistant généraliste
                    </p>
                    <p className="text-body-md text-reviz-muted">{c.eux}</p>
                  </div>
                  <div className="flex flex-col gap-space-4 border-t border-black/5 pt-space-12">
                    <p className="text-caption uppercase text-reviz-ink">
                      <span className="mr-1 inline-block rounded-full bg-reviz-yellow px-1.5">✓</span>
                      Reviz
                    </p>
                    <p className="text-body-lg font-bold text-reviz-ink">{c.nous}</p>
                  </div>
                </article>
              ))}
            </div>
          </div>
        </section>

        {/* --- Comment ça marche */}
        <section id="comment" className="mx-auto max-w-5xl scroll-mt-20 px-space-16 py-space-48">
          <h2 className="text-headline-xl sm:text-[34px] sm:leading-[40px]">Comment ça marche</h2>
          <ol className="mt-space-32 grid gap-space-16 md:grid-cols-3">
            {ETAPES.map((e, i) => (
              <li key={e.titre} className="flex flex-col gap-space-12 rounded-card bg-white p-space-20 shadow-card">
                <div className="flex items-center justify-between">
                  <span className="flex h-9 w-9 items-center justify-center rounded-full bg-reviz-yellow text-label-lg">
                    {i + 1}
                  </span>
                  <Panthere pose={e.pose} taille={72} className="h-16 w-16" />
                </div>
                <h3 className="text-headline-md">{e.titre}</h3>
                <p className="text-body-md text-reviz-muted">{e.texte}</p>
              </li>
            ))}
          </ol>
          <div className="mt-space-40 flex snap-x snap-mandatory gap-space-20 overflow-x-auto pb-space-8 md:justify-center md:overflow-visible">
            {[
              ['/landing/ecran-session.webp', 'Une question de QCM tirée du cours'],
              ['/landing/ecran-correction.webp', 'Une copie corrigée : 27,5 sur 40, et les chapitres à revoir'],
              ['/landing/ecran-ligue.webp', 'La ligue de la semaine'],
            ].map(([src, alt]) => (
              <figure key={src} className="w-[220px] shrink-0 snap-center md:w-[240px]">
                <Telephone src={src} alt={alt} />
                <figcaption className="mt-space-12 text-center text-label-sm text-reviz-muted">
                  {alt}
                </figcaption>
              </figure>
            ))}
          </div>
        </section>

        {/* --- Ce qui fait revenir */}
        <section className="bg-white">
          <div className="mx-auto max-w-5xl px-space-16 py-space-48">
            <h2 className="text-headline-xl sm:text-[34px] sm:leading-[40px]">
              Réviser un peu chaque jour, pour de vrai
            </h2>
            <div className="mt-space-32 grid gap-space-12 sm:grid-cols-2 lg:grid-cols-3">
              {RAISONS.map((r) => (
                <div key={r.titre} className="flex items-center gap-space-16 rounded-card bg-surface p-space-16">
                  <Panthere pose={r.pose} taille={64} className="h-14 w-14 shrink-0" />
                  <div>
                    <h3 className="text-headline-sm">{r.titre}</h3>
                    <p className="text-body-md text-reviz-muted">{r.texte}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* --- Prix */}
        <section id="prix" className="mx-auto max-w-5xl px-space-16 py-space-48">
          <h2 className="text-headline-xl sm:text-[34px] sm:leading-[40px]">Des packs, pas d’abonnement</h2>
          <p className="mt-space-8 max-w-[60ch] text-body-lg text-reviz-muted">
            Tu paies une fois en Mobile Money, pour une durée précise. À la
            fin, rien n’est prélevé : l’accès s’arrête, et tes cours restent à
            toi pour réviser gratuitement.
          </p>
          <div className="mt-space-32 grid gap-space-12 sm:grid-cols-2 lg:grid-cols-5">
            {packs.map((p) => {
              const conseille = p.code === PACK_CONSEILLE
              return (
                <article
                  key={p.code}
                  className={`flex flex-col gap-space-8 rounded-card p-space-16 ${
                    conseille ? 'bg-reviz-ink text-white shadow-card' : 'bg-white shadow-card-sm'
                  }`}
                >
                  <div className="flex items-center justify-between gap-space-8">
                    <h3 className="text-headline-md">{p.label}</h3>
                    {conseille && (
                      <span className="rounded-full bg-reviz-yellow px-space-8 py-space-2 text-caption text-reviz-on-yellow">
                        Conseillé
                      </span>
                    )}
                  </div>
                  <p className="text-[28px] font-extrabold leading-8 tabular-nums">{prixLisible(p.prixFcfa)}</p>
                  <p className={`text-label-sm ${conseille ? 'text-white/70' : 'text-reviz-muted'}`}>
                    {dureeLisible(p.jours)} · {p.matieres === null ? 'toutes tes matières' : `${p.matieres} matière${p.matieres > 1 ? 's' : ''}`} · {p.corrections} correction{p.corrections > 1 ? 's' : ''}
                  </p>
                  <p className={`text-body-md ${conseille ? 'text-white/85' : 'text-reviz-muted'}`}>{p.description}</p>
                </article>
              )
            })}
          </div>
          <p className="mt-space-16 text-label-sm text-reviz-muted">
            MTN et Moov au Bénin, Moov et Togocel au Togo, MTN en Côte d’Ivoire, Free au Sénégal.
          </p>
        </section>

        {/* --- Parrainage */}
        <section className="bg-reviz-yellow">
          <div className="mx-auto flex max-w-5xl flex-col items-start gap-space-24 px-space-16 py-space-48 sm:flex-row sm:items-center">
            <div className="flex shrink-0 -space-x-6">
              <Panthere pose="amis" taille={120} className="h-28 w-28" />
              <Panthere pose="pieces" taille={120} className="h-28 w-28" />
            </div>
            <div>
              <h2 className="text-headline-xl text-reviz-on-yellow sm:text-[34px] sm:leading-[40px]">
                Invite ta promo, gagne 25 %
              </h2>
              <p className="mt-space-8 max-w-[56ch] text-body-lg text-reviz-on-yellow/80">
                Chaque fois qu’un camarade que tu as invité paie un pack, 25 %
                du montant arrivent dans ton portefeuille, pendant douze mois.
                Tu retires en Mobile Money dès 3 000 F.
              </p>
            </div>
          </div>
        </section>

        {/* --- FAQ */}
        <section id="questions" className="mx-auto max-w-3xl px-space-16 py-space-48">
          <h2 className="text-headline-xl sm:text-[34px] sm:leading-[40px]">Tes questions</h2>
          <div className="mt-space-24 flex flex-col gap-space-8">
            {FAQ.map((q) => (
              <details key={q.question} className="group rounded-card bg-white p-space-16 shadow-card-sm">
                <summary className="flex cursor-pointer list-none items-center justify-between gap-space-12 text-headline-sm">
                  {q.question}
                  <span aria-hidden className="text-headline-lg text-reviz-muted transition-transform group-open:rotate-45">+</span>
                </summary>
                <p className="mt-space-12 text-body-md text-reviz-muted">{q.reponse}</p>
              </details>
            ))}
          </div>
        </section>

        {/* --- Dernier appel */}
        <section className="mx-auto max-w-5xl px-space-16 pb-space-48">
          <div className="flex flex-col items-center gap-space-16 rounded-hero bg-reviz-ink px-space-20 py-space-40 text-center text-white">
            <Panthere pose="cadeau" taille={120} alt="Le panthéreau te tend un cadeau" className="h-28 w-28" />
            <h2 className="text-headline-xl">Ton premier pack est offert</h2>
            <p className="max-w-[44ch] text-body-lg text-white/75">
              Installe Reviz, dépose un cours, et révise ce soir. Trois jours
              pour essayer, sans payer.
            </p>
            <div className="w-full max-w-sm">
              <BoutonTelecharger />
            </div>
            <Link href="/app" className="text-label-md text-white/70 underline underline-offset-4">
              Comment installer l’application
            </Link>
          </div>
        </section>
      </main>

      <footer className="border-t border-black/5">
        <div className="mx-auto flex max-w-5xl flex-col gap-space-8 px-space-16 py-space-24 pb-safe text-label-sm text-reviz-muted sm:flex-row sm:justify-between">
          <p>© 2026 Reviz · Fait pour les étudiants d’Afrique francophone</p>
          <p>
            <Link href="/app" className="underline underline-offset-4">Installer</Link>
            {' · '}
            <a href="#prix" className="underline underline-offset-4">Prix</a>
            {' · '}
            <a href="#questions" className="underline underline-offset-4">Questions</a>
            {' · '}
            <Link href="/confidentialite" className="underline underline-offset-4">Confidentialité</Link>
          </p>
        </div>
      </footer>
    </div>
  )
}
