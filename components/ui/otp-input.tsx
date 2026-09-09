'use client'

import { useEffect, useRef, useState } from 'react'
import { extraireCode } from '@/lib/auth/otp'
import { cn } from '@/lib/utils'
import { Icon } from './icon'

export type OtpInputProps = {
  value: string
  onChange: (valeur: string) => void
  /** Appelé dès que le code est complet — évite une frappe de plus. */
  onComplete?: (valeur: string) => void
  length?: number
  error?: boolean
  disabled?: boolean
  name?: string
}

/**
 * Saisie d'un code à usage unique.
 *
 * Un seul champ réel, invisible, superposé aux cases affichées : des champs
 * séparés se battent contre le collage et contre le remplissage automatique
 * des claviers Android, qui livrent les six chiffres d'un coup.
 */
export function OtpInput({
  value,
  onChange,
  onComplete,
  length = 6,
  error,
  disabled,
  name,
}: OtpInputProps) {
  const ref = useRef<HTMLInputElement>(null)
  const [collageDisponible, setCollageDisponible] = useState(false)
  const dejaComplete = useRef(false)

  useEffect(() => {
    ref.current?.focus()
    // Le bouton « Coller » n'a de sens que si l'API est là et utilisable.
    setCollageDisponible(
      typeof navigator !== 'undefined' && Boolean(navigator.clipboard?.readText),
    )
  }, [])

  // Déclenche onComplete une seule fois par code saisi.
  useEffect(() => {
    if (value.length === length && !dejaComplete.current) {
      dejaComplete.current = true
      onComplete?.(value)
    }
    if (value.length < length) dejaComplete.current = false
  }, [value, length, onComplete])

  function appliquer(brut: string) {
    onChange(extraireCode(brut, length))
  }

  async function collerDepuisPressePapier() {
    try {
      const texte = await navigator.clipboard.readText()
      const code = extraireCode(texte, length)
      if (code.length > 0) {
        appliquer(code)
        ref.current?.focus()
      }
    } catch {
      // Permission refusée ou presse-papier vide : on laisse la saisie
      // manuelle, sans message — l'étudiant voit que rien n'a changé.
    }
  }

  const cases = Array.from({ length }, (_, i) => value[i] ?? '')
  const position = Math.min(value.length, length - 1)

  return (
    <div className="flex flex-col gap-space-12">
      <div
        className="relative"
        onClick={() => ref.current?.focus()}
        role="presentation"
      >
        <input
          ref={ref}
          name={name}
          value={value}
          onChange={(e) => appliquer(e.target.value)}
          onPaste={(e) => {
            // On prend la main : le collage brut laisserait passer le texte
            // autour du code.
            e.preventDefault()
            appliquer(e.clipboardData.getData('text'))
          }}
          inputMode="numeric"
          autoComplete="one-time-code"
          maxLength={length * 4}
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

      {collageDisponible && value.length < length ? (
        <button
          type="button"
          onClick={collerDepuisPressePapier}
          disabled={disabled}
          className="flex min-h-[48px] w-fit items-center gap-space-8 self-center rounded-full px-space-16 text-label-md text-primary"
        >
          <Icon name="content_paste" size={20} />
          Coller le code
        </button>
      ) : null}
    </div>
  )
}
