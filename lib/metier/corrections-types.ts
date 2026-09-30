/**
 * Les types d'épreuve qu'un étudiant peut préciser au dépôt d'une copie.
 *
 * À part de `corrections.ts`, qui est `server-only` : la consigne et ses
 * tests en ont besoin sans tirer le client Supabase.
 */
export const TYPES_EPREUVE = ['devoir', 'interrogation', 'partiel', 'examen', 'td'] as const
