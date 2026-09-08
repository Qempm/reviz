import type { ReactNode } from 'react'
import { Icon } from './icon'

export type HeroCardProps = {
  /** Pilule blanche en haut à gauche, par exemple « J-3 avant le contrôle ». */
  badge: string
  /** Glyphe de la pilule. */
  badgeIcon?: string
  /** Mention discrète en haut à droite, par exemple « Amphi 7 • 08:30 ». */
  meta?: string
  title: string
  /** Ligne de contexte sous le titre. */
  subtitle?: string
  /** Grand glyphe décoratif en filigrane. */
  watermark?: string
  /** Initiales des camarades inscrits. */
  avatars?: string[]
  /** Texte accompagnant les avatars, par exemple « +1 420 candidats ». */
  avatarsLabel?: string
  action?: ReactNode
}

/**
 * Carte héros orange : compte à rebours d'examen, défi de la semaine
 * (docs/DESIGN.md § 7). Rayon 24 px et ombre colorée, la seule du système.
 */
export function HeroCard({
  badge,
  badgeIcon = 'hourglass_top',
  meta,
  title,
  subtitle,
  watermark,
  avatars,
  avatarsLabel,
  action,
}: HeroCardProps) {
  return (
    <section className="relative flex flex-col gap-space-16 overflow-hidden rounded-hero bg-reviz-orange p-space-20 text-reviz-card shadow-hero">
      {/* Décor : cercle en débord et glyphe en filigrane. */}
      <div className="pointer-events-none absolute -bottom-6 -right-6 h-32 w-32 rounded-full bg-reviz-card/10" />
      {watermark ? (
        <div className="pointer-events-none absolute right-12 top-4 text-reviz-card/20">
          <Icon name={watermark} size={64} />
        </div>
      ) : null}

      <div className="relative z-10 flex items-center justify-between">
        <span className="flex items-center gap-space-4 rounded-full bg-reviz-card px-space-12 py-space-4 text-label-sm text-secondary shadow-sm">
          <Icon name={badgeIcon} size={16} />
          {badge}
        </span>
        {meta ? (
          <span className="rounded-full bg-black/20 px-space-8 py-space-4 text-caption text-reviz-card">
            {meta}
          </span>
        ) : null}
      </div>

      <div className="relative z-10 flex flex-col gap-space-4">
        <h2 className="text-headline-lg leading-tight text-reviz-card">{title}</h2>
        {subtitle ? (
          <p className="text-label-sm text-reviz-card/90">{subtitle}</p>
        ) : null}
      </div>

      {avatars?.length || action ? (
        <div className="relative z-10 flex items-center justify-between gap-space-12">
          {avatars?.length ? (
            <div className="flex items-center gap-space-8">
              <div className="flex -space-x-2">
                {avatars.slice(0, 4).map((initiale, i) => (
                  <span
                    key={i}
                    className="flex h-8 w-8 items-center justify-center rounded-full border-2 border-reviz-card bg-reviz-orange-soft text-caption text-on-secondary-fixed"
                  >
                    {initiale}
                  </span>
                ))}
              </div>
              {avatarsLabel ? (
                <span className="text-label-sm text-reviz-card/90">
                  {avatarsLabel}
                </span>
              ) : null}
            </div>
          ) : (
            <span />
          )}
          {action}
        </div>
      ) : null}
    </section>
  )
}
