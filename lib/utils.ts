type ClassValue = string | false | null | undefined

/**
 * Concatène des classes conditionnelles. Volontairement minimal : pas de
 * fusion de conflits Tailwind, l'ordre des classes suffit à nos usages.
 */
export function cn(...values: ClassValue[]): string {
  return values.filter(Boolean).join(' ')
}
