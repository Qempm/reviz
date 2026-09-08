import type { ButtonHTMLAttributes, ReactNode } from 'react'
import { cn } from '@/lib/utils'
import { Icon } from './icon'

export type ButtonVariant = 'primary' | 'secondary' | 'danger' | 'fab'

export type ButtonProps = {
  variant?: ButtonVariant
  /** Glyphe Material Symbols affiché avant le libellé. */
  icon?: string
  /** Occupe toute la largeur. Vrai par défaut, sauf pour `fab`. */
  fullWidth?: boolean
  children?: ReactNode
} & Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'className'>

/**
 * Bouton du design system.
 *
 * La variante `primary` est la forme canonique arbitrée le 8 septembre 2026
 * (docs/DESIGN.md § 11) : 56 px de haut, rayon 12 px, texte en headline-md.
 * La variante 52 px / rayon 16 px présente dans certains écrans Stitch est
 * abandonnée.
 *
 * Toutes les variantes portent l'arête tactile : une ombre pleine sans flou
 * qui se réduit à l'appui, signature visuelle de Reviz (docs/DESIGN.md § 6).
 */
export function Button({
  variant = 'primary',
  icon,
  fullWidth,
  children,
  disabled,
  type = 'button',
  ...rest
}: ButtonProps) {
  const large = fullWidth ?? variant !== 'fab'

  const base =
    'inline-flex items-center justify-center gap-space-8 transition-all ' +
    'disabled:opacity-50 disabled:pointer-events-none'

  const variants: Record<ButtonVariant, string> = {
    primary:
      'h-cta rounded-xl px-space-20 text-headline-md ' +
      'bg-reviz-yellow text-reviz-on-yellow ' +
      'shadow-tactile active:translate-y-[2px] active:shadow-tactile-pressed',
    secondary:
      'h-cta rounded-xl px-space-20 text-label-lg ' +
      'bg-reviz-card text-reviz-ink border-2 border-reviz-border ' +
      'shadow-tactile-neutral active:translate-y-[2px] active:shadow-none',
    danger:
      'h-cta rounded-xl px-space-20 text-label-lg ' +
      'bg-reviz-danger text-on-error ' +
      'shadow-tactile-danger active:translate-y-[2px] active:shadow-none',
    fab:
      'h-14 w-14 rounded-full ' +
      'bg-reviz-orange text-on-secondary ' +
      'shadow-tactile-orange active:translate-y-[2px] active:shadow-tactile-orange-pressed',
  }

  return (
    <button
      type={type}
      disabled={disabled}
      className={cn(base, variants[variant], large && 'w-full')}
      {...rest}
    >
      {icon ? <Icon name={icon} size={variant === 'fab' ? 24 : 20} filled /> : null}
      {children}
    </button>
  )
}
