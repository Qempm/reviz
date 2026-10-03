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
 * grille met en avant le pack qui y répond — en jaune, la couleur de l'action.
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
        <p className="font-titre text-[22px]">Tu prépares quoi en ce moment ?</p>
        <div className="flex flex-wrap justify-center gap-2">
          {packs.map((p) => {
            const on = p.code === actif.code
            return (
              <button
                key={p.code}
                type="button"
                aria-pressed={on}
                onClick={() => setChoix(p.code)}
                className={`min-h-12 rounded-full px-5 text-[15px] transition-colors ${
                  on
                    ? 'bg-reviz-ink font-bold text-white'
                    : 'bg-reviz-card font-semibold text-reviz-ink shadow-card-sm'
                }`}
              >
                {objectifDe(p).bouton}
              </button>
            )
          })}
        </div>
        <p aria-live="polite" className="max-w-[640px] text-center text-[15px] font-medium text-reviz-muted">
          {phraseConseil(actif)}
        </p>
      </div>

      <div className="grid grid-cols-[repeat(auto-fit,minmax(min(250px,100%),1fr))] items-stretch gap-[18px] pt-2">
        {packs.map((p) => {
          const on = p.code === actif.code
          return (
            <article
              key={p.code}
              className={`flex flex-col gap-[18px] rounded-[28px] p-[26px] transition-transform duration-150 motion-reduce:transition-none ${
                on ? '-translate-y-2 bg-reviz-yellow shadow-lueur-large' : 'bg-reviz-card shadow-card'
              }`}
            >
              <div className="flex min-h-[30px] items-center justify-between gap-2">
                <h3 className="font-titre text-[26px]">{p.label}</h3>
                {/* « Conseillé » suit le choix : c'est le conseil pour ce
                    que l'étudiant vient de dire qu'il prépare. */}
                {on && (
                  <span className="whitespace-nowrap rounded-full bg-reviz-ink px-[11px] py-[5px] text-xs font-bold text-white">
                    Conseillé
                  </span>
                )}
                {!on && p.code === meilleurParJour && (
                  <span className="whitespace-nowrap rounded-full bg-reviz-orange-soft px-2.5 py-1 text-xs font-bold text-[#A8461C]">
                    Meilleur prix / jour
                  </span>
                )}
              </div>
              <div className="flex flex-col gap-2">
                <p className="flex items-baseline gap-1.5">
                  <span className="font-titre text-[52px] leading-none">{nombreLisible(p.prixFcfa)}</span>
                  <span className="text-[15px] font-bold">F CFA</span>
                </p>
                <span
                  className={`self-start rounded-[10px] px-2.5 py-[5px] text-[13px] font-semibold ${
                    on ? 'bg-reviz-ink/10' : 'bg-reviz-surface-low text-reviz-muted'
                  }`}
                >
                  {prixParJour(p.prixFcfa, p.jours)}
                </span>
              </div>
              <ul
                className={`flex flex-col gap-3 border-t-2 border-dashed pt-4 text-base font-semibold ${
                  on ? 'border-reviz-ink/25' : 'border-[#EADBB4]'
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
              <p className={`flex-grow text-[15px] leading-normal ${on ? 'text-[#3B3424]' : 'text-reviz-muted'}`}>
                {p.description}
              </p>
              {on ? (
                <a
                  href={lien}
                  className="flex min-h-[54px] items-center justify-center rounded-[20px] bg-reviz-ink text-base font-bold text-white no-underline transition-transform active:scale-[0.97] motion-reduce:transition-none"
                >
                  Commencer avec {p.label}
                </a>
              ) : (
                <button
                  type="button"
                  onClick={() => setChoix(p.code)}
                  className="min-h-[54px] rounded-[20px] bg-reviz-cream text-base font-bold text-reviz-ink transition-transform active:scale-[0.97] motion-reduce:transition-none"
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
