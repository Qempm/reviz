import type { SelectHTMLAttributes } from 'react'
import { cn } from '@/lib/utils'
import { Icon } from './icon'

export type SelectOption = {
  value: string
  label: string
}

export type SelectProps = {
  options: SelectOption[]
  error?: string
  hint?: string
} & SelectHTMLAttributes<HTMLSelectElement>

/**
 * Select dropdown du design system.
 */
export function Select({ options, error, hint, ...rest }: SelectProps) {
  const aide = error ?? hint
  const hasError = !!error

  return (
    <div className="flex flex-col gap-space-8">
      <div
        className={cn(
          'relative flex h-cta items-center gap-space-8 rounded-xl border-2 bg-reviz-card px-space-16 transition-colors',
          'focus-within:border-reviz-yellow',
          hasError ? 'border-reviz-danger' : 'border-reviz-border',
        )}
      >
        <select
          className="w-full appearance-none bg-transparent text-body-lg text-reviz-ink outline-none cursor-pointer"
          {...rest}
        >
          {options.map((opt) => (
            <option key={opt.value} value={opt.value}>
              {opt.label}
            </option>
          ))}
        </select>
        <Icon
          name="expand_more"
          size={20}
          className="text-reviz-muted pointer-events-none absolute right-4 shrink-0"
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
