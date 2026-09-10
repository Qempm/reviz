import type { InputHTMLAttributes, ReactNode } from 'react'
import { cn } from '@/lib/utils'

export type InputProps = {
  hint?: string
  error?: string
  prefix?: ReactNode
} & InputHTMLAttributes<HTMLInputElement>

/**
 * Simple input wrapper sans label.
 */
export function Input({ hint, error, prefix, ...rest }: InputProps) {
  const aide = error ?? hint
  const hasError = !!error

  return (
    <div className="flex flex-col gap-space-8">
      <div
        className={cn(
          'flex h-cta items-center gap-space-8 rounded-xl border-2 bg-reviz-card px-space-16 transition-colors',
          'focus-within:border-reviz-yellow',
          hasError ? 'border-reviz-danger' : 'border-reviz-border',
        )}
      >
        {prefix && (
          <span className="shrink-0 text-body-lg text-reviz-muted">{prefix}</span>
        )}
        <input
          className="w-full bg-transparent text-body-lg text-reviz-ink outline-none placeholder:text-reviz-muted/60"
          {...rest}
        />
      </div>

      {aide && (
        <span className={cn('text-label-sm', hasError ? 'text-reviz-danger' : 'text-reviz-muted')}>
          {aide}
        </span>
      )}
    </div>
  )
}
