'use client'

import { useEffect, useRef } from 'react'
import { cn } from '@/lib/utils'

export type OtpInputProps = {
  value: string
  onChange: (valeur: string) => void
  length?: number
  error?: boolean
  disabled?: boolean
  /** Nom du champ caché, pour l'envoi dans un formulaire. */
  name?: string
}

/**
 * Saisie d'un code à usage unique.
 *
 * Un seul champ réel, invisible, superposé aux cases affichées : la saisie
 * par champs séparés se bat contre le remplissage automatique des claviers
 * Android, qui collent le code entier d'un coup.
 */
export function OtpInput({
  value,
  onChange,
  length = 6,
  error,
  disabled,
  name,
}: OtpInputProps) {
  const ref = useRef<HTMLInputElement>(null)

  // Le clavier doit s'ouvrir sans que l'étudiant ait à viser une case.
  useEffect(() => {
    ref.current?.focus()
  }, [])

  const cases = Array.from({ length }, (_, i) => value[i] ?? '')
  const position = Math.min(value.length, length - 1)

  return (
    <div
      className="relative"
      onClick={() => ref.current?.focus()}
      role="presentation"
    >
      <input
        ref={ref}
        name={name}
        value={value}
        onChange={(e) => onChange(e.target.value.replace(/\D/g, '').slice(0, length))}
        inputMode="numeric"
        autoComplete="one-time-code"
        maxLength={length}
        disabled={disabled}
        aria-label={`Code à ${length} chiffres`}
        className="absolute inset-0 h-full w-full cursor-default opacity-0"
      />

      <div className="flex justify-between gap-space-8" aria-hidden="true">
        {cases.map((chiffre, i) => (
          <span
            key={i}
            className={cn(
              'flex h-14 flex-1 items-center justify-center rounded-xl border-2 text-headline-lg transition-colors',
              error
                ? 'border-reviz-danger bg-reviz-danger-soft text-reviz-on-danger-soft'
                : chiffre
                  ? 'border-reviz-yellow bg-reviz-yellow-soft text-reviz-ink'
                  : 'border-reviz-border bg-reviz-card text-reviz-muted',
              !disabled && i === position && !chiffre && 'border-reviz-yellow',
            )}
          >
            {chiffre}
          </span>
        ))}
      </div>
    </div>
  )
}
