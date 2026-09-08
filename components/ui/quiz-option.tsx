import { cn } from '@/lib/utils'
import { Icon } from './icon'

export type QuizOptionState = 'idle' | 'selected' | 'correct' | 'wrong'

export type QuizOptionProps = {
  /** Lettre affichée dans la pastille : A, B, C, D. */
  letter: string
  label: string
  state?: QuizOptionState
  onSelect?: () => void
  disabled?: boolean
}

/**
 * Option de QCM, une par ligne et pleine largeur (docs/DESIGN.md § 7).
 *
 * Deux points où le rendu Stitch prime sur la prose de CLAUDE.md :
 *   - pas de bordure de 2 px, la distinction vient du fond et de l'arête
 *     tactile (écart 14) ;
 *   - pas de vert de succès, la bonne réponse est célébrée en jaune, la
 *     mauvaise en rouge d'erreur (arbitrage du § 11).
 */
export function QuizOption({
  letter,
  label,
  state = 'idle',
  onSelect,
  disabled,
}: QuizOptionProps) {
  const container: Record<QuizOptionState, string> = {
    idle: 'bg-reviz-card shadow-md',
    selected: 'bg-reviz-yellow-soft shadow-tactile',
    correct: 'bg-reviz-yellow-soft shadow-tactile',
    wrong: 'bg-reviz-danger-soft shadow-[0_4px_0_theme(colors.reviz.edge.danger)]',
  }

  const pill: Record<QuizOptionState, string> = {
    idle: 'bg-surface-container text-reviz-muted',
    selected: 'bg-reviz-yellow text-reviz-on-yellow',
    correct: 'bg-reviz-yellow text-reviz-on-yellow',
    wrong: 'bg-reviz-danger text-on-error',
  }

  const text: Record<QuizOptionState, string> = {
    idle: 'text-reviz-ink',
    selected: 'text-reviz-ink',
    correct: 'text-reviz-ink',
    wrong: 'text-reviz-on-danger-soft',
  }

  return (
    <button
      type="button"
      onClick={onSelect}
      disabled={disabled}
      aria-pressed={state === 'selected'}
      className={cn(
        'flex w-full items-center justify-between gap-space-12 rounded-xl p-space-16 text-left transition-all',
        'active:translate-y-[2px] disabled:pointer-events-none',
        container[state],
      )}
    >
      <span className="flex items-center gap-space-12">
        <span
          className={cn(
            'flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-label-md',
            pill[state],
          )}
        >
          {state === 'correct' ? (
            <Icon name="check" size={20} />
          ) : state === 'wrong' ? (
            <Icon name="close" size={20} />
          ) : (
            letter
          )}
        </span>
        <span className={cn('text-body-lg', text[state])}>{label}</span>
      </span>

      {state === 'correct' ? (
        <Icon name="check_circle" size={22} filled className="text-primary" />
      ) : null}
    </button>
  )
}
