/**
 * Design system Reviz.
 *
 * ATTENTION — `BottomSheet`, `ToastProvider` et `Confetti` ne sont
 * volontairement PAS réexportés ici : ils dépendent de `motion`, et le barrel
 * est importé par presque toutes les pages. Les exposer ferait charger Motion
 * (~49 ko servis) sur chaque route, y compris celles qui n'animent rien.
 * Mesuré : le premier chargement passait de 109 à 152 ko.
 *
 * Les importer directement depuis leur fichier :
 *   import { BottomSheet } from '@/components/ui/bottom-sheet'
 *   import { ToastProvider } from '@/components/ui/toast-provider'
 *   import { Confetti } from '@/components/reviz/confetti'
 */

export { Icon } from './icon'
export { TextField } from './text-field'
export { OtpInput } from './otp-input'
export { Skeleton } from './skeleton'
export { Chip } from './chip'
export { Avatar } from './avatar'
export { Tabs } from './tabs'
export { Countdown } from './countdown'
export { CircularProgress } from './circular-progress'
export { FileDropzone } from './file-dropzone'
export { Stepper } from './stepper'
export { Button } from './button'
export { Card } from './card'
export { ProgressBar, SegmentedProgressBar } from './progress-bar'
export { Podium, LeaderboardRow } from './podium'
export { StreakCard } from './streak-card'
export { HeroCard } from './hero-card'
export { QuizOption } from './quiz-option'
export { BottomNav, NAV_TABS } from './bottom-nav'
export { Toast } from './toast'
export { EmptyState } from './empty-state'
export { MascotState } from './mascot-state'

export type { ButtonProps, ButtonVariant } from './button'
export type { TextFieldProps } from './text-field'
export type { OtpInputProps } from './otp-input'
export type { SkeletonProps } from './skeleton'
export type { ChipProps, ChipTone } from './chip'
export type { AvatarProps } from './avatar'
export type { TabsProps, Onglet } from './tabs'
export type { CountdownProps } from './countdown'
export type { CircularProgressProps } from './circular-progress'
export type { FileDropzoneProps, FichierChoisi } from './file-dropzone'
export type { StepperProps } from './stepper'
export type { CardProps } from './card'
export type { ProgressBarProps, SegmentState } from './progress-bar'
export type { PodiumProps, PodiumEntry } from './podium'
export type { StreakCardProps, StreakDay } from './streak-card'
export type { HeroCardProps } from './hero-card'
export type { QuizOptionProps, QuizOptionState } from './quiz-option'
export type { NavTab } from './bottom-nav'
export type { ToastProps, ToastTone } from './toast'
export type { EmptyStateProps } from './empty-state'
export type { MascotStateProps, MascotMood } from './mascot-state'
