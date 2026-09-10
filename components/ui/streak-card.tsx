import { progressionDuJour } from '@/lib/xp/serie'
import { cn } from '@/lib/utils'
import { Card } from './card'
import { Icon } from './icon'
import { ProgressBar } from './progress-bar'

/** Un jour de la semaine, tel que le renvoie `public.streak_week()`. */
export type StreakDay = {
  /** 1 = lundi, 7 = dimanche (isodow). */
  weekday: number
  isValidated: boolean
  isToday: boolean
}

export type StreakCardProps = {
  /**
   * Jours validés consécutifs, **déjà corrigés** par `etatSerie()`.
   * `profiles.current_streak` brut ne convient pas : il garde la valeur du
   * dernier jour validé, même vieille d'une semaine.
   */
  streak: number
  /** La série ne court plus : le dernier jour validé est trop ancien. */
  rompue?: boolean
  /** XP gagnés dans la journée. */
  xpToday?: number
  /** Objectif du jour, pour la barre de progression. */
  objectif?: { repondues: number; total: number }
  /** Les 7 jours de la semaine, du lundi au dimanche. */
  days: StreakDay[]
  /** Phrase d'encouragement affichée sous la ligne des jours. */
  message?: string
}

const LETTRES = ['L', 'M', 'M', 'J', 'V', 'S', 'D']

// Inclinaisons relevées dans le markup Stitch : les cases validées ne sont pas
// alignées au cordeau, ce qui donne son côté « collé à la main » à la carte.
const INCLINAISONS = ['rotate-3', '-rotate-3', 'rotate-2', '', 'rotate-3', '-rotate-2', 'rotate-1']

/**
 * Carte de série de révision (docs/DESIGN.md § 7).
 *
 * Sept carrés arrondis légèrement inclinés, et non sept losanges à 45° comme
 * l'annonçait CLAUDE.md (écart 11) : ce sont les carrés que Stitch a produits.
 */
export function StreakCard({
  streak,
  rompue,
  xpToday,
  objectif,
  days,
  message,
}: StreakCardProps) {
  const eteinte = rompue || streak === 0

  return (
    <Card>
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-space-12">
          <span
            className={cn(
              'flex h-12 w-12 items-center justify-center rounded-full',
              // Éteinte, la flamme reste chaude mais sourde : pas de gris
              // froid, la palette n'en a pas (docs/DESIGN.md § 11).
              eteinte
                ? 'bg-surface-container text-reviz-muted'
                : 'bg-reviz-yellow text-reviz-on-yellow shadow-[0_3px_0_theme(colors.reviz.edge.yellow)]',
            )}
          >
            <Icon name="local_fire_department" size={28} filled={!eteinte} />
          </span>
          <div className="flex flex-col">
            <h2 className="text-headline-md text-reviz-ink">
              {eteinte
                ? 'Lance ta série'
                : `${streak} ${streak > 1 ? 'jours' : 'jour'} de flamme !`}
            </h2>
            {typeof xpToday === 'number' && xpToday > 0 ? (
              <span className="text-label-sm text-primary">
                +{xpToday} XP aujourd&apos;hui
              </span>
            ) : null}
          </div>
        </div>
      </div>

      <div className="flex items-center justify-between px-space-4">
        {days.map((day, i) => (
          <div
            key={day.weekday}
            className={cn(
              'flex flex-col items-center gap-space-4',
              !day.isValidated && !day.isToday && 'opacity-50',
            )}
          >
            <span
              className={cn(
                'text-caption',
                day.isToday ? 'text-secondary' : 'text-reviz-muted',
              )}
            >
              {LETTRES[i]}
            </span>

            {day.isToday && day.isValidated ? (
              // Aujourd'hui, et c'est fait : la case ne clignote plus. Une
              // case qui appelle encore alors que le jour est validé annule
              // la récompense.
              <span className="flex h-10 w-10 scale-105 items-center justify-center rounded-xl bg-reviz-orange text-reviz-card shadow-[0_3px_0_theme(colors.reviz.edge.orange)]">
                <Icon name="local_fire_department" size={22} filled />
              </span>
            ) : day.isToday ? (
              // Aujourd'hui, pas encore validé : la case pulse, en creux.
              <span className="flex h-10 w-10 scale-105 animate-pulse items-center justify-center rounded-xl bg-reviz-orange-soft text-reviz-orange shadow-[0_3px_0_theme(colors.reviz.edge.orange)]">
                <Icon name="local_fire_department" size={22} />
              </span>
            ) : day.isValidated ? (
              <span
                className={cn(
                  'flex h-9 w-9 items-center justify-center rounded-xl bg-reviz-yellow text-reviz-on-yellow shadow-tactile-sm',
                  INCLINAISONS[i],
                )}
              >
                <Icon name="check" size={20} />
              </span>
            ) : (
              <span className="flex h-9 w-9 items-center justify-center rounded-xl bg-surface-container">
                <span className="h-2 w-2 rounded-full bg-reviz-border" />
              </span>
            )}
          </div>
        ))}
      </div>

      {/* Objectif du jour : sans compteur, « réponds à 10 questions » n'est
          qu'une phrase. */}
      {objectif && objectif.repondues < objectif.total ? (
        <ProgressBar
          value={progressionDuJour(objectif.repondues, objectif.total)}
          label={`${objectif.repondues} / ${objectif.total} questions aujourd’hui`}
        />
      ) : null}

      {message ? (
        <div className="flex items-center gap-space-8 rounded-xl bg-surface-container-low p-space-12">
          <Icon name="military_tech" size={22} className="text-secondary" />
          <p className="text-label-sm text-reviz-ink">{message}</p>
        </div>
      ) : null}
    </Card>
  )
}
