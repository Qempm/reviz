import { cn } from '@/lib/utils'
import { Icon } from './icon'

export type ToastTone = 'neutral' | 'success' | 'danger'

export type ToastProps = {
  message: string
  tone?: ToastTone
  icon?: string
  /** Positionne le toast au-dessus de la barre de navigation. */
  floating?: boolean
}

/**
 * Toast en pilule sombre, flottant au-dessus de la navigation
 * (docs/DESIGN.md § 7). Surface `inverse-surface`, icône en jaune.
 */
export function Toast({ message, tone = 'neutral', icon, floating }: ToastProps) {
  const glyphe =
    icon ??
    (tone === 'success' ? 'check_circle' : tone === 'danger' ? 'error' : 'info')

  const teinte =
    tone === 'danger' ? 'text-reviz-danger-soft' : 'text-reviz-yellow'

  return (
    <div
      role="status"
      className={cn(
        'flex items-center gap-space-8 rounded-full bg-inverse-surface px-space-16 py-space-12 shadow-float',
        floating && 'fixed inset-x-space-16 bottom-[104px] z-40 mx-auto w-fit',
      )}
    >
      <Icon name={glyphe} size={20} filled className={teinte} />
      <span className="text-label-md text-inverse-on-surface">{message}</span>
    </div>
  )
}
