import { cn } from '@/lib/utils'
import { Icon } from './icon'

export type PodiumEntry = {
  name: string
  xp: number
  avatarUrl?: string
}

export type PodiumProps = {
  first: PodiumEntry
  second: PodiumEntry
  third: PodiumEntry
}

type Rank = 1 | 2 | 3

/**
 * Mesures relevées dans l'écran « Ligue & Classement » (docs/DESIGN.md § 7).
 * Le n°3 est en pêche pâle, pas en orange : c'est ce que Stitch a produit,
 * contrairement à ce qu'annonçait CLAUDE.md (écart 12).
 */
const ranks: Record<
  Rank,
  {
    avatar: string
    ring: string
    block: string
    height: string
    numeral: string
    badge: string
    text: string
  }
> = {
  1: {
    avatar: 'w-16 h-16',
    ring: 'bg-reviz-yellow shadow-lg',
    block: 'bg-reviz-yellow shadow-md pt-space-12',
    height: 'h-32',
    numeral: 'text-display-hero',
    badge: 'w-7 h-7 bg-reviz-yellow text-reviz-on-yellow',
    text: 'text-reviz-on-yellow',
  },
  2: {
    avatar: 'w-14 h-14',
    ring: 'bg-reviz-blue shadow-md',
    block: 'bg-reviz-blue shadow-sm pt-space-8',
    height: 'h-24',
    numeral: 'text-display-hero-mobile',
    badge: 'w-6 h-6 bg-reviz-blue text-on-tertiary-container',
    text: 'text-on-tertiary-container',
  },
  3: {
    avatar: 'w-14 h-14',
    ring: 'bg-reviz-orange-soft shadow-md',
    block: 'bg-reviz-orange-soft shadow-sm pt-space-8',
    height: 'h-20',
    numeral: 'text-display-hero-mobile',
    badge: 'w-6 h-6 bg-reviz-orange-soft text-on-secondary-fixed',
    text: 'text-on-secondary-fixed',
  },
}

function Step({ rank, entry }: { rank: Rank; entry: PodiumEntry }) {
  const r = ranks[rank]

  return (
    <div className="flex flex-1 flex-col items-center">
      <div className="relative flex flex-col items-center">
        {rank === 1 ? (
          <span className="absolute -top-5 whitespace-nowrap rounded-full bg-reviz-orange px-space-4 py-0.5 text-caption text-on-secondary shadow-sm">
            Champion
          </span>
        ) : null}

        <div
          className={cn(
            'flex items-center justify-center rounded-full p-1',
            r.avatar,
            r.ring,
          )}
        >
          {entry.avatarUrl ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={entry.avatarUrl}
              alt=""
              className="h-full w-full rounded-full object-cover"
            />
          ) : (
            <span className="flex h-full w-full items-center justify-center rounded-full bg-reviz-card text-headline-md text-reviz-muted">
              {entry.name.slice(0, 1).toUpperCase()}
            </span>
          )}
        </div>

        <span
          className={cn(
            'absolute -bottom-2 flex items-center justify-center rounded-full text-headline-sm shadow-sm',
            r.badge,
          )}
        >
          {rank}
        </span>
      </div>

      <div
        className={cn(
          'mt-space-8 flex w-full flex-col items-center justify-start rounded-t-xl',
          r.height,
          r.block,
        )}
      >
        <span className={cn('font-black opacity-40', r.numeral, r.text)}>
          {rank}
        </span>
      </div>

      <div className="flex flex-col items-center gap-space-2 pt-space-8">
        <span className="text-label-md text-reviz-ink">{entry.name}</span>
        <span className="rounded-full bg-reviz-yellow-soft px-space-8 py-space-2 text-caption text-primary">
          {entry.xp.toLocaleString('fr-FR')} XP
        </span>
      </div>
    </div>
  )
}

/** Podium 2 / 1 / 3, le n°1 surélevé au centre. */
export function Podium({ first, second, third }: PodiumProps) {
  return (
    <div className="flex items-end justify-center gap-space-8 pb-space-4 pt-space-16">
      <Step rank={2} entry={second} />
      <Step rank={1} entry={first} />
      <Step rank={3} entry={third} />
    </div>
  )
}

/** Ligne de classement hors podium, mise en avant si c'est l'étudiant courant. */
export function LeaderboardRow({
  rank,
  entry,
  isCurrentUser = false,
}: {
  rank: number
  entry: PodiumEntry
  isCurrentUser?: boolean
}) {
  return (
    <div
      className={cn(
        'flex h-16 items-center gap-space-12 rounded-xl px-space-12',
        isCurrentUser
          ? 'bg-reviz-yellow-soft ring-2 ring-reviz-yellow'
          : 'bg-reviz-card shadow-sm',
      )}
    >
      <span className="w-7 text-center text-label-md text-reviz-muted">{rank}</span>
      <span className="flex h-10 w-10 items-center justify-center rounded-full bg-surface-container text-label-md text-reviz-muted">
        {entry.name.slice(0, 1).toUpperCase()}
      </span>
      <span className="flex-1 text-label-lg text-reviz-ink">{entry.name}</span>
      <span className="flex items-center gap-space-4 text-headline-sm text-reviz-ink">
        <Icon name="stars" size={16} filled className="text-reviz-yellow" />
        {entry.xp.toLocaleString('fr-FR')}
      </span>
    </div>
  )
}
