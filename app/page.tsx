import Image from 'next/image'
import Link from 'next/link'
import { APK, tailleLisible, VERSION } from '@/lib/metier/publication'
import {
  chargerPacks,
  correctionsLisibles,
  FAQ,
  matieresLisibles,
  meilleurPrixParJour,
  PACK_CONSEILLE,
} from '@/lib/metier/offre'
import { operateursDuPays } from '@/lib/metier/operateurs'
import { SelecteurPacks } from './SelecteurPacks'

/**
 * La page d'accueil publique : pourquoi Reviz plutôt que ChatGPT, et où la
 * prendre.
 *
 * **Identité du 3 octobre 2026** (`docs/DESIGN.md` § 11 ter), la même que
 * l'application : fond crème, cartes blanches à ombres douces teintées
 * d'encre, jaune pour l'action, Fredoka pour les titres, Inter pour le texte,
 * panthéreau en 3D. Elle remplace l'habit « Page Tarifs » du 1er octobre
 * (bordures de 2 px, ombres franches, jetons `papier.*`), retiré. Maquette
 * validée sur le canevas « Reviz — page d'accueil ».
 *
 * Mobile d'abord — le lien arrive par WhatsApp sur un Android milieu de
 * gamme —, légère (images en WebP), et sans un mot technique. Les captures
 * sont de vrais écrans de l'application (`test_apercus/studio_test.dart`),
 * le panthéreau est celui de l'application.
 *
 * Les prix viennent de la table `packs` (`lib/metier/offre.ts`), relus toutes
 * les heures ; les opérateurs, de `lib/metier/operateurs.ts` ; le bouton de
 * téléchargement, de `lib/metier/publication.ts`, comme `/app`.
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

const LIEN = APK.publie ? APK.url : '/app'

// Les classes qui reviennent.
const CONTENU = 'mx-auto max-w-[1200px] px-4 sm:px-8 lg:px-10'
const CARTE = 'rounded-[28px] bg-reviz-card shadow-card'
const TITRE_SECTION =
  'text-balance text-center font-titre text-[32px] leading-[1.05] sm:text-[44px] lg:text-[52px]'
const SOUS_TITRE = 'max-w-[640px] text-balance text-center text-[17px] leading-relaxed text-reviz-muted sm:text-lg'
const BOUTON_JAUNE =
  'inline-flex min-h-[60px] items-center justify-center gap-2.5 rounded-[20px] bg-reviz-yellow px-7 text-lg font-bold text-reviz-ink no-underline shadow-lueur transition-transform active:scale-[0.97] motion-reduce:transition-none'
const BOUTON_BLANC =
  'inline-flex min-h-[60px] items-center justify-center rounded-[20px] bg-reviz-card px-6 text-[17px] font-bold text-reviz-ink no-underline shadow-card transition-transform active:scale-[0.97] motion-reduce:transition-none'
const PUCE = 'inline-flex items-center gap-1.5 rounded-xl bg-reviz-surface-low px-3 py-2 text-sm font-semibold'
const ETIQUETTE =
  'inline-flex items-center gap-2 rounded-full bg-reviz-card px-3.5 py-2 text-sm font-semibold text-reviz-muted shadow-card-sm'

const trait = {
  fill: 'none',
  stroke: 'currentColor',
  strokeLinecap: 'round' as const,
  strokeLinejoin: 'round' as const,
}

function Coche({ taille = 16, epaisseur = 3 }: { taille?: number; epaisseur?: number }) {
  return (
    <svg width={taille} height={taille} viewBox="0 0 24 24" strokeWidth={epaisseur} {...trait} aria-hidden>
      <path d="M5 12.5l4.5 4.5L19 7.5" />
    </svg>
  )
}

function CocheJaune({ taille = 28 }: { taille?: number }) {
  return (
    <span
      className="inline-flex shrink-0 items-center justify-center rounded-[10px] bg-reviz-yellow"
      style={{ width: taille, height: taille }}
    >
      <Coche taille={Math.round(taille * 0.54)} epaisseur={3.2} />
    </span>
  )
}

function IconeTelecharger() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" strokeWidth="2.6" {...trait} aria-hidden>
      <path d="M12 4v11" />
      <path d="M7 10l5 5 5-5" />
      <path d="M5 20h14" />
    </svg>
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
    <div className={`rounded-[42px] bg-reviz-ink p-2.5 shadow-telephone ${className}`}>
      <Image
        src={src}
        alt={alt}
        width={780}
        height={1688}
        priority={priorite}
        sizes="(max-width: 640px) 240px, 282px"
        className="block h-auto w-full rounded-[32px]"
      />
    </div>
  )
}

function Panthere({ pose, taille, alt = '', className = '' }: { pose: string; taille: number; alt?: string; className?: string }) {
  return (
    <Image src={`/landing/panthereau-${pose}.webp`} alt={alt} width={taille} height={taille} className={className} />
  )
}

const CONTRASTES = [
  {
    eux: 'Il ne connaît pas ton cours : il répond avec ce qu’il sait, pas avec ce que ton professeur a enseigné.',
    nous: 'Il lit ton propre cours — PDF, Word ou photo — et en tire des QCM et des fiches, chapitre par chapitre.',
  },
  {
    eux: 'Il corrige « dans l’absolu » : il sanctionne ce qui n’était pas au programme et attend d’un L1 la rigueur d’un master.',
    nous: 'Il corrige ta copie d’après ton cours, ton année et ta filière, et te dit quels chapitres revoir.',
  },
  {
    eux: 'Il oublie tout d’une conversation à l’autre.',
    nous: 'Il se souvient de tes erreurs : tes séries reviennent sur ce que tu rates, jusqu’à ce que ce soit acquis.',
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

const ECRANS = [
  { src: '/landing/ecran-session.webp', alt: 'Une question de QCM tirée du cours', legende: 'Une question tirée de ton cours' },
  {
    src: '/landing/ecran-correction.webp',
    alt: 'Une copie corrigée : 27,5 sur 40, et les chapitres à revoir',
    legende: 'Ta copie corrigée, barème à l’appui',
  },
  { src: '/landing/ecran-ligue.webp', alt: 'La ligue de la semaine', legende: 'Ta ligue de la semaine' },
]

const RAISONS = [
  { pose: 'niveau', titre: 'Des niveaux', texte: 'Chaque bonne réponse te rapproche du niveau suivant.' },
  { pose: 'medaille', titre: 'Ta ligue de la semaine', texte: 'Trente étudiants, les sept premiers montent. De Bronze à Diamant.' },
  { pose: 'flamme', titre: 'Ta série', texte: 'Dix questions par jour, et ta flamme ne s’éteint pas.' },
  { pose: 'reveil', titre: 'Des rappels', texte: 'Ta série le soir, à l’heure que tu choisis. Ton examen à J-3 et à J-1.' },
  { pose: 'reflexion', titre: 'Même sans réseau', texte: 'Tes séries sont gardées et partent au retour de la connexion.' },
  { pose: 'telephone', titre: 'Léger', texte: 'Une application pensée pour un forfait data limité.' },
]

const ENGAGEMENTS = [
  'Paiement unique, jamais de prélèvement',
  'Tes cours restent à toi, même après ton pack',
  'Sur Android, et dans le navigateur d’un ordinateur ou d’un iPhone',
]

/** Les pays, et les opérateurs payables dans l'application (`operateurs.ts`). */
const PAYS = [
  { code: 'BJ', nom: 'Bénin' },
  { code: 'TG', nom: 'Togo' },
  { code: 'CI', nom: 'Côte d’Ivoire' },
  { code: 'SN', nom: 'Sénégal' },
]

const NOMS_OPERATEURS: Record<string, string> = {
  mtn: 'MTN',
  moov: 'Moov',
  celtiis: 'Celtiis',
  togocel: 'Togocel',
  free: 'Free',
}

export default async function Accueil() {
  const packs = await chargerPacks()
  const payants = packs.filter((p) => p.prixFcfa > 0)
  const decouverte = packs.find((p) => p.prixFcfa === 0)

  return (
    <div id="haut" className="min-h-screen overflow-x-hidden bg-reviz-cream text-reviz-ink">
      {/* --- Barre du haut */}
      <header className="sticky top-0 z-20 border-b border-[#EBDDB8] bg-reviz-cream/90 pt-safe backdrop-blur-md">
        <div className={`${CONTENU} flex h-[76px] items-center justify-between gap-4`}>
          <Link href="/" className="flex items-center gap-2.5 text-reviz-ink no-underline">
            <Image src="/landing/logo.png" alt="" width={42} height={42} className="rounded-xl" />
            <span className="font-titre text-[27px]">Reviz</span>
          </Link>
          <nav aria-label="Sections" className="hidden items-center gap-8 text-[15px] font-semibold md:flex">
            <a href="#comment" className="text-reviz-ink no-underline hover:underline">Comment ça marche</a>
            <a href="#prix" className="text-reviz-ink no-underline hover:underline">Prix</a>
            <a href="#questions" className="text-reviz-ink no-underline hover:underline">Questions</a>
          </nav>
          <a
            href={LIEN}
            className="inline-flex min-h-12 items-center gap-2 rounded-2xl bg-reviz-ink px-5 text-[15px] font-bold text-white no-underline transition-transform active:scale-[0.97] motion-reduce:transition-none"
          >
            <IconeTelecharger />
            Télécharger
          </a>
        </div>
      </header>

      <main>
        {/* --- Héros */}
        <section className={`${CONTENU} flex flex-wrap items-center gap-10 pb-16 pt-10 md:gap-16 md:pb-24 md:pt-16`}>
          <div className="flex min-w-0 flex-[1_1_460px] flex-col items-start gap-6">
            <span className={ETIQUETTE}>
              <svg width="16" height="16" viewBox="0 0 24 24" strokeWidth="2.2" {...trait} className="text-reviz-ink" aria-hidden>
                <path d="M22 10L12 5 2 10l10 5 10-5z" />
                <path d="M6 12v5c3 2 9 2 12 0v-5" />
              </svg>
              Pour les étudiants du Bénin, du Togo, de Côte d’Ivoire et du Sénégal
            </span>
            <h1 className="font-titre text-[48px] leading-[0.98] tracking-[-0.015em] sm:text-[72px] lg:text-[96px]">
              Ton cours.
              <br />
              Ton niveau.
              <br />
              <span className="mt-2 inline-block rounded-3xl bg-reviz-yellow px-4 pb-1 leading-[1.05]">Ta note.</span>
            </h1>
            <p className="max-w-[540px] text-[17px] leading-relaxed text-reviz-muted sm:text-xl">
              Reviz transforme ton propre cours en QCM, se souvient de tes erreurs et corrige tes copies d’après ce que
              ton professeur a enseigné.
            </p>
            <div className="flex w-full flex-wrap gap-3">
              <a href={LIEN} className={`${BOUTON_JAUNE} flex-[1_1_260px] sm:flex-none`}>
                <IconeTelecharger />
                Télécharger l’application
              </a>
              <a href="#comment" className={`${BOUTON_BLANC} flex-[1_1_220px] sm:flex-none`}>
                Voir comment ça marche
              </a>
            </div>
            {/* L'APK ne s'installe que sur Android : un ordinateur ou un
                iPhone ouvre la même application dans le navigateur. */}
            <a href="/web" className="text-[15px] font-semibold text-reviz-ink underline underline-offset-4">
              Sur ordinateur ou iPhone ? Ouvre Reviz dans ton navigateur
            </a>
            <ul className="flex flex-wrap gap-2">
              {['Gratuit pour commencer', 'Sans abonnement', 'Paiement Mobile Money'].map((t) => (
                <li key={t} className={PUCE}>
                  <Coche />
                  {t}
                </li>
              ))}
            </ul>
            {APK.publie && (
              <p className="text-[13px] font-medium text-reviz-muted">
                Android · version {VERSION} · {tailleLisible(APK.tailleOctets)}
              </p>
            )}
          </div>

          <div className="flex min-w-0 flex-[1_1_340px] justify-center">
            <div className="relative h-[560px] w-full max-w-[520px] sm:h-[640px]">
              <div className="absolute bottom-[6%] left-[8%] right-0 top-[4%] rounded-[48px] bg-reviz-yellow" />
              <Telephone
                src="/landing/ecran-accueil.webp"
                alt="L’accueil de Reviz : l’objectif du jour, la série et les matières"
                priorite
                className="absolute left-1/2 top-0 w-[230px] -translate-x-[38%] sm:w-[282px]"
              />
              <Panthere
                pose="salut"
                taille={540}
                alt="Le panthéreau Reviz te fait signe"
                className="absolute -left-[4%] bottom-[-2%] h-auto w-[190px] sm:w-[270px]"
              />
              {/* Deux pastilles d'exemple, données de démonstration de
                  l'application : elles disent ce qu'on y trouve. */}
              <div className="absolute right-[-2%] top-[18%] flex items-center gap-2.5 rounded-[20px] bg-reviz-card py-3 pl-3 pr-4 shadow-pastille">
                <span className="flex h-10 w-10 items-center justify-center rounded-[14px] bg-reviz-orange-soft">
                  <svg width="20" height="20" viewBox="0 0 24 24" fill="#F4793B" aria-hidden>
                    <path d="M12 2c1.2 3.4 5 5.6 5 10.2A5 5 0 0 1 7 12.2c0-2.3 1.2-3.6 2.4-4.6 0 2.2 1 3.4 2.2 3.4 0-3.3-1-5.6.4-9z" />
                  </svg>
                </span>
                <span className="flex flex-col">
                  <span className="font-titre text-lg">6 jours de flamme</span>
                  <span className="text-[13px] text-reviz-muted">Exemple</span>
                </span>
              </div>
              <div className="absolute bottom-[14%] right-[4%] flex w-[200px] flex-col gap-1.5 rounded-[20px] bg-reviz-ink px-4 py-3.5 text-white shadow-pastille">
                <span className="text-xs font-semibold text-[#D8D2C2]">Copie corrigée · exemple</span>
                <span className="font-titre text-[30px] leading-none">
                  27,5 <span className="text-[17px] text-[#D8D2C2]">/ 40</span>
                </span>
                <span className="block h-2 rounded bg-[#2E3636]">
                  <span className="block h-full w-[69%] rounded bg-reviz-yellow" />
                </span>
              </div>
            </div>
          </div>
        </section>

        {/* --- Pourquoi pas ChatGPT */}
        <section className="bg-reviz-card">
          <div className={`${CONTENU} flex flex-col gap-10 py-16 md:py-[104px]`}>
            <div className="flex flex-col items-center gap-3.5">
              <h2 className={TITRE_SECTION}>Pourquoi pas simplement ChatGPT ?</h2>
              <p className={SOUS_TITRE}>
                Un assistant généraliste répond bien. Mais il ne révise pas avec toi, et il ne sait pas ce qui tombera à
                ton examen.
              </p>
            </div>
            <div className="grid grid-cols-[repeat(auto-fit,minmax(min(300px,100%),1fr))] gap-5">
              {CONTRASTES.map((c) => (
                <article key={c.nous} className="flex flex-col gap-[18px] rounded-[28px] bg-reviz-cream p-7">
                  <div className="flex flex-col gap-1.5">
                    <p className="text-xs font-bold uppercase tracking-[0.06em] text-reviz-muted">Un assistant généraliste</p>
                    <p className="text-[15px] leading-normal text-reviz-muted">{c.eux}</p>
                  </div>
                  <div className="border-t-2 border-dashed border-reviz-border" />
                  <div className="flex flex-col gap-2">
                    <p className="flex items-center gap-2 text-xs font-bold uppercase tracking-[0.06em]">
                      <CocheJaune taille={24} />
                      Reviz
                    </p>
                    <p className="font-titre text-xl leading-snug">{c.nous}</p>
                  </div>
                </article>
              ))}
            </div>
          </div>
        </section>

        {/* --- Comment ça marche */}
        <section id="comment" className={`${CONTENU} flex scroll-mt-24 flex-col gap-10 pt-16 md:pt-[104px]`}>
          <div className="flex flex-col items-center gap-3.5">
            <h2 className={TITRE_SECTION}>Comment ça marche</h2>
            <p className={SOUS_TITRE}>Trois gestes, et ton cours devient une révision qui te ressemble.</p>
          </div>
          <ol className="grid grid-cols-[repeat(auto-fit,minmax(min(300px,100%),1fr))] gap-5">
            {ETAPES.map((e, i) => (
              <li key={e.titre} className={`${CARTE} flex flex-col gap-2.5 px-7 pb-7 pt-6`}>
                <div className="flex items-end justify-between">
                  <span className="flex h-12 w-12 items-center justify-center rounded-2xl bg-reviz-yellow font-titre text-2xl">
                    {i + 1}
                  </span>
                  <Panthere pose={e.pose} taille={128} className="-mb-1.5 -mr-3 -mt-10 h-32 w-32" />
                </div>
                <h3 className="font-titre text-2xl">{e.titre}</h3>
                <p className="text-[15px] leading-relaxed text-reviz-muted">{e.texte}</p>
              </li>
            ))}
          </ol>
          <div className="-mx-4 flex snap-x snap-mandatory gap-8 overflow-x-auto bg-reviz-surface-container px-6 py-10 sm:mx-0 sm:justify-center sm:rounded-[40px] md:gap-12 md:px-10 md:py-14">
            {ECRANS.map((e) => (
              <figure key={e.src} className="flex w-[220px] shrink-0 snap-center flex-col items-center gap-4 sm:w-[240px]">
                <Telephone src={e.src} alt={e.alt} className="w-full" />
                <figcaption className="text-center font-titre text-lg">{e.legende}</figcaption>
              </figure>
            ))}
          </div>
        </section>

        {/* --- Ce qui fait revenir */}
        <section className={`${CONTENU} flex flex-col gap-9 pt-16 md:pt-[104px]`}>
          <h2 className={TITRE_SECTION}>Réviser un peu chaque jour, pour de vrai</h2>
          <div className="grid grid-cols-[repeat(auto-fit,minmax(min(320px,100%),1fr))] gap-4">
            {RAISONS.map((r) => (
              <div key={r.titre} className="flex items-center gap-4 rounded-3xl bg-reviz-card py-3.5 pl-2.5 pr-5 shadow-card-sm">
                <Panthere pose={r.pose} taille={84} className="h-[84px] w-[84px] shrink-0" />
                <div className="flex flex-col gap-1">
                  <h3 className="font-titre text-xl">{r.titre}</h3>
                  <p className="text-[15px] leading-snug text-reviz-muted">{r.texte}</p>
                </div>
              </div>
            ))}
          </div>
        </section>

        {/* --- Pensé pour toi */}
        <section className={`${CONTENU} pt-16 md:pt-[104px]`}>
          <div className="flex flex-wrap items-center gap-10 md:gap-14">
            <div className="flex min-w-0 flex-[1_1_380px] flex-col gap-[18px]">
              <h2 className="text-balance font-titre text-[32px] leading-[1.05] sm:text-[40px] lg:text-[48px]">
                Pensé pour l’amphi, pas pour la Silicon Valley
              </h2>
              <p className="text-[17px] leading-relaxed text-reviz-muted sm:text-lg">
                Tout est en français, tous les prix sont en F CFA, et l’application tient sur un Android milieu de gamme,
                même la veille d’un contrôle avec une connexion qui coupe.
              </p>
              <ul className="flex flex-col gap-2.5 text-base font-medium">
                {ENGAGEMENTS.map((t) => (
                  <li key={t} className="flex items-center gap-2.5">
                    <CocheJaune />
                    {t}
                  </li>
                ))}
              </ul>
            </div>
            <div className="relative h-[360px] min-w-0 flex-[1_1_440px] sm:h-[440px]">
              <Image
                src="/landing/photo-classe.webp"
                alt="Une étudiante révise sur son téléphone, en amphi"
                width={1100}
                height={614}
                sizes="(max-width: 640px) 70vw, 400px"
                className="absolute left-0 top-0 h-[64%] w-[72%] rounded-[32px] object-cover shadow-telephone"
              />
              <Image
                src="/landing/photo-fete.webp"
                alt="Des étudiants fêtent leur réussite"
                width={1100}
                height={614}
                sizes="(max-width: 640px) 60vw, 340px"
                className="absolute bottom-0 right-0 h-[54%] w-[62%] rounded-[32px] border-[6px] border-reviz-cream object-cover shadow-telephone"
              />
              <Panthere pose="bravo" taille={200} className="absolute -bottom-[6%] left-[4%] h-auto w-[34%]" />
            </div>
          </div>
        </section>

        {/* --- Prix */}
        <section id="prix" className={`${CONTENU} flex scroll-mt-24 flex-col gap-8 pt-[72px] md:pt-[120px]`}>
          <div className="flex flex-col items-center gap-3.5 text-center">
            <span className={ETIQUETTE}>
              <svg width="16" height="16" viewBox="0 0 24 24" strokeWidth="2.2" {...trait} className="text-reviz-ink" aria-hidden>
                <rect x="6" y="2.5" width="12" height="19" rx="3" />
                <path d="M11 18h2" />
              </svg>
              Paiement unique en Mobile Money
            </span>
            <h2 className="text-balance font-titre text-[38px] leading-[1.02] sm:text-[56px] lg:text-[68px]">
              Des packs, pas d’abonnement.
            </h2>
            <p className={SOUS_TITRE}>
              Tu paies une fois, pour une durée précise. À la fin, rien n’est prélevé : l’accès s’arrête, et tes cours
              restent à toi pour réviser gratuitement.
            </p>
          </div>

          <SelecteurPacks
            packs={payants}
            conseille={PACK_CONSEILLE}
            meilleurParJour={meilleurPrixParJour(packs)}
            lien={LIEN}
          />

          {decouverte && (
            <div className="flex flex-wrap items-center gap-5 rounded-[28px] border-2 border-dashed border-reviz-border bg-reviz-surface-low py-[18px] pl-3 pr-6">
              <Panthere pose="cadeau" taille={104} alt="Le panthéreau te tend un cadeau" className="h-[104px] w-[104px] shrink-0" />
              <div className="flex flex-[1_1_280px] flex-col gap-1">
                <p className="font-titre text-2xl">Pas encore sûr ? Essaie gratuitement.</p>
                <p className="text-[15px] leading-normal text-reviz-muted">
                  Pack {decouverte.label} : {decouverte.jours} jours, {matieresLisibles(decouverte.matieres).toLowerCase()},{' '}
                  {correctionsLisibles(decouverte.corrections)}. Il s’active en un appui, sans rien payer.
                </p>
              </div>
              <a href={LIEN} className={`${BOUTON_BLANC} min-h-[54px] text-base`}>
                Commencer l’essai gratuit
              </a>
            </div>
          )}
        </section>

        {/* --- Mobile Money */}
        <section className={`${CONTENU} flex flex-col gap-8 pt-16 md:pt-[104px]`}>
          <div className="flex flex-col items-center gap-2.5 text-center">
            <h2 className="font-titre text-[30px] leading-[1.05] sm:text-[44px]">Paie avec ton Mobile Money</h2>
            <p className="text-[17px] text-reviz-muted">Dans l’application, sans la quitter : la demande arrive sur ton téléphone.</p>
          </div>
          <div className="grid grid-cols-[repeat(auto-fit,minmax(min(240px,100%),1fr))] gap-4">
            {PAYS.map((p) => (
              <div key={p.code} className="flex flex-col gap-4 rounded-3xl bg-reviz-card p-[22px] shadow-card-sm">
                <div className="flex items-center gap-3">
                  <span className="flex h-[42px] w-[42px] items-center justify-center rounded-[14px] bg-reviz-ink text-[13px] font-bold tracking-[0.04em] text-white">
                    {p.code}
                  </span>
                  <span className="font-titre text-[21px]">{p.nom}</span>
                </div>
                <div className="flex flex-wrap gap-2">
                  {operateursDuPays(p.code).map((o) => (
                    <span key={o} className={PUCE}>
                      {NOMS_OPERATEURS[o] ?? o}
                    </span>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </section>

        {/* --- Parrainage */}
        <section className={`${CONTENU} pt-16 md:pt-[104px]`}>
          <div className="flex flex-wrap items-center gap-6 rounded-[40px] bg-reviz-yellow p-7 shadow-lueur-large md:gap-10 md:p-[52px]">
            <div className="flex shrink-0">
              <Panthere pose="amis" taille={170} className="h-auto w-[130px] md:w-[170px]" />
              <Panthere pose="pieces" taille={170} className="-ml-7 h-auto w-[130px] md:w-[170px]" />
            </div>
            <div className="flex flex-[1_1_360px] flex-col gap-3">
              <h2 className="font-titre text-[32px] leading-[1.05] sm:text-[48px]">Atteins 3 000 XP, invite ta promo</h2>
              <p className="text-[17px] leading-relaxed text-[#3B3424] sm:text-lg">
                Révise jusqu’à 3 000 XP : ton parrainage s’ouvre. Ensuite, chaque fois qu’un camarade que tu as invité
                paie un pack, 25 % du montant arrivent dans ton portefeuille, pendant douze mois. Tu retires en Mobile
                Money dès 3 000 F.
              </p>
            </div>
          </div>
        </section>

        {/* --- Questions : `<details>` natifs, la première ouverte. Rien à
            charger côté client pour les ouvrir. */}
        <section id="questions" className="mx-auto flex max-w-[880px] scroll-mt-24 flex-col gap-7 px-4 pt-16 sm:px-8 md:pt-[104px]">
          <h2 className={TITRE_SECTION}>Tes questions</h2>
          <div className="flex flex-col gap-3">
            {FAQ.map((q, i) => (
              <details
                key={q.question}
                open={i === 0}
                className="group rounded-3xl bg-reviz-card shadow-card-sm [&_summary::-webkit-details-marker]:hidden"
              >
                <summary className="flex min-h-16 cursor-pointer list-none items-center justify-between gap-4 px-[22px] py-[18px]">
                  <span className="font-titre text-[19px] leading-snug">{q.question}</span>
                  <span className="flex h-[34px] w-[34px] shrink-0 items-center justify-center rounded-xl bg-reviz-cream transition-colors group-open:bg-reviz-yellow">
                    <svg width="16" height="16" viewBox="0 0 24 24" strokeWidth="3" {...trait} aria-hidden>
                      <path d="M5 12h14" />
                      <path d="M12 5v14" className="group-open:hidden" />
                    </svg>
                  </span>
                </summary>
                <p className="px-[22px] pb-[22px] text-base leading-relaxed text-reviz-muted">{q.reponse}</p>
              </details>
            ))}
          </div>
        </section>

        {/* --- Dernier appel */}
        <section className={`${CONTENU} pb-16 pt-16 md:pb-20 md:pt-[104px]`}>
          <div className="flex flex-wrap items-center justify-between gap-7 rounded-[40px] bg-reviz-ink p-7 text-white md:p-14">
            <div className="flex flex-[1_1_440px] items-center gap-5">
              <Panthere pose="cadeau" taille={136} className="h-auto w-24 shrink-0 md:w-[136px]" />
              <div className="flex flex-col gap-2">
                <p className="font-titre text-[28px] leading-[1.05] sm:text-[44px]">Ton premier pack est offert.</p>
                <p className="text-[17px] leading-relaxed text-[#D8D2C2]">
                  Installe Reviz, dépose un cours, et révise ce soir. Trois jours pour essayer, sans payer.
                </p>
              </div>
            </div>
            <div className="flex flex-col items-start gap-3">
              <a
                href={LIEN}
                className="inline-flex min-h-[60px] items-center gap-2.5 rounded-[20px] bg-reviz-yellow px-7 text-lg font-bold text-reviz-ink no-underline transition-transform active:scale-[0.97] motion-reduce:transition-none"
              >
                Télécharger l’application
                <svg width="20" height="20" viewBox="0 0 24 24" strokeWidth="2.6" {...trait} aria-hidden>
                  <path d="M5 12h14" />
                  <path d="M13 6l6 6-6 6" />
                </svg>
              </a>
              <Link href="/app" className="text-sm font-semibold text-[#D8D2C2] underline underline-offset-4">
                Comment installer l’application
              </Link>
              <a href="/web" className="text-sm font-semibold text-[#D8D2C2] underline underline-offset-4">
                Ou l’ouvrir dans le navigateur
              </a>
            </div>
          </div>
        </section>
      </main>

      <footer className="border-t border-[#EBDDB8]">
        <div className={`${CONTENU} flex flex-wrap items-center justify-between gap-4 pb-safe pt-6 text-sm font-medium text-reviz-muted`}>
          <p className="flex items-center gap-2.5 pb-8">
            <Image src="/landing/logo.png" alt="" width={28} height={28} className="rounded-lg" />© 2026 Reviz · Fait
            pour les étudiants d’Afrique francophone
          </p>
          <p className="flex flex-wrap gap-[18px] pb-8">
            <Link href="/app" className="text-reviz-muted underline underline-offset-4">Installer</Link>
            <a href="#prix" className="text-reviz-muted underline underline-offset-4">Prix</a>
            <a href="#questions" className="text-reviz-muted underline underline-offset-4">Questions</a>
            <Link href="/confidentialite" className="text-reviz-muted underline underline-offset-4">Confidentialité</Link>
          </p>
        </div>
      </footer>
    </div>
  )
}
