'use client'

import { useState } from 'react'
import {
  correctionsLisibles,
  dureeLisible,
  matieresLisibles,
  nombreLisible,
  objectifDe,
  type PackPublic,
  phraseConseil,
  prixParJour,
} from '@/lib/metier/offre'

/**
 * « Tu prépares quoi en ce moment ? » : l'étudiant dit ce qui l'attend, la
 * grille met en avant le pack qui y répond.
 *
 * Le seul morceau interactif de la page d'accueil, donc le seul composant
 * client : tout le reste est rendu sur le serveur. Les packs arrivent déjà
 * lus en base (`chargerPacks`). Le bouton du pack choisi mène au
 * téléchargement et non à un paiement : on n'achète que dans l'application.
 */
export function SelecteurPacks({
  packs,
  conseille,
  meilleurParJour,
  lien,
}: {
  /** Les packs payants, du moins cher au plus cher. */
  packs: PackPublic[]
  conseille: string
  meilleurParJour: string | null
  lien: string
}) {
  const [choix, setChoix] = useState(
    packs.some((p) => p.code === conseille) ? conseille : packs[0]?.code,
  )
  const actif = packs.find((p) => p.code === choix) ?? packs[0]
  if (!actif) return null

  return (
    <>
      <div className="flex flex-col items-center gap-3.5">
        <p className="text-lg font-black">Tu prépares quoi en ce moment ?</p>
        <div className="flex flex-wrap justify-center gap-2.5">
          {packs.map((p) => {
            const on = p.code === actif.code
            return (
              <button
                key={p.code}
                type="button"
                aria-pressed={on}
                onClick={() => setChoix(p.code)}
                className={`min-h-12 rounded-full border-2 px-5 text-[15px] font-extrabold text-papier-encre transition-colors ${
                  on
                    ? 'border-papier-encre bg-papier-jaune shadow-[0_3px_0_#1C1A14]'
                    : 'border-papier-bord-doux bg-white shadow-[0_3px_0_#E2D5B2]'
                }`}
              >
                {objectifDe(p).bouton}
              </button>
            )
          })}
        </div>
        <p aria-live="polite" className="text-center text-[15px] font-bold text-papier-sourdine">
          {phraseConseil(actif)}
        </p>
      </div>

      <div className="grid grid-cols-[repeat(auto-fit,minmax(250px,1fr))] items-stretch gap-5 pt-3">
        {packs.map((p) => {
          const on = p.code === actif.code
          return (
            <article
              key={p.code}
              className={`flex flex-col gap-[18px] rounded-[26px] border-2 p-[26px] transition-transform duration-150 motion-reduce:transition-none ${
                on
                  ? '-translate-y-2 border-papier-encre bg-papier-jaune shadow-[0_8px_0_#1C1A14]'
                  : 'border-papier-bord bg-white shadow-[0_4px_0_#E9DDBE]'
              }`}
            >
              <div className="flex min-h-[30px] items-center justify-between gap-2">
                <h3 className="text-[22px] font-black tracking-[-0.01em]">{p.label}</h3>
                {/* « Conseillé » suit le choix : c'est le conseil pour ce
                    que l'étudiant vient de dire qu'il prépare. */}
                {on && (
                  <span className="whitespace-nowrap rounded-full bg-papier-encre px-[11px] py-[5px] text-xs font-extrabold text-white">
                    Conseillé
                  </span>
                )}
                {!on && p.code === meilleurParJour && (
                  <span className="whitespace-nowrap rounded-full border-2 border-papier-encre px-2.5 py-1 text-xs font-extrabold">
                    Meilleur prix / jour
                  </span>
                )}
              </div>
              <div className="flex flex-col gap-2">
                <p className="flex items-baseline gap-1.5">
                  <span className="text-[50px] font-black leading-none tracking-[-0.03em]">
                    {nombreLisible(p.prixFcfa)}
                  </span>
                  <span className="text-base font-extrabold">F CFA</span>
                </p>
                <span
                  className={`self-start rounded-[10px] px-2.5 py-[5px] text-[13px] font-extrabold ${
                    on ? 'bg-papier-encre/10 text-papier-brun' : 'bg-papier-puce text-papier-pale'
                  }`}
                >
                  {prixParJour(p.prixFcfa, p.jours)}
                </span>
              </div>
              <ul
                className={`flex flex-col gap-3 border-t-2 border-dashed pt-4 text-base font-bold ${
                  on ? 'border-papier-encre/35' : 'border-papier-bord'
                }`}
              >
                <li className="flex items-center gap-2.5">
                  <IconeHorloge />
                  {dureeLisible(p.jours)}
                </li>
                <li className="flex items-center gap-2.5">
                  <IconeLivre />
                  {matieresLisibles(p.matieres)}
                </li>
                <li className="flex items-center gap-2.5">
                  <IconeCoche />
                  {correctionsLisibles(p.corrections)}
                </li>
              </ul>
              <p
                className={`flex-grow text-[15px] font-semibold leading-normal ${
                  on ? 'text-papier-brun' : 'text-papier-pale'
                }`}
              >
                {p.description}
              </p>
              {on ? (
                <a
                  href={lien}
                  className="flex min-h-[52px] items-center justify-center rounded-2xl border-2 border-papier-encre bg-papier-encre text-base font-black text-white no-underline shadow-[0_4px_0_#1C1A14] active:translate-y-[2px] active:shadow-[0_2px_0_#1C1A14]"
                >
                  Commencer avec {p.label}
                </a>
              ) : (
                <button
                  type="button"
                  onClick={() => setChoix(p.code)}
                  className="min-h-[52px] rounded-2xl border-2 border-papier-encre bg-white text-base font-black text-papier-encre shadow-[0_4px_0_#1C1A14] active:translate-y-[2px] active:shadow-[0_2px_0_#1C1A14]"
                >
                  Choisir {p.label}
                </button>
              )}
            </article>
          )
        })}
      </div>
    </>
  )
}

const trait = {
  fill: 'none',
  stroke: 'currentColor',
  strokeLinecap: 'round' as const,
  strokeLinejoin: 'round' as const,
}

function IconeHorloge() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" strokeWidth="2.2" {...trait} aria-hidden>
      <circle cx="12" cy="12" r="9" />
      <path d="M12 7v5l3 2" />
    </svg>
  )
}

function IconeLivre() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" strokeWidth="2.2" {...trait} aria-hidden>
      <path d="M5 4h11a3 3 0 0 1 3 3v13H8a3 3 0 0 1-3-3z" />
      <path d="M5 17a3 3 0 0 1 3-3h11" />
    </svg>
  )
}

function IconeCoche() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" strokeWidth="2.4" {...trait} aria-hidden>
      <rect x="3" y="3" width="18" height="18" rx="5" />
      <path d="M8 12.5l2.8 2.8L16.5 9" />
    </svg>
  )
}
