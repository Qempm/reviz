import type { InputHTMLAttributes, ReactNode } from 'react'
import { cn } from '@/lib/utils'

export type TextFieldProps = {
  label?: string
  /** Message d'erreur : remplace l'aide et colore le champ. */
  error?: string
  /** Aide à la saisie, sous le champ. */
  hint?: string
  /** Contenu collé à gauche dans le champ, par exemple un indicatif. */
  prefix?: ReactNode
} & Omit<InputHTMLAttributes<HTMLInputElement>, 'className' | 'prefix'>

/**
 * Champ de saisie du design system.
 *
 * Hauteur 56 px comme le CTA : sur mobile, un champ plus bas qu'un bouton se
 * rate au pouce. Bordure de 2 px, contrairement aux cartes — ici le contour
 * porte l'état (repos, focus, erreur), il ne peut pas être implicite.
 */
export function TextField({
  label,
  error,
  hint,
  prefix,
  id,
  ...rest
}: TextFieldProps) {
  const aide = error ?? hint
  const aideId = aide && id ? `${id}-aide` : undefined

  return (
    <div className="flex flex-col gap-space-8">
      {label ? (
        <label htmlFor={id} className="text-label-md text-reviz-ink">
          {label}
        </label>
      ) : null}

      <div
        className={cn(
          'flex h-cta items-center gap-space-8 rounded-xl border-2 bg-reviz-card px-space-16 transition-colors',
          'focus-within:border-reviz-yellow',
          error ? 'border-reviz-danger' : 'border-reviz-border',
        )}
      >
        {prefix ? (
          <span className="shrink-0 text-body-lg text-reviz-muted">{prefix}</span>
        ) : null}
        <input
          id={id}
          aria-invalid={error ? true : undefined}
          aria-describedby={aideId}
          className="w-full bg-transparent text-body-lg text-reviz-ink outline-none placeholder:text-reviz-muted/60"
          {...rest}
        />
      </div>

      {aide ? (
        <span
          id={aideId}
          role={error ? 'alert' : undefined}
          className={cn(
            'text-label-sm',
            error ? 'text-reviz-danger' : 'text-reviz-muted',
          )}
        >
          {aide}
        </span>
      ) : null}
    </div>
  )
}
