import { cn } from '@/lib/utils'
import { Icon } from './icon'

export type StepperProps = {
  /** Libellés des étapes. */
  etapes: string[]
  /** Index de l'étape en cours, à partir de 0. */
  courante: number
}

/**
 * Fil d'étapes.
 *
 * Sert aux parcours en plusieurs temps — inscription, dépôt d'un cours,
 * paiement. Montrer où l'on en est réduit l'abandon : l'étudiant sait
 * combien il reste.
 */
export function Stepper({ etapes, courante }: StepperProps) {
  return (
    <ol className="flex items-center gap-space-4" aria-label="Progression">
      {etapes.map((etape, i) => {
        const faite = i < courante
        const active = i === courante

        return (
          <li key={etape} className="flex flex-1 items-center gap-space-4">
            <span
              aria-current={active ? 'step' : undefined}
              className={cn(
                'flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-caption transition-colors',
                faite
                  ? 'bg-reviz-yellow text-reviz-on-yellow'
                  : active
                    ? 'bg-reviz-yellow text-reviz-on-yellow shadow-tactile-sm'
                    : 'bg-surface-container text-reviz-muted',
              )}
            >
              {faite ? <Icon name="check" size={16} /> : i + 1}
            </span>

            {i < etapes.length - 1 ? (
              <span
                aria-hidden="true"
                className={cn(
                  'h-1 flex-1 rounded-full transition-colors',
                  faite ? 'bg-reviz-yellow' : 'bg-surface-container',
                )}
              />
            ) : null}
          </li>
        )
      })}
    </ol>
  )
}
