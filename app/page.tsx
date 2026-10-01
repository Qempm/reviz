import { Nunito } from 'next/font/google'
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
 * **Habit du 1er octobre 2026**, repris de la maquette « Page Tarifs » :
 * papier crème, encre, jaune, Nunito très gras, bordures de 2 px et ombres
 * franches sous les cartes et les boutons. Il ne vaut que pour cette page —
 * l'application garde ses neutres (`docs/DESIGN.md` § 11 bis) — et ses
 * couleurs sont les jetons `papier.*` de `tailwind.config.ts`.
 *
 * Mobile d'abord — le lien arrive par WhatsApp sur un Android milieu de
 * gamme —, légère (captures en WebP de 35 à 50 ko, rendues à ×2 par
 * `test_apercus/studio_test.dart`), et sans un mot
 * technique. Les captures sont de vrais écrans de l'application, le
 * panthéreau est celui de l'application.
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

const nunito = Nunito({
  subsets: ['latin'],
  weight: ['600', '700', '800', '900'],
  display: 'swap',
})

const LIEN = APK.publie ? APK.url : '/app'

// Les classes qui reviennent : une carte calme, une carte appuyée, un
// bouton. L'appui enfonce le bouton de la hauteur de son ombre.
const CARTE = 'rounded-3xl border-2 border-papier-bord bg-white shadow-[0_4px_0_#E9DDBE]'
const BOUTON =
  'inline-flex min-h-[58px] items-center justify-center gap-2.5 rounded-2xl border-2 border-papier-encre px-6 text-[17px] font-black text-papier-encre no-underline shadow-[0_5px_0_#1C1A14] transition-transform active:translate-y-[3px] active:shadow-[0_2px_0_#1C1A14] motion-reduce:transition-none'
const TITRE = 'text-center text-[30px] font-black leading-[1.05] tracking-[-0.03em] sm:text-[40px] lg:text-[46px]'
const PUCE =
  'inline-flex items-center gap-1.5 rounded-[10px] border-2 border-papier-puce-bord bg-papier-puce px-3 py-[7px] text-sm font-extrabold'

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

function Telephone({
  src,
  alt,
  priorite = false,
  ombre = 'shadow-[0_8px_0_#E2D2A6]',
  className = '',
}: {
  src: string
  alt: string
  priorite?: boolean
  ombre?: string
  className?: string
}) {
  return (
    <div className={`rounded-[40px] border-2 border-papier-encre bg-papier-encre p-2 ${ombre} ${className}`}>
      <Image
        src={src}
        alt={alt}
        width={390}
        height={844}
        priority={priorite}
        sizes="290px"
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
  { pose: 'reveil', titre: 'Des rappels', texte: 'Ta série le soir, ton examen à J-3 et à J-1.' },
  { pose: 'reflexion', titre: 'Même sans réseau', texte: 'Tes séries sont gardées et partent au retour de la connexion.' },
  { pose: 'telephone', titre: 'Léger', texte: 'Une application de 60 Mo, pensée pour un forfait data limité.' },
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
    <div
      id="haut"
      className={`${nunito.className} min-h-screen overflow-x-hidden bg-papier-creme text-papier-encre tabular-nums`}
    >
      {/* --- Barre du haut */}
      <header className="sticky top-0 z-20 border-b-2 border-papier-bord bg-papier-creme/90 pt-safe backdrop-blur-md">
        <div className="mx-auto flex h-[76px] max-w-[1180px] items-center justify-between gap-4 px-5">
          <Link href="/" className="flex items-center gap-2.5 text-papier-encre no-underline">
            <span className="flex h-11 w-11 items-center justify-center rounded-[13px] border-2 border-papier-encre bg-papier-jaune shadow-[0_3px_0_#1C1A14]">
              <Image src="/landing/logo.png" alt="" width={30} height={30} />
            </span>
            <span className="text-[25px] font-black tracking-[-0.02em]">Reviz</span>
          </Link>
          <nav aria-label="Sections" className="hidden items-center gap-7 text-[15px] font-extrabold md:flex">
            <a href="#comment" className="text-papier-encre no-underline hover:underline">Comment ça marche</a>
            <a href="#prix" className="text-papier-encre no-underline hover:underline">Prix</a>
            <a href="#questions" className="text-papier-encre no-underline hover:underline">Questions</a>
          </nav>
          <a
            href={LIEN}
            className="inline-flex min-h-12 items-center rounded-[14px] border-2 border-papier-encre bg-white px-[18px] text-[15px] font-black text-papier-encre no-underline shadow-[0_3px_0_#1C1A14] active:translate-y-[2px] active:shadow-[0_1px_0_#1C1A14]"
          >
            Télécharger
          </a>
        </div>
      </header>

      <main>
        {/* --- Héros */}
        <section className="mx-auto flex max-w-[1180px] flex-wrap items-center gap-14 px-5 pb-20 pt-12 md:pt-16">
          <div className="flex flex-[1_1_460px] flex-col items-start gap-[22px]">
            <span className="inline-flex items-center gap-2 rounded-full border-2 border-papier-bord bg-white px-3.5 py-2 text-sm font-extrabold text-papier-sourdine">
              <svg width="16" height="16" viewBox="0 0 24 24" strokeWidth="2.4" {...trait} aria-hidden>
                <path d="M22 10L12 5 2 10l10 5 10-5z" />
                <path d="M6 12v5c3 2 9 2 12 0v-5" />
              </svg>
              Pour les étudiants du Bénin, du Togo, de Côte d’Ivoire et du Sénégal
            </span>
            <h1 className="text-[46px] font-black leading-[0.98] tracking-[-0.04em] sm:text-[64px] lg:text-[84px]">
              Ton cours.
              <br />
              Ton niveau.
              <br />
              <span className="mt-1.5 inline-block rounded-[14px] bg-papier-jaune px-2.5 pb-1 leading-[1.05]">Ta note.</span>
            </h1>
            <p className="max-w-[520px] text-[17px] font-semibold leading-relaxed text-papier-sourdine sm:text-xl">
              Reviz transforme ton propre cours en QCM, se souvient de tes erreurs et corrige tes copies d’après ce
              que ton professeur a enseigné.
            </p>
            <div className="flex w-full flex-wrap gap-3.5">
              <a href={LIEN} className={`${BOUTON} flex-[1_1_260px] bg-papier-jaune text-lg sm:max-w-[340px]`}>
                <svg width="20" height="20" viewBox="0 0 24 24" strokeWidth="2.6" {...trait} aria-hidden>
                  <path d="M12 4v11" />
                  <path d="M7 10l5 5 5-5" />
                  <path d="M5 20h14" />
                </svg>
                Télécharger l’application
              </a>
              <a href="#comment" className={`${BOUTON} bg-white`}>
                Voir comment ça marche
              </a>
            </div>
            <ul className="flex flex-wrap gap-2.5">
              {['Gratuit pour commencer', 'Sans abonnement', 'Paiement Mobile Money'].map((t) => (
                <li key={t} className={PUCE}>
                  <Coche />
                  {t}
                </li>
              ))}
            </ul>
            {APK.publie && (
              <p className="text-sm font-bold text-papier-pale">
                Android · version {VERSION} · {tailleLisible(APK.tailleOctets)}
              </p>
            )}
          </div>
          <div className="flex flex-[1_1_320px] justify-center">
            <div className="relative w-[290px] max-w-[80%]">
              <Telephone
                src="/landing/ecran-chemin.webp"
                alt="Le chemin des chapitres d’un cours, avec ses couronnes"
                priorite
                ombre="shadow-[14px_16px_0_#FFC83D]"
              />
              <Panthere
                pose="salut"
                taille={140}
                alt="Le panthéreau Reviz te fait signe"
                className="absolute -bottom-7 -left-12 h-28 w-28 sm:-left-16 sm:h-[138px] sm:w-[138px]"
              />
            </div>
          </div>
        </section>

        {/* --- Pourquoi pas ChatGPT */}
        <section className="border-y-2 border-papier-encre bg-white">
          <div className="mx-auto flex max-w-[1180px] flex-col gap-8 px-5 py-20 md:py-[88px]">
            <div className="flex flex-col items-center gap-3 text-center">
              <h2 className={TITRE}>Pourquoi pas simplement ChatGPT ?</h2>
              <p className="max-w-[620px] text-[17px] font-semibold leading-relaxed text-papier-sourdine">
                Un assistant généraliste répond bien. Mais il ne révise pas avec toi, et il ne sait pas ce qui
                tombera à ton examen.
              </p>
            </div>
            <div className="grid grid-cols-[repeat(auto-fit,minmax(280px,1fr))] gap-5">
              {CONTRASTES.map((c) => (
                <article
                  key={c.nous}
                  className="flex flex-col gap-4 rounded-[26px] border-2 border-papier-encre bg-papier-creme p-[26px] shadow-[0_6px_0_#1C1A14]"
                >
                  <div className="flex flex-col gap-1.5">
                    <p className="text-[13px] font-black uppercase tracking-[0.06em] text-papier-pale">
                      Un assistant généraliste
                    </p>
                    <p className="text-[15px] font-semibold leading-normal text-papier-sourdine">{c.eux}</p>
                  </div>
                  <div className="flex flex-col gap-1.5 border-t-2 border-dashed border-papier-pointille pt-4">
                    <p className="flex items-center gap-2 text-[13px] font-black uppercase tracking-[0.06em]">
                      <span className="inline-flex h-[22px] w-[22px] items-center justify-center rounded-full border-2 border-papier-encre bg-papier-jaune">
                        <Coche taille={12} epaisseur={4} />
                      </span>
                      Reviz
                    </p>
                    <p className="text-lg font-extrabold leading-snug">{c.nous}</p>
                  </div>
                </article>
              ))}
            </div>
          </div>
        </section>

        {/* --- Comment ça marche */}
        <section id="comment" className="mx-auto flex max-w-[1180px] scroll-mt-24 flex-col gap-8 px-5 pt-24">
          <h2 className={TITRE}>Comment ça marche</h2>
          <ol className="grid grid-cols-[repeat(auto-fit,minmax(260px,1fr))] gap-5">
            {ETAPES.map((e, i) => (
              <li key={e.titre} className={`${CARTE} flex flex-col gap-3 p-[26px]`}>
                <div className="flex items-center justify-between">
                  <span className="flex h-[46px] w-[46px] items-center justify-center rounded-full border-2 border-papier-encre bg-papier-jaune text-[21px] font-black">
                    {i + 1}
                  </span>
                  <Panthere pose={e.pose} taille={76} className="h-[76px] w-[76px]" />
                </div>
                <h3 className="text-xl font-black">{e.titre}</h3>
                <p className="text-[15px] font-semibold leading-normal text-papier-sourdine">{e.texte}</p>
              </li>
            ))}
          </ol>
          <div className="-mx-5 flex snap-x snap-mandatory gap-9 overflow-x-auto px-5 pb-4 pt-6 md:mx-0 md:justify-center md:overflow-visible md:px-0">
            {ECRANS.map((e) => (
              <figure key={e.src} className="flex w-[230px] shrink-0 snap-center flex-col items-center gap-4">
                <Telephone src={e.src} alt={e.alt} />
                <figcaption className="text-center text-[15px] font-extrabold">{e.legende}</figcaption>
              </figure>
            ))}
          </div>
        </section>

        {/* --- Ce qui fait revenir */}
        <section className="mx-auto flex max-w-[1180px] flex-col gap-8 px-5 pt-24">
          <h2 className={TITRE}>Réviser un peu chaque jour, pour de vrai</h2>
          <div className="grid grid-cols-[repeat(auto-fit,minmax(min(300px,100%),1fr))] gap-4">
            {RAISONS.map((r) => (
              <div key={r.titre} className="flex items-center gap-4 rounded-[22px] border-2 border-papier-bord bg-white p-[18px]">
                <Panthere pose={r.pose} taille={68} className="h-[68px] w-[68px] shrink-0" />
                <div className="flex flex-col gap-1">
                  <h3 className="text-lg font-black">{r.titre}</h3>
                  <p className="text-[15px] font-semibold leading-snug text-papier-sourdine">{r.texte}</p>
                </div>
              </div>
            ))}
          </div>
        </section>

        {/* --- Prix */}
        <section id="prix" className="mx-auto flex max-w-[1180px] scroll-mt-24 flex-col gap-7 px-5 pt-[104px]">
          <div className="flex flex-col items-center gap-3.5 text-center">
            <span className="inline-flex items-center gap-2 rounded-full border-2 border-papier-bord bg-white px-3.5 py-2 text-sm font-extrabold text-papier-sourdine">
              <svg width="16" height="16" viewBox="0 0 24 24" strokeWidth="2.4" {...trait} aria-hidden>
                <rect x="6" y="2.5" width="12" height="19" rx="3" />
                <path d="M11 18h2" />
              </svg>
              Paiement unique en Mobile Money
            </span>
            <h2 className="text-[36px] font-black leading-[1.02] tracking-[-0.035em] sm:text-[52px] lg:text-[64px]">
              Des packs, pas d’abonnement.
            </h2>
            <p className="max-w-[640px] text-base font-semibold leading-relaxed text-papier-sourdine sm:text-[19px]">
              Tu paies une fois, pour une durée précise. À la fin, rien n’est prélevé : l’accès s’arrête, et tes
              cours restent à toi pour réviser gratuitement.
            </p>
          </div>

          <SelecteurPacks
            packs={payants}
            conseille={PACK_CONSEILLE}
            meilleurParJour={meilleurPrixParJour(packs)}
            lien={LIEN}
          />

          {decouverte && (
            <div className="flex flex-wrap items-center gap-5 rounded-3xl border-2 border-dashed border-papier-pointille bg-white px-6 py-[22px]">
              <Panthere pose="cadeau" taille={84} alt="Le panthéreau te tend un cadeau" className="h-[84px] w-[84px] shrink-0" />
              <div className="flex flex-[1_1_280px] flex-col gap-1">
                <p className="text-xl font-black">Pas encore sûr ? Essaie gratuitement.</p>
                <p className="text-[15px] font-semibold text-papier-sourdine">
                  Pack {decouverte.label} : {decouverte.jours} jours,{' '}
                  {matieresLisibles(decouverte.matieres).toLowerCase()},{' '}
                  {correctionsLisibles(decouverte.corrections)}. Il s’active en un appui, sans rien payer.
                </p>
              </div>
              <a href={LIEN} className={`${BOUTON} min-h-[52px] bg-white text-base`}>
                Commencer l’essai gratuit
              </a>
            </div>
          )}
        </section>

        {/* --- Mobile Money */}
        <section className="mx-auto flex max-w-[1180px] flex-col gap-7 px-5 pt-24">
          <div className="flex flex-col items-center gap-2.5 text-center">
            <h2 className="text-[28px] font-black tracking-[-0.025em] sm:text-[40px]">Paie avec ton Mobile Money</h2>
            <p className="text-base font-semibold text-papier-sourdine">
              Dans l’application, sans la quitter : la demande arrive sur ton téléphone.
            </p>
          </div>
          <div className="grid grid-cols-[repeat(auto-fit,minmax(220px,1fr))] gap-4">
            {PAYS.map((p) => (
              <div key={p.code} className="flex flex-col gap-3.5 rounded-[22px] border-2 border-papier-bord bg-white p-[22px]">
                <div className="flex items-center gap-3">
                  <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-papier-encre text-sm font-black tracking-[0.04em] text-white">
                    {p.code}
                  </span>
                  <span className="text-lg font-black">{p.nom}</span>
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
        <section className="mx-auto max-w-[1180px] px-5 pt-24">
          <div className="flex flex-wrap items-center gap-7 rounded-[32px] border-2 border-papier-encre bg-papier-jaune p-7 shadow-[0_8px_0_#1C1A14] md:p-12">
            <div className="flex shrink-0">
              <Panthere pose="amis" taille={120} className="h-[120px] w-[120px]" />
              <Panthere pose="pieces" taille={120} className="-ml-7 h-[120px] w-[120px]" />
            </div>
            <div className="flex flex-[1_1_360px] flex-col gap-2.5">
              <h2 className="text-[28px] font-black leading-[1.05] tracking-[-0.03em] sm:text-[42px]">
                Invite ta promo, gagne 25 %
              </h2>
              <p className="text-[17px] font-bold leading-normal text-papier-brun">
                Chaque fois qu’un camarade que tu as invité paie un pack, 25 % du montant arrivent dans ton
                portefeuille, pendant douze mois. Tu retires en Mobile Money dès 3 000 F.
              </p>
            </div>
          </div>
        </section>

        {/* --- FAQ */}
        <section id="questions" className="mx-auto flex max-w-[1180px] scroll-mt-24 flex-col gap-7 px-5 pt-24">
          <h2 className="text-center text-[28px] font-black tracking-[-0.025em] sm:text-[40px]">Tes questions</h2>
          {/* En colonnes qui s'écoulent, et non en grille : sept questions
              laisseraient la dernière seule sur sa rangée. */}
          <div className="gap-4 md:columns-2 lg:columns-3">
            {FAQ.map((q) => (
              <div
                key={q.question}
                className="mb-4 flex break-inside-avoid flex-col gap-2 rounded-[22px] border-2 border-papier-bord bg-white p-6"
              >
                <h3 className="text-[17px] font-black">{q.question}</h3>
                <p className="text-[15px] font-semibold leading-relaxed text-papier-sourdine">{q.reponse}</p>
              </div>
            ))}
          </div>
        </section>

        {/* --- Dernier appel */}
        <section className="mx-auto max-w-[1180px] px-5 pb-20 pt-24">
          <div className="flex flex-wrap items-center justify-between gap-7 rounded-[32px] bg-papier-encre p-7 text-white md:p-[52px]">
            <div className="flex flex-[1_1_440px] items-center gap-5">
              <Panthere pose="cadeau" taille={104} className="h-20 w-20 shrink-0 sm:h-[104px] sm:w-[104px]" />
              <div className="flex flex-col gap-2">
                <p className="text-[26px] font-black leading-tight tracking-[-0.025em] sm:text-[40px]">
                  Ton premier pack est offert.
                </p>
                <p className="text-base font-semibold leading-normal text-papier-sable">
                  Installe Reviz, dépose un cours, et révise ce soir. Trois jours pour essayer, sans payer.
                </p>
              </div>
            </div>
            <div className="flex flex-col items-start gap-3">
              <a
                href={LIEN}
                className="inline-flex min-h-[58px] items-center gap-2.5 rounded-2xl border-2 border-papier-jaune bg-papier-jaune px-[26px] text-lg font-black text-papier-encre no-underline shadow-[0_5px_0_#8A6A00] active:translate-y-[3px] active:shadow-[0_2px_0_#8A6A00]"
              >
                Télécharger l’application
                <svg width="20" height="20" viewBox="0 0 24 24" strokeWidth="2.6" {...trait} aria-hidden>
                  <path d="M5 12h14" />
                  <path d="M13 6l6 6-6 6" />
                </svg>
              </a>
              <Link href="/app" className="text-sm font-bold text-papier-sable underline underline-offset-4">
                Comment installer l’application
              </Link>
            </div>
          </div>
        </section>
      </main>

      <footer className="border-t-2 border-papier-bord">
        <div className="mx-auto flex max-w-[1180px] flex-wrap justify-between gap-3 px-5 pb-safe pt-6 text-sm font-bold text-papier-pale">
          <p className="pb-8">© 2026 Reviz · Fait pour les étudiants d’Afrique francophone</p>
          <p className="flex flex-wrap gap-4 pb-8">
            <Link href="/app" className="text-papier-pale underline underline-offset-4">Installer</Link>
            <a href="#prix" className="text-papier-pale underline underline-offset-4">Prix</a>
            <a href="#questions" className="text-papier-pale underline underline-offset-4">Questions</a>
            <Link href="/confidentialite" className="text-papier-pale underline underline-offset-4">Confidentialité</Link>
          </p>
        </div>
      </footer>
    </div>
  )
}
