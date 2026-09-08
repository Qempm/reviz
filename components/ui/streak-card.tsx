import { cn } from '@/lib/utils'
import { Card } from './card'
import { Icon } from './icon'

/** Un jour de la semaine, tel que le renvoie `public.streak_week()`. */
export type StreakDay = {
  /** 1 = lundi, 7 = dimanche (isodow). */
  weekday: number
  isValidated: boolean
  isToday: boolean
}

export type StreakCardProps = {
  /** Jours validés consécutifs (`profiles.current_streak`). */
  streak: number
  /** XP gagnés dans la journée. */
  xpToday?: number
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
export function StreakCard({ streak, xpToday, days, message }: StreakCardProps) {
  return (
    <Card>
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-space-12">
          <span className="flex h-12 w-12 items-center justify-center rounded-full bg-reviz-yellow text-reviz-on-yellow shadow-[0_3px_0_theme(colors.reviz.edge.yellow)]">
            <Icon name="local_fire_department" size={28} filled />
          </span>
          <div className="flex flex-col">
            <h2 className="text-headline-md text-reviz-ink">
              {streak} {streak > 1 ? 'jours' : 'jour'} de flamme !
            </h2>
            {typeof xpToday === 'number' ? (
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

            {day.isToday ? (
              <span className="flex h-10 w-10 scale-105 animate-pulse items-center justify-center rounded-xl bg-reviz-orange text-reviz-card shadow-[0_3px_0_theme(colors.reviz.edge.orange)]">
                <Icon name="local_fire_department" size={22} filled />
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

      {message ? (
        <div className="flex items-center gap-space-8 rounded-xl bg-surface-container-low p-space-12">
          <Icon name="military_tech" size={22} className="text-secondary" />
          <p className="text-label-sm text-reviz-ink">{message}</p>
        </div>
      ) : null}
    </Card>
  )
}
